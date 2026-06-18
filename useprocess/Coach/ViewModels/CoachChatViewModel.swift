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
    var voiceTranscript = ""
    var voiceAudioLevel: CGFloat = 0
    var voiceAudioLevels: [CGFloat] = Array(repeating: 0.06, count: 32)

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

    private var activePlanFocus: CoachPlanFocus?

    func bind(profile: UnifiedUserProfile?) {
        self.profile = profile
        claudeConfigured = ClaudeConfiguration.isConfigured
        transportLabel = ClaudeConfiguration.transportLabel
    }

    func loadThreadIfNeeded() async {
        libraryStore.loadLocal()
        CoachConversationStore.stripInjectedProgramSummaryMessages()
        let welcome = CoachEngine.welcomeMessage(profile: profile)
        libraryStore.migrateLegacyThreadIfNeeded(welcome: welcome)

        guard let conversationId = libraryStore.activeConversationId else {
            await createNewConversation()
            await consumePendingPlanPromptIfNeeded()
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
            messages = Self.filteredCoachMessages(stored.messages, welcome: welcome)
            if messages.count != stored.messages.count {
                libraryStore.setActiveMessages(messages)
                await CoachSyncService.replaceThread(
                    CoachChatThread(messages: messages),
                    userId: userId,
                    conversationId: conversationId,
                    title: libraryStore.activeConversation?.title
                )
            }
        }
        await consumePendingPlanPromptIfNeeded()
    }

    func consumePendingPlanPromptIfNeeded() async {
        guard let prompt = CoachPlanNavigationBridge.shared.consumePendingPrompt() else { return }
        activePlanFocus = CoachPlanNavigationBridge.shared.consumePendingFocus()
        await sendPrompt(prompt, persistUserMessage: true)
        activePlanFocus = nil
    }

    func selectConversation(_ id: UUID) async {
        guard id != libraryStore.activeConversationId else { return }
        libraryStore.selectConversation(id)
        await reloadActiveConversation()
    }

    func createNewConversation() async {
        resetVoiceStateImmediately()
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
        resetVoiceStateImmediately()
        clearPendingAttachment()
        isSending = false
        streamingText = ""

        let stored = await CoachSyncService.loadConversation(userId: userId, conversationId: id)
        if stored.messages.isEmpty {
            let welcome = CoachEngine.welcomeMessage(profile: profile)
            messages = [welcome]
            libraryStore.setActiveMessages(messages)
        } else {
            let welcome = CoachEngine.welcomeMessage(profile: profile)
            messages = Self.filteredCoachMessages(stored.messages, welcome: welcome)
            if messages.count != stored.messages.count {
                libraryStore.setActiveMessages(messages)
            }
        }
    }

    private static func filteredCoachMessages(_ messages: [CoachMessage], welcome: CoachMessage) -> [CoachMessage] {
        let filtered = messages.filter { !CoachConversationStore.shouldHideProgramSummaryMessage($0) }
        return filtered.isEmpty ? [welcome] : filtered
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
            voiceTranscript = ""
            voiceAudioLevel = 0
            voiceAudioLevels = Array(repeating: 0.06, count: 32)
            startVoiceTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelVoiceRecording() {
        guard isVoiceRecording || isVoiceExiting else { return }
        voiceTimerTask?.cancel()
        isVoiceExiting = true
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            CoachSpeechTranscriber.shared.cancelRecording()
            isVoiceRecording = false
            isVoiceExiting = false
            voiceElapsed = 0
            voiceTranscript = ""
            voiceAudioLevel = 0
            voiceAudioLevels = Array(repeating: 0.06, count: 32)
        }
    }

    /// Arrêt immédiat sans animation — changement de conversation / historique.
    private func resetVoiceStateImmediately() {
        guard isVoiceRecording || isVoiceExiting else { return }
        voiceTimerTask?.cancel()
        voiceTimerTask = nil
        CoachSpeechTranscriber.shared.cancelRecording()
        isVoiceRecording = false
        isVoiceExiting = false
        voiceElapsed = 0
        voiceTranscript = ""
        voiceAudioLevel = 0
        voiceAudioLevels = Array(repeating: 0.06, count: 32)
    }

    func confirmVoiceRecording() async -> Bool {
        guard isVoiceRecording else { return false }
        voiceTimerTask?.cancel()
        isVoiceExiting = true
        try? await Task.sleep(for: .milliseconds(180))

        let fallback = voiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let captured = CoachSpeechTranscriber.shared.stopRecording()
        let finalText = captured.isEmpty ? fallback : captured

        isVoiceRecording = false
        isVoiceExiting = false
        voiceElapsed = 0
        voiceTranscript = ""
        voiceAudioLevel = 0
        voiceAudioLevels = Array(repeating: 0.06, count: 32)

        guard !finalText.isEmpty else {
            errorMessage = "Aucune voix détectée — réessaie."
            return false
        }

        inputText = finalText
        errorMessage = nil
        return true
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
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { break }
                voiceElapsed = Date().timeIntervalSince(startedAt)
                voiceTranscript = CoachSpeechTranscriber.shared.partialTranscript
                voiceAudioLevel = CoachSpeechTranscriber.shared.audioLevel
                voiceAudioLevels = CoachSpeechTranscriber.shared.audioLevels
            }
        }
    }

    private func sendPrompt(_ trimmed: String, persistUserMessage: Bool) async {
        let cleaned = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard let conversationId = libraryStore.activeConversationId else { return }

        if persistUserMessage {
            let userCountBefore = libraryStore.activeConversation?.messages.filter { $0.role == .user }.count ?? 0
            libraryStore.updateActiveConversation { $0.applyAutoTitle(from: cleaned) }
            let title = libraryStore.activeConversation?.title

            let userMsg = CoachMessage(role: .user, text: cleaned)
            messages.append(userMsg)
            await CoachSyncService.appendMessage(
                userMsg,
                userId: userId,
                conversationId: conversationId,
                title: title
            )
            inputText = ""

            if userCountBefore == 0 {
                Task { await refineConversationSubject(from: cleaned, conversationId: conversationId) }
            }
        }

        isSending = true
        streamingText = ""
        errorMessage = nil
        defer { isSending = false }

        do {
            let modIntent = CoachPlanModificationService.detectIntent(in: cleaned)
            var effectiveFocus = activePlanFocus
            if effectiveFocus == nil, let intent = modIntent, let plan = WelcomePlanStore.shared.plan {
                effectiveFocus = CoachPlanModificationService.buildFocus(intent: intent, plan: plan)
            }

            var assembled = ""
            for try await chunk in CoachEngine.streamChatMessage(
                cleaned,
                profile: profile,
                history: messages,
                planFocus: effectiveFocus
            ) {
                assembled += chunk
                streamingText = assembled
            }

            var planChanges: [String] = []
            if modIntent != nil || effectiveFocus?.mode == .modify, var plan = WelcomePlanStore.shared.plan {
                planChanges = CoachPlanModificationService.apply(
                    userRequest: cleaned,
                    coachResponse: assembled,
                    focus: effectiveFocus,
                    plan: &plan
                )
                WelcomePlanStore.shared.savePlan(plan)
            }

            if !planChanges.isEmpty {
                assembled = CoachPlanModificationService.confirmationPrefix(changes: planChanges) + assembled
            }

            streamingText = ""
            let model = ClaudeModel.preferred(for: .chat).rawValue
            let reply = CoachMessage(role: .assistant, text: assembled, modelUsed: model)
            messages.append(reply)
            CoachMemoryStore.shared.recordExchange(
                userText: cleaned,
                assistantText: assembled,
                conversationTitle: libraryStore.activeConversation?.title
            )
            CoachMemoryStore.shared.refreshConversationDigests(
                excludingActiveId: libraryStore.activeConversationId
            )

            Task {
                await CoachMemorySummarizer.refreshIfNeeded(profile: profile)
            }

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

    private func refineConversationSubject(from userText: String, conversationId: UUID) async {
        guard let refined = await CoachConversationSubjectService.refineWithAI(from: userText) else { return }
        libraryStore.updateConversation(conversationId) { $0.applySubjectLabel(refined) }
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

    func copyMessage(_ message: CoachMessage) {
        UIPasteboard.general.string = message.text
    }

    func beginEditingMessage(_ message: CoachMessage) async {
        guard message.role == .user,
              let index = messages.firstIndex(where: { $0.id == message.id }) else { return }

        messages = Array(messages.prefix(index))
        libraryStore.setActiveMessages(messages)
        inputText = message.text

        guard let conversationId = libraryStore.activeConversationId else { return }
        await CoachSyncService.replaceThread(
            CoachChatThread(messages: messages),
            userId: userId,
            conversationId: conversationId,
            title: libraryStore.activeConversation?.title
        )
    }
}
