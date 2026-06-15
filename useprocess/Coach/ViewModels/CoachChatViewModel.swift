import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CoachChatViewModel {
    var messages: [CoachMessage] = []
    var inputText = ""
    var pendingAttachmentImage: UIImage?
    var isSending = false
    var streamingText = ""
    var errorMessage: String?
    var claudeConfigured = ClaudeConfiguration.isConfigured
    var transportLabel = ClaudeConfiguration.transportLabel
    var isSidebarExpanded = false

    var isVoiceRecording = false
    var isVoiceExiting = false
    var voiceElapsed: TimeInterval = 0
    let voiceMaxDuration: TimeInterval = 5.0

    private let libraryStore = CoachConversationLibraryStore.shared
    private var profile: UnifiedUserProfile?
    private var userId: String? { profile?.userId.isEmpty == false ? profile?.userId : AuthUser.current?.uid }
    private var voiceTimerTask: Task<Void, Never>?

    var conversations: [CoachConversation] {
        libraryStore.sortedConversations
    }

    var activeConversationId: UUID? {
        libraryStore.activeConversationId
    }

    var isSidebarEnabled: Bool {
        !isSending && !isVoiceRecording
    }

    func bind(profile: UnifiedUserProfile?) {
        self.profile = profile
        claudeConfigured = ClaudeConfiguration.isConfigured
        transportLabel = ClaudeConfiguration.transportLabel
    }

    func loadThreadIfNeeded() async {
        libraryStore.loadLocal()
        let welcome = CoachEngine.welcomeMessage(profile: profile)
        libraryStore.migrateLegacyThreadIfNeeded(welcome: welcome)

        guard let conversationId = libraryStore.activeConversationId else {
            await createNewConversation()
            return
        }

        let stored = await CoachSyncService.loadConversation(userId: userId, conversationId: conversationId)
        if stored.messages.isEmpty {
            messages = [welcome]
            libraryStore.setActiveMessages(messages)
            await CoachSyncService.replaceThread(
                CoachChatThread(messages: messages),
                userId: userId,
                conversationId: conversationId,
                title: libraryStore.activeConversation?.title
            )
        } else {
            messages = stored.messages
        }
    }

    func selectConversation(_ id: UUID) async {
        guard id != libraryStore.activeConversationId else { return }
        libraryStore.selectConversation(id)
        await reloadActiveConversation()
    }

    func createNewConversation() async {
        cancelVoiceRecording()
        clearPendingAttachment()
        isSending = false
        streamingText = ""
        errorMessage = nil

        let welcome = CoachEngine.welcomeMessage(profile: profile)
        let id = libraryStore.createConversation(welcome: welcome)
        messages = [welcome]

        await CoachSyncService.replaceThread(
            CoachChatThread(messages: [welcome]),
            userId: userId,
            conversationId: id,
            title: "Nouvelle conversation"
        )
    }

    func deleteConversation(_ id: UUID) async {
        let wasActive = libraryStore.activeConversationId == id
        await CoachSyncService.deleteConversation(id: id, userId: userId)
        libraryStore.deleteConversation(id)

        if libraryStore.sortedConversations.isEmpty {
            await createNewConversation()
            return
        }

        if wasActive {
            await reloadActiveConversation()
        }
    }

    private func reloadActiveConversation() async {
        guard let id = libraryStore.activeConversationId else {
            await createNewConversation()
            return
        }
        cancelVoiceRecording()
        clearPendingAttachment()
        isSending = false
        streamingText = ""

        let stored = await CoachSyncService.loadConversation(userId: userId, conversationId: id)
        if stored.messages.isEmpty {
            let welcome = CoachEngine.welcomeMessage(profile: profile)
            messages = [welcome]
            libraryStore.setActiveMessages(messages)
        } else {
            messages = stored.messages
        }
    }

    func sendCurrentMessage() async {
        guard !isSending else { return }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let image = pendingAttachmentImage {
            await sendImageAttachment(image, caption: trimmed)
            return
        }

        guard !trimmed.isEmpty else { return }
        await sendPrompt(trimmed, persistUserMessage: true)
    }

    func stageImageAttachment(_ image: UIImage) {
        pendingAttachmentImage = image
    }

    func clearPendingAttachment() {
        pendingAttachmentImage = nil
    }

    func startVoiceRecording() async {
        guard !isSending, !isVoiceRecording else { return }
        let authorized = await CoachSpeechTranscriber.shared.requestAuthorization()
        guard authorized else {
            errorMessage = CoachSpeechError.permissionDenied.errorDescription
            return
        }
        do {
            try CoachSpeechTranscriber.shared.startRecording()
            errorMessage = nil
            isVoiceExiting = false
            isVoiceRecording = true
            voiceElapsed = 0
            startVoiceTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelVoiceRecording() {
        voiceTimerTask?.cancel()
        isVoiceExiting = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            CoachSpeechTranscriber.shared.cancelRecording()
            isVoiceRecording = false
            isVoiceExiting = false
            voiceElapsed = 0
        }
    }

    func confirmVoiceRecording() async {
        guard isVoiceRecording else { return }
        voiceTimerTask?.cancel()
        isVoiceExiting = true
        try? await Task.sleep(for: .milliseconds(260))

        let transcript = CoachSpeechTranscriber.shared.stopRecording()
        isVoiceRecording = false
        isVoiceExiting = false
        voiceElapsed = 0

        guard !transcript.isEmpty else {
            errorMessage = "Aucune voix détectée — réessaie."
            return
        }
        await sendPrompt(transcript, persistUserMessage: true)
    }

    func runTool(_ tool: CoachTool) async {
        guard !isSending else { return }
        let prompt = tool.label
        let userMsg = CoachMessage(role: .user, text: "🔹 \(prompt)")
        messages.append(userMsg)
        await persistMessage(userMsg)
        isSending = true
        streamingText = ""
        errorMessage = nil
        defer { isSending = false; streamingText = "" }

        do {
            let reply = try await CoachEngine.runTool(tool, profile: profile)
            messages.append(reply)
            await persistMessage(reply)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startVoiceTimer() {
        voiceTimerTask?.cancel()
        let startedAt = Date()
        voiceTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
                guard !Task.isCancelled else { break }
                voiceElapsed = Date().timeIntervalSince(startedAt)
                if voiceElapsed >= voiceMaxDuration {
                    await confirmVoiceRecording()
                    break
                }
            }
        }
    }

    private func sendPrompt(_ trimmed: String, persistUserMessage: Bool) async {
        guard let conversationId = libraryStore.activeConversationId else { return }

        if persistUserMessage {
            libraryStore.updateActiveConversation { $0.applyAutoTitle(from: trimmed) }
            let title = libraryStore.activeConversation?.title

            let userMsg = CoachMessage(role: .user, text: trimmed)
            messages.append(userMsg)
            await CoachSyncService.appendMessage(
                userMsg,
                userId: userId,
                conversationId: conversationId,
                title: title
            )
            inputText = ""
        }

        isSending = true
        streamingText = ""
        errorMessage = nil
        defer { isSending = false }

        do {
            var assembled = ""
            for try await chunk in CoachEngine.streamChatMessage(trimmed, profile: profile, history: messages) {
                assembled += chunk
                streamingText = assembled
            }

            streamingText = ""
            let model = ClaudeModel.preferred(for: .chat).rawValue
            let reply = CoachMessage(role: .assistant, text: assembled, modelUsed: model)
            messages.append(reply)
            await CoachSyncService.appendMessage(
                reply,
                userId: userId,
                conversationId: conversationId,
                title: libraryStore.activeConversation?.title
            )
        } catch {
            errorMessage = error.localizedDescription
            streamingText = ""
        }
    }

    private func persistMessage(_ message: CoachMessage) async {
        guard let conversationId = libraryStore.activeConversationId else { return }
        await CoachSyncService.appendMessage(
            message,
            userId: userId,
            conversationId: conversationId,
            title: libraryStore.activeConversation?.title
        )
    }

    func resetConversation() async {
        await createNewConversation()
    }

    func sendImageAttachment(_ image: UIImage, caption: String = "") async {
        guard !isSending, let conversationId = libraryStore.activeConversationId else { return }

        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let userText = trimmedCaption.isEmpty ? "📷 Photo" : trimmedCaption
        let analysisPrompt = trimmedCaption.isEmpty
            ? "Analyse cette image en 2-3 phrases max. Contexte coach useprocess."
            : trimmedCaption

        pendingAttachmentImage = nil
        inputText = ""

        let userMsg = CoachMessage(role: .user, text: userText)
        messages.append(userMsg)
        await CoachSyncService.appendMessage(
            userMsg,
            userId: userId,
            conversationId: conversationId,
            title: libraryStore.activeConversation?.title
        )

        isSending = true
        streamingText = ""
        errorMessage = nil
        defer { isSending = false; streamingText = "" }

        do {
            let reply = try await CoachEngine.analyzeAttachedImage(
                image,
                caption: analysisPrompt,
                profile: profile,
                history: messages
            )
            messages.append(reply)
            await CoachSyncService.appendMessage(
                reply,
                userId: userId,
                conversationId: conversationId,
                title: libraryStore.activeConversation?.title
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendFileAttachment(name: String) async {
        await sendPrompt("📎 Fichier : \(name)", persistUserMessage: true)
    }
}
