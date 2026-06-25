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
    /// Fil brouillon en mémoire — non enregistré dans l’historique tant qu’aucun message utilisateur.
    private var draftSessionId: UUID?
    private var didInitialLoad = false
    /// Garde le brouillon vierge du lancement froid malgré le rebind profil qui arrive souvent juste après.
    private var shouldKeepColdLaunchDraft = false

    var conversations: [CoachConversation] {
        libraryStore.sortedConversations
    }

    var activeConversationId: UUID? {
        libraryStore.activeConversationId
    }

    var isSidebarEnabled: Bool {
        !isSending && !isVoiceRecording
    }

    var homePrompt: CoachHomePrompt {
        CoachHomeContext.resolve(profile: profile)
    }

    var showsContextualHome: Bool {
        !messages.contains(where: { $0.role == .user }) && !isSending
    }

    var showsHomeInsteadOfInput: Bool {
        showsContextualHome && homePrompt.replacesChatInput && !homeInputUnlocked
    }

    var homeActionsRevealed = false
    var homeInputUnlocked = false

    /// Accueils déjà animés (par conversation + texte d’accueil).
    private var completedHomePresentationKeys: Set<String> = []

    private var activePlanFocus: CoachPlanFocus?

    func bind(profile: UnifiedUserProfile?) {
        let previousUserId = userId
        self.profile = profile
        let nextUserId = userId
        claudeConfigured = ClaudeConfiguration.isConfigured
        FaceScanHistoryStore.shared.reloadForUser(userId: profile?.userId)

        let didSwitchUser = {
            if let previousUserId, let nextUserId {
                return previousUserId != nextUserId
            }
            return previousUserId != nil && nextUserId == nil
        }()

        if didSwitchUser {
            didInitialLoad = false
            draftSessionId = nil
            shouldKeepColdLaunchDraft = false
        }
    }

    func loadThreadIfNeeded() async {
        if didInitialLoad {
            await consumePendingPlanPromptIfNeeded()
            return
        }
        didInitialLoad = true

        libraryStore.loadLocal()
        CoachConversationStore.stripInjectedProgramSummaryMessages()
        CoachConversationStore.stripLegacyWelcomeMessages()
        libraryStore.migrateLegacyThreadIfNeeded()
        libraryStore.purgeEmptyConversations()

        if CoachAppLaunchSession.consumeColdLaunchFreshConversation() {
            shouldKeepColdLaunchDraft = true
            await beginDraftSession()
            await consumePendingPlanPromptIfNeeded()
            return
        }

        if shouldKeepColdLaunchDraft && !messages.contains(where: { $0.role == .user }) {
            await beginDraftSession()
            await consumePendingPlanPromptIfNeeded()
            return
        }

        if let activeId = libraryStore.activeConversationId,
           let conversation = libraryStore.conversation(for: activeId),
           conversation.hasUserMessages {
            draftSessionId = nil
            await reloadActiveConversation()
            await consumePendingPlanPromptIfNeeded()
            return
        }

        if let recent = libraryStore.mostRecentConversationWithUserMessages() {
            libraryStore.selectConversation(recent.id)
            draftSessionId = nil
            await reloadActiveConversation()
            await consumePendingPlanPromptIfNeeded()
            return
        }

        await beginDraftSession()
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
        shouldKeepColdLaunchDraft = false
        draftSessionId = nil
        libraryStore.selectConversation(id)
        await reloadActiveConversation()
    }

    func createNewConversation() async {
        shouldKeepColdLaunchDraft = false
        await beginDraftSession()
        onActiveConversationChanged()
    }

    private func beginDraftSession() async {
        resetVoiceStateImmediately()
        clearPendingAttachment()
        isSending = false
        streamingText = ""
        errorMessage = nil

        draftSessionId = UUID()
        libraryStore.clearActiveSelection()
        messages = []
        resetHomePresentation()
    }

    private func ensurePersistedConversationId() async -> UUID {
        if let activeId = libraryStore.activeConversationId,
           libraryStore.conversation(for: activeId) != nil {
            draftSessionId = nil
            return activeId
        }

        let draftId = draftSessionId ?? UUID()
        draftSessionId = nil
        shouldKeepColdLaunchDraft = false
        let conversationId = libraryStore.promoteDraftConversation(id: draftId)
        return conversationId
    }

    func deleteConversation(_ id: UUID) async {
        let wasActive = libraryStore.activeConversationId == id

        if wasActive {
            voiceTimerTask?.cancel()
            resetVoiceStateImmediately()
            clearPendingAttachment()
            isSending = false
            streamingText = ""
            errorMessage = nil
            messages = []
            resetHomePresentation()
        }

        await CoachSyncService.deleteConversation(id: id, userId: userId)
        libraryStore.deleteConversation(id)
        libraryStore.purgeEmptyConversations()

        if libraryStore.sortedConversations.isEmpty {
            await beginDraftSession()
            return
        }

        if wasActive {
            await reloadActiveConversation()
        }
    }

    private func reloadActiveConversation() async {
        guard let id = libraryStore.activeConversationId else {
            await beginDraftSession()
            return
        }
        resetVoiceStateImmediately()
        clearPendingAttachment()
        isSending = false
        streamingText = ""

        let stored = await CoachSyncService.loadConversation(userId: userId, conversationId: id)
        messages = Self.filteredCoachMessages(stored.messages)
        if messages.count != stored.messages.count {
            libraryStore.setActiveMessages(messages)
        }
        syncHomePresentationFromCache()
    }

    func onHomeGreetingComplete() {
        completedHomePresentationKeys.insert(homePresentationKey())
        guard !homeActionsRevealed else { return }
        withAnimation(OnboardingProfileChatAnswerReveal.spring) {
            homeActionsRevealed = true
        }
    }

    func resetHomePresentation() {
        homeActionsRevealed = false
        homeInputUnlocked = false
    }

    func homePresentationKey() -> String {
        let conversationPart = libraryStore.activeConversationId?.uuidString
            ?? draftSessionId?.uuidString
            ?? "draft"
        return "\(conversationPart)|\(homePrompt.greetingText)"
    }

    var shouldSkipHomeAnimation: Bool {
        guard showsContextualHome else { return false }
        return completedHomePresentationKeys.contains(homePresentationKey())
    }

    func restoreHomePresentationIfNeeded() {
        guard shouldSkipHomeAnimation else { return }
        if !homeActionsRevealed {
            homeActionsRevealed = true
        }
    }

    func syncHomePresentationFromCache() {
        if shouldSkipHomeAnimation {
            homeActionsRevealed = true
        } else {
            homeActionsRevealed = false
        }
    }

    func onActiveConversationChanged() {
        homeInputUnlocked = false
        syncHomePresentationFromCache()
    }

    func unlockHomeChatInput() {
        homeInputUnlocked = true
    }

    private static func filteredCoachMessages(_ messages: [CoachMessage]) -> [CoachMessage] {
        CoachHomeContext.sanitizedMessages(
            messages.filter { !CoachConversationStore.shouldHideProgramSummaryMessage($0) }
        )
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
            voiceAudioLevels = Array(repeating: 0.06, count: 52)
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
            voiceAudioLevels = Array(repeating: 0.06, count: 52)
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
        voiceAudioLevels = Array(repeating: 0.06, count: 52)
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
        voiceAudioLevels = Array(repeating: 0.06, count: 52)

        guard !finalText.isEmpty else {
            errorMessage = "Aucune voix détectée — réessaie."
            return false
        }

        inputText = finalText
        errorMessage = nil
        return true
    }

    func sendHomeSuggestion(_ suggestion: CoachHomeSuggestion) async {
        guard !isSending else { return }
        await sendPrompt(
            suggestion.prompt,
            userDisplayText: suggestion.label,
            persistUserMessage: true
        )
    }

    func runTool(_ tool: CoachTool) async {
        guard !isSending else { return }
        guard ProcessPrivacyConsentStore.shared.canUseThirdPartyAI else {
            ProcessPrivacyConsentStore.shared.presentThirdPartyAIConsentIfNeeded {
                Task { await self.runTool(tool) }
            }
            return
        }
        let prompt = tool.label
        let conversationId = await ensurePersistedConversationId()
        libraryStore.updateActiveConversation { $0.applyAutoTitle(from: prompt) }
        let userMsg = CoachMessage(role: .user, text: "🔹 \(prompt)")
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
            let reply = try await CoachEngine.runTool(tool, profile: profile)
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

    private func sendPrompt(
        _ trimmed: String,
        userDisplayText: String? = nil,
        persistUserMessage: Bool
    ) async {
        let cleaned = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        guard ProcessPrivacyConsentStore.shared.canUseThirdPartyAI else {
            ProcessPrivacyConsentStore.shared.presentThirdPartyAIConsentIfNeeded {
                Task { await self.sendPrompt(cleaned, userDisplayText: userDisplayText, persistUserMessage: persistUserMessage) }
            }
            return
        }

        let conversationId: UUID
        if persistUserMessage {
            conversationId = await ensurePersistedConversationId()
        } else {
            guard let activeId = libraryStore.activeConversationId else { return }
            conversationId = activeId
        }
        let bubbleText: String = {
            if let userDisplayText,
               !userDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return userDisplayText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return cleaned
        }()

        if persistUserMessage {
            let userCountBefore = libraryStore.activeConversation?.messages.filter { $0.role == .user }.count ?? 0
            libraryStore.updateActiveConversation { $0.applyAutoTitle(from: bubbleText) }
            let title = libraryStore.activeConversation?.title

            let userMsg = CoachMessage(role: .user, text: bubbleText)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                messages.append(userMsg)
            }
            await CoachSyncService.appendMessage(
                userMsg,
                userId: userId,
                conversationId: conversationId,
                title: title
            )
            inputText = ""

            if userCountBefore == 0 {
                Task { await refineConversationSubject(from: bubbleText, conversationId: conversationId) }
            }
        }

        isSending = true
        streamingText = ""
        errorMessage = nil

        do {
            let modIntent = CoachPlanModificationService.detectIntent(in: cleaned)
            var effectiveFocus = activePlanFocus
            if effectiveFocus == nil, let intent = modIntent, let plan = WelcomePlanStore.shared.plan {
                effectiveFocus = CoachPlanModificationService.buildFocus(intent: intent, plan: plan)
            }

            var assembled = ""
            var lastError: Error?
            let maxAttempts = 3

            for attempt in 0..<maxAttempts {
                assembled = ""
                streamingText = ""

                do {
                    for try await chunk in CoachEngine.streamChatMessage(
                        cleaned,
                        profile: profile,
                        history: messages,
                        planFocus: effectiveFocus
                    ) {
                        assembled += chunk
                        streamingText = assembled
                    }
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    if error is ProcessPrivacyConsentError {
                        ProcessPrivacyConsentStore.shared.presentThirdPartyAIConsentIfNeeded {
                            Task { await self.sendPrompt(cleaned, userDisplayText: userDisplayText, persistUserMessage: false) }
                        }
                        isSending = false
                        streamingText = ""
                        return
                    }
                    let canRetry = CoachRemoteError.isRetryable(error) && attempt < maxAttempts - 1
                    if canRetry {
                        try? await Task.sleep(nanoseconds: UInt64(900_000_000 * UInt64(attempt + 1)))
                        continue
                    }
                    throw error
                }
            }

            if let lastError { throw lastError }

            let trimmedReply = assembled.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedReply.isEmpty else {
                throw CoachRemoteError.incompleteStream
            }

            guard libraryStore.activeConversationId == conversationId else {
                isSending = false
                streamingText = ""
                return
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

            let model = ClaudeModel.preferred(for: .chat).rawValue
            let reply = CoachMessage(role: .assistant, text: assembled, modelUsed: model)
            messages.append(reply)
            isSending = false
            streamingText = ""
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
            errorMessage = userFacingCoachError(error)
            isSending = false
            streamingText = ""
        }
    }

    private func userFacingCoachError(_ error: Error) -> String {
        if let remote = error as? CoachRemoteError {
            return remote.localizedDescription
        }
        return error.localizedDescription
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
        guard !isSending else { return }
        let conversationId = await ensurePersistedConversationId()

        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let userText = trimmedCaption.isEmpty ? "📷 Photo" : trimmedCaption
        let analysisPrompt = trimmedCaption.isEmpty
            ? "Analyse cette image en 2-3 phrases max. Contexte coach useprocess."
            : trimmedCaption

        pendingAttachmentImage = nil
        inputText = ""

        let userMsg = CoachMessage(role: .user, text: userText)
        libraryStore.updateActiveConversation { $0.applyAutoTitle(from: userText) }
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
            guard libraryStore.activeConversationId == conversationId else { return }
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
