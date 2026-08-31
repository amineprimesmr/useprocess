import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CoachChatViewModel {
    var messages: [CoachMessage] = []
    var inputText = ""
    var pendingAttachmentImages: [UIImage] = []
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
    var shouldOpenInlineCamera = false

    private var pendingPlanPatches: [UUID: PendingCoachPlanPatch] = [:]
    private let libraryStore = CoachConversationLibraryStore.shared
    private var profile: UnifiedUserProfile?
    private var userId: String? { profile?.userId.isEmpty == false ? profile?.userId : AuthUser.current?.uid }
    private var voiceTimerTask: Task<Void, Never>?
    /// Fil brouillon en mémoire — non enregistré dans l’historique tant qu’aucun message utilisateur.
    private var draftSessionId: UUID?
    private var didInitialLoad = false

    var conversations: [CoachConversation] {
        libraryStore.sortedConversations
    }

    var activeConversationId: UUID? {
        libraryStore.activeConversationId
    }

    var homePrompt: CoachHomePrompt {
        if let handoff = activeMealHandoff {
            return CoachMealHandoffBuilder.homePrompt(for: handoff, profile: profile)
        }
        return CoachHomeContext.resolve(profile: profile)
    }

    var showsContextualHome: Bool {
        guard !CoachPlanNavigationBridge.shared.hasPendingFaceScanHandoff else { return false }
        return !hasThreadContent && !isSending
    }

    private var hasThreadContent: Bool {
        messages.contains { message in
            message.role == .user
                || FaceScanCoachInsightService.isCoachInsightMessage(message)
        }
    }

    private var activePlanFocus: CoachPlanFocus?
    var activeMealHandoff: CoachMealHandoff?

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
        }
    }

    func loadThreadIfNeeded() async {
        if didInitialLoad {
            await consumePendingNavigationIfNeeded()
            return
        }
        didInitialLoad = true

        libraryStore.loadLocal()
        CoachConversationStore.stripInjectedProgramSummaryMessages()
        CoachConversationStore.stripLegacyWelcomeMessages()
        libraryStore.migrateLegacyThreadIfNeeded()
        libraryStore.purgeEmptyConversations()

        let bridge = CoachPlanNavigationBridge.shared

        if bridge.hasPendingFaceScanHandoff {
            await consumePendingNavigationIfNeeded()
            return
        }

        // Notif / deeplink : ouvrir la conversation demandée.
        if let conversationId = bridge.pendingConversationId,
           libraryStore.conversation(for: conversationId) != nil {
            draftSessionId = nil
            libraryStore.selectConversation(conversationId)
            await reloadActiveConversation()
            await consumePendingNavigationIfNeeded()
            return
        }

        // Ouverture normale : accueil vierge. L’historique reste dans la sidebar.
        await beginDraftSession()
        await consumePendingNavigationIfNeeded()
    }

    func consumePendingPlanPromptIfNeeded() async {
        guard let prompt = CoachPlanNavigationBridge.shared.consumePendingPrompt() else { return }
        activePlanFocus = CoachPlanNavigationBridge.shared.consumePendingFocus()
        await sendPrompt(prompt, persistUserMessage: true)
        activePlanFocus = nil
    }

    func consumePendingNavigationIfNeeded() async {
        if let conversationId = CoachPlanNavigationBridge.shared.pendingConversationId {
            CoachPlanNavigationBridge.shared.pendingConversationId = nil
            if conversationId != libraryStore.activeConversationId {
                await selectConversation(conversationId)
            }
        }
        if let checkInPrompt = CoachPlanNavigationBridge.shared.consumePendingCheckInPrompt() {
            await sendPrompt(checkInPrompt, persistUserMessage: true)
            return
        }
        if let handoff = CoachPlanNavigationBridge.shared.consumePendingFaceScanHandoff() {
            await deliverCoachFirstFaceScanAnalysis(handoff)
            return
        }
        if let handoff = CoachPlanNavigationBridge.shared.consumePendingMealHandoff() {
            if let prompt = CoachPlanNavigationBridge.shared.consumePendingPrompt() {
                await sendMealCoachPrompt(prompt, handoff: handoff)
            } else {
                activeMealHandoff = handoff
            }
            return
        }
        await consumePendingPlanPromptIfNeeded()
    }

    func deliverCoachFirstFaceScanAnalysis(_ handoff: FaceScanCoachHandoff) async {
        draftSessionId = nil
        resetVoiceStateImmediately()
        clearPendingAttachment()
        pendingPlanPatches = [:]
        isSending = false
        streamingText = ""
        errorMessage = nil
        activeMealHandoff = nil

        let reply = handoff.assistantMessage
        let conversationId = CoachDebloatJourneyStore.ensureConversation(in: CoachConversationLibraryStore.shared)
        let scanNumber = FaceScanHistoryStore.shared.history.count
        let userMessage = CoachDebloatJourneyStore.faceScanUserMessage(
            scanId: handoff.resultId,
            scanNumber: max(scanNumber, 1)
        )

        libraryStore.selectConversation(conversationId)
        libraryStore.updateConversation(conversationId) { conversation in
            conversation.append(userMessage)
            conversation.append(reply)
            if CoachConversation.isUntitled(conversation.title) {
                conversation.title = AppCopy.tSync("Trajectoire debloat", en: "Debloat trajectory")
                conversation.subjectLabel = AppCopy.tSync("Trajectoire debloat", en: "Debloat trajectory")
            }
        }

        let thread = libraryStore.conversation(for: conversationId)?.messages ?? [userMessage, reply]

        // État UI atomique — jamais d’accueil « Salut… » entre-temps.
        messages = thread

        await persistPreGeneratedAssistantMessage(reply, conversationId: conversationId)
    }

    func sendFaceScanHandoff(for result: FaceScanResult, insight: FaceScanAIInsight? = nil) async {
        let history = FaceScanEvolutionEngine.dailyHistory(from: FaceScanHistoryStore.shared.history)
        let resolvedInsight = insight ?? FaceScanAIInsightBuilder.insight(
            for: result,
            history: history,
            context: FaceScanInsightContext.fromTodayHealth()
        )
        let message = FaceScanCoachInsightService.immediateCoachMessage(
            for: result,
            insight: resolvedInsight
        )

        await deliverCoachFirstFaceScanAnalysis(
            FaceScanCoachHandoff(resultId: result.id, assistantMessage: message)
        )

        Task {
            _ = await FaceScanCoachInsightService.ensureCoachMessage(
                for: result,
                insight: resolvedInsight,
                profile: profile
            )
        }
    }

    private func persistPreGeneratedAssistantMessage(_ reply: CoachMessage, conversationId: UUID) async {
        guard libraryStore.activeConversationId == conversationId else { return }

        let title = libraryStore.activeConversation?.title
        await CoachSyncService.appendMessage(
            reply,
            userId: userId,
            conversationId: conversationId,
            title: title
        )

        let parsedReply = CoachResponseParser.parseFull(reply.text)
        CoachPostReplyService.applySideEffects(
            parsed: parsedReply,
            userText: "",
            rawAssistantText: reply.text
        )
        CoachMemoryStore.shared.recordExchange(
            userText: AppCopy.tSync("Scan visage du jour", en: "Today's face scan"),
            assistantText: reply.text,
            conversationTitle: title
        )
        CoachMemoryStore.shared.refreshConversationDigests(
            excludingActiveId: libraryStore.activeConversationId
        )

        Task {
            await CoachMemorySummarizer.refreshIfNeeded(profile: profile)
        }
    }

    func sendMealCoachPrompt(_ prompt: String, handoff: CoachMealHandoff) async {
        let augmented = CoachMealHandoffBuilder.augmentedPrompt(prompt, handoff: handoff)
        activeMealHandoff = nil
        await sendPrompt(augmented, persistUserMessage: true)
    }

    func reloadForEveningDelivery() async {
        if let eveningConversation = libraryStore.conversationWithEveningMessageToday() {
            if libraryStore.activeConversationId != eveningConversation.id {
                await selectConversation(eveningConversation.id)
            } else {
                await reloadActiveConversation()
            }
            return
        }
        await reloadActiveConversation()
    }

    func enrichment(for message: CoachMessage) -> CoachMessageEnrichment? {
        let isFaceScanInsight = FaceScanCoachInsightService.isCoachInsightMessage(message)
        let resolvedActions = isFaceScanInsight ? [] : contextualActions(for: message)
        let sanitizedFollowUps = CoachFollowUpSanitizer.sanitized(message.followUps ?? [])
        let displayFollowUps = (resolvedActions.isEmpty && !isFaceScanInsight) ? sanitizedFollowUps : []

        if let base = message.enrichment {
            var deepLink = base.deepLink
            if isFaceScanInsight {
                deepLink = nil
            } else if deepLink?.action == .plan {
                deepLink = nil
            } else if resolvedActions.contains(where: { $0.kind == .openJournal }) {
                deepLink = nil
            }

            return CoachMessageEnrichment(
                displayText: base.displayText,
                reasoning: nil,
                followUps: displayFollowUps,
                deepLink: nil,
                contextualActions: resolvedActions.filter { $0.kind == .applyPlanChanges }
            )
        }

        guard !resolvedActions.isEmpty || !displayFollowUps.isEmpty else { return nil }
        return CoachMessageEnrichment(
            displayText: message.text,
            reasoning: nil,
            followUps: displayFollowUps,
            deepLink: nil,
            contextualActions: resolvedActions.filter { $0.kind == .applyPlanChanges }
        )
    }

    func contextualActions(for message: CoachMessage) -> [CoachContextualAction] {
        if FaceScanCoachInsightService.isCoachInsightMessage(message) {
            return []
        }
        let userText = precedingUserText(for: message)
        return CoachContextualActionResolver.resolve(
            userText: userText,
            assistantText: message.text,
            parsedActions: message.resolvedContextualActions,
            meal: nil,
            hasPendingPlanPatch: pendingPlanPatches[message.id] != nil
        )
    }

    func executeContextualAction(_ action: CoachContextualAction, for message: CoachMessage) async {
        switch action.kind {
        case .validateMeal:
            guard let meal = CoachMealMessageDetector.mealContent(from: message.text),
                  meal.isValid,
                  let plan = WelcomePlanStore.shared.plan,
                  let day = OriginPlanPresenter.todayDay(in: plan) else {
                errorMessage = AppCopy.t(
                    "Impossible de valider ce repas pour aujourd'hui.",
                    en: "Couldn't log this meal for today."
                )
                return
            }
            WelcomePlanStore.shared.saveValidatedMeal(dayId: day.id, meal: meal, slot: meal.timeSlot)
            WelcomePlanStore.shared.clearDraftMeal(dayId: day.id, slot: meal.timeSlot)
            ProcessToastCenter.shared.show(
                "Repas ajouté",
                en: "Meal added",
                description: "Ajouté à ton plan du jour.",
                en: "Added to today's plan.",
                symbol: "fork.knife.circle.fill",
                tintColor: Color(red: 0.22, green: 0.78, blue: 0.48)
            )

        case .saveMealDraft:
            guard let meal = CoachMealMessageDetector.mealContent(from: message.text),
                  meal.isValid,
                  let plan = WelcomePlanStore.shared.plan,
                  let day = OriginPlanPresenter.todayDay(in: plan) else { return }
            WelcomePlanStore.shared.saveDraftMeal(dayId: day.id, meal: meal, slot: meal.timeSlot)
            ProcessToastCenter.shared.show(
                "Suggestion enregistrée",
                en: "Suggestion saved",
                description: "Brouillon repas sauvegardé.",
                en: "Meal draft saved.",
                symbol: "tray.and.arrow.down.fill",
                tintColor: .blue
            )

        case .modifyMeal:
            let prompt = action.payload.map {
                AppCopy.t("Je veux ajuster ce repas (\($0)) : ", en: "I want to adjust this meal (\($0)): ")
            } ?? AppCopy.t("Je veux ajuster ce repas : ", en: "I want to adjust this meal: ")
            inputText = prompt
            return

        case .anotherMeal:
            let slot = action.payload ?? AppCopy.t("ce créneau", en: "this slot")
            await sendFollowUp(AppCopy.t(
                "Autre idée de repas pour \(slot).",
                en: "Another meal idea for \(slot)."
            ))

        case .addToShoppingList:
            guard let meal = CoachMealMessageDetector.mealContent(from: message.text),
                  let plan = WelcomePlanStore.shared.plan,
                  let day = OriginPlanPresenter.todayDay(in: plan) else { return }
            WelcomePlanStore.shared.addMealToShoppingList(meal, dayId: day.id)
            ProcessToastCenter.shared.show(
                "Liste de courses",
                en: "Grocery list",
                description: "Ingrédients ajoutés.",
                en: "Ingredients added.",
                symbol: "cart.fill",
                tintColor: Color(red: 0.98, green: 0.72, blue: 0.18)
            )

        case .applyPlanChanges:
            guard let patch = pendingPlanPatches[message.id],
                  var plan = WelcomePlanStore.shared.plan else { return }
            let changes = CoachPlanModificationService.apply(
                userRequest: patch.userRequest,
                coachResponse: patch.coachResponse,
                focus: patch.focus,
                plan: &plan
            )
            WelcomePlanStore.shared.savePlan(plan, structureChanged: true)
            pendingPlanPatches.removeValue(forKey: message.id)
            let confirmation = changes.isEmpty
                ? AppCopy.t("Programme mis à jour.", en: "Program updated.")
                : CoachPlanModificationService.confirmationPrefix(changes: changes).trimmingCharacters(in: .whitespacesAndNewlines)
            ProcessToastCenter.shared.show(
                ProcessToast(
                    symbol: "calendar.badge.checkmark",
                    title: AppCopy.t("Programme mis à jour", en: "Program updated"),
                    description: confirmation,
                    tintColor: Color(red: 0.34, green: 0.62, blue: 0.98),
                    autoDismissInterval: 4
                )
            )

        case .swapWorkout:
            await sendFollowUp(action.payload ?? AppCopy.t(
                "Propose une autre séance adaptée à ma situation aujourd'hui.",
                en: "Suggest another session that fits my situation today."
            ))

        case .openPlan, .openJournal:
            return

        case .takePhoto:
            shouldOpenInlineCamera = true
            return

        case .followUp:
            if let payload = action.payload {
                await sendFollowUp(payload)
            } else {
                inputText = action.label + " "
            }
        }
    }

    private func precedingUserText(for message: CoachMessage) -> String {
        guard let index = messages.firstIndex(where: { $0.id == message.id }),
              index > 0 else { return "" }
        let previous = messages[index - 1]
        return previous.role == .user ? previous.text : ""
    }

    func sendFollowUp(_ text: String) async {
        await sendPrompt(text, persistUserMessage: true)
    }

    func selectConversation(_ id: UUID) async {
        guard id != libraryStore.activeConversationId else { return }
        draftSessionId = nil
        libraryStore.selectConversation(id)
        await reloadActiveConversation()
    }

    func createNewConversation() async {
        await beginDraftSession()
        onActiveConversationChanged()
    }

    private func beginDraftSession() async {
        resetVoiceStateImmediately()
        clearPendingAttachment()
        pendingPlanPatches = [:]
        isSending = false
        streamingText = ""
        errorMessage = nil

        draftSessionId = UUID()
        libraryStore.clearActiveSelection()
        messages = []
    }

    private func ensurePersistedConversationId() async -> UUID {
        if let activeId = libraryStore.activeConversationId,
           libraryStore.conversation(for: activeId) != nil {
            draftSessionId = nil
            return activeId
        }

        let draftId = draftSessionId ?? UUID()
        draftSessionId = nil
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
        }

        await CoachSyncService.deleteConversation(id: id, userId: userId)
        libraryStore.deleteConversation(id)
        libraryStore.purgeEmptyConversations()

        if wasActive {
            await beginDraftSession()
        }
    }

    func deleteAllConversations() async {
        let ids = libraryStore.sortedConversations.map(\.id)
        for id in ids {
            await deleteConversation(id)
        }
    }

    func resyncConversationHistory() async {
        await CoachIntelligenceSettingsStore.shared.resyncConversationHistory()
        if libraryStore.activeConversationId != nil {
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
        pendingPlanPatches = [:]
        isSending = false
        streamingText = ""

        let stored = await CoachSyncService.loadConversation(userId: userId, conversationId: id)
        messages = Self.filteredCoachMessages(stored.messages)
        if messages.count != stored.messages.count {
            libraryStore.setActiveMessages(messages)
        }
    }

    func onActiveConversationChanged() {
        activeMealHandoff = nil
    }

    private static func filteredCoachMessages(_ messages: [CoachMessage]) -> [CoachMessage] {
        CoachHomeContext.sanitizedMessages(
            messages
                .filter { !CoachConversationStore.shouldHideProgramSummaryMessage($0) }
                .map { CoachResponseParser.reparsedMessageIfNeeded($0) }
        )
    }

    func sendCurrentMessage() async {
        guard !isSending else { return }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pendingAttachmentImages.isEmpty {
            await sendImageAttachments(pendingAttachmentImages, caption: trimmed)
            return
        }

        guard !trimmed.isEmpty else { return }
        if let handoff = activeMealHandoff {
            let augmented = CoachMealHandoffBuilder.augmentedPrompt(trimmed, handoff: handoff)
            activeMealHandoff = nil
            await sendPrompt(augmented, userDisplayText: trimmed, persistUserMessage: true)
        } else {
            await sendPrompt(trimmed, persistUserMessage: true)
        }
    }

    func stageImageAttachment(_ image: UIImage) {
        pendingAttachmentImages.append(image)
    }

    func clearPendingAttachment() {
        pendingAttachmentImages = []
    }

    func removePendingAttachment(at index: Int) {
        guard pendingAttachmentImages.indices.contains(index) else { return }
        pendingAttachmentImages.remove(at: index)
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
            errorMessage = AppCopy.t("Aucune voix détectée — réessaie.", en: "No voice detected — try again.")
            return false
        }

        inputText = finalText
        errorMessage = nil
        return true
    }

    func sendHomeSuggestion(_ suggestion: CoachHomeSuggestion) async {
        guard !isSending else { return }
        if let handoff = activeMealHandoff {
            let augmented = CoachMealHandoffBuilder.augmentedPrompt(suggestion.prompt, handoff: handoff)
            activeMealHandoff = nil
            await sendPrompt(augmented, userDisplayText: suggestion.userMessage, persistUserMessage: true)
        } else {
            await sendPrompt(
                suggestion.prompt,
                userDisplayText: suggestion.userMessage,
                persistUserMessage: true
            )
        }
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

        if CoachIntelligenceSettingsStore.shared.isEnabled,
           !CoachIntelligenceSettingsStore.shared.canSendCoachMessage {
            errorMessage = CoachIntelligenceSettingsStore.shared.quotaExceededMessage
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
        CoachIntelligenceSettingsStore.shared.recordCoachMessageSent()

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
            let shouldDeferPlanApply = modIntent != nil || effectiveFocus?.mode == .modify

            if !shouldDeferPlanApply,
               modIntent != nil || effectiveFocus?.mode == .modify,
               var plan = WelcomePlanStore.shared.plan {
                planChanges = CoachPlanModificationService.apply(
                    userRequest: cleaned,
                    coachResponse: assembled,
                    focus: effectiveFocus,
                    plan: &plan
                )
                WelcomePlanStore.shared.savePlan(plan, structureChanged: true)
            }

            if !planChanges.isEmpty {
                assembled = CoachPlanModificationService.confirmationPrefix(changes: planChanges) + assembled
            }

            let parsedReply = CoachResponseParser.parseFull(assembled)
            var enrichment = parsedReply.enrichment
            let proposesPlanChange = CoachPlanModificationService.coachProposesApplyingChange(
                in: parsedReply.enrichment.displayText
            )
            if shouldDeferPlanApply, proposesPlanChange {
                if !enrichment.contextualActions.contains(where: { $0.kind == .applyPlanChanges }) {
                    enrichment.contextualActions.insert(CoachContextualAction(kind: .applyPlanChanges), at: 0)
                }
            }
            let parsed = enrichment
            let model = ClaudeModel.preferred(for: .chat).rawValue
            let reply = Self.assistantMessage(
                from: parsed,
                rawText: assembled,
                modelUsed: model
            )

            if shouldDeferPlanApply, proposesPlanChange {
                pendingPlanPatches[reply.id] = PendingCoachPlanPatch(
                    userRequest: cleaned,
                    coachResponse: assembled,
                    focus: effectiveFocus
                )
            }

            withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                messages.append(reply)
            }
            isSending = false
            streamingText = ""
            CoachPostReplyService.applySideEffects(
                parsed: parsedReply,
                userText: cleaned,
                rawAssistantText: assembled
            )
            CoachMemoryStore.shared.recordExchange(
                userText: cleaned,
                assistantText: parsed.displayText,
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
            notifyReplyIfNeeded(conversationId: conversationId, replyText: parsed.displayText)
        } catch {
            errorMessage = userFacingCoachError(error)
            isSending = false
            streamingText = ""
        }
    }

    private func notifyReplyIfNeeded(conversationId: UUID, replyText: String) {
        Task {
            await CoachIntelligenceNotificationService.notifyReplyReady(
                conversationId: conversationId,
                replyText: replyText,
                conversationTitle: libraryStore.conversation(for: conversationId)?.sidebarSubject
            )
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

    func sendImageAttachments(
        _ images: [UIImage],
        caption: String = "",
        userDisplayText: String? = nil
    ) async {
        guard !isSending, !images.isEmpty else { return }

        if CoachIntelligenceSettingsStore.shared.isEnabled,
           !CoachIntelligenceSettingsStore.shared.canSendCoachMessage {
            errorMessage = CoachIntelligenceSettingsStore.shared.quotaExceededMessage
            return
        }

        let conversationId = await ensurePersistedConversationId()

        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let userText: String = {
            if let userDisplayText,
               !userDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return userDisplayText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !trimmedCaption.isEmpty { return trimmedCaption }
            return images.count == 1
                ? AppCopy.tSync("📷 Photo", en: "📷 Photo")
                : AppCopy.tSync("📷 \(images.count) photos", en: "📷 \(images.count) photos")
        }()
        let analysisPrompt: String = {
            if !trimmedCaption.isEmpty { return trimmedCaption }
            if images.count == 1 {
                return AppCopy.tSync(
                    "Analyse cette image en 2-3 phrases max. Contexte coach useprocess.",
                    en: "Analyze this image in 2–3 sentences max. useprocess coach context."
                )
            }
            return AppCopy.tSync(
                "Analyse ces \(images.count) images en 2-4 phrases max. Contexte coach useprocess.",
                en: "Analyze these \(images.count) images in 2–4 sentences max. useprocess coach context."
            )
        }()

        pendingAttachmentImages = []
        inputText = ""

        let messageId = UUID()
        CoachChatAttachmentImageStore.save(images: images, messageId: messageId)

        let userMsg = CoachMessage(
            id: messageId,
            role: .user,
            text: CoachChatImageMessageMarker.embed(messageId: messageId, displayText: userText)
        )
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
        CoachIntelligenceSettingsStore.shared.recordCoachMessageSent()
        defer { isSending = false; streamingText = "" }

        do {
            let rawReply = try await CoachEngine.analyzeAttachedImages(
                images,
                caption: analysisPrompt,
                profile: profile,
                history: messages
            )
            guard libraryStore.activeConversationId == conversationId else { return }
            let parsedReply = CoachResponseParser.parseFull(rawReply.text)
            let parsed = parsedReply.enrichment
            let reply = Self.assistantMessage(
                from: parsed,
                rawText: rawReply.text,
                modelUsed: rawReply.modelUsed,
                id: rawReply.id,
                createdAt: rawReply.createdAt
            )
            CoachPostReplyService.applySideEffects(
                parsed: parsedReply,
                userText: analysisPrompt,
                rawAssistantText: rawReply.text
            )
            withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                messages.append(reply)
            }
            await CoachSyncService.appendMessage(
                reply,
                userId: userId,
                conversationId: conversationId,
                title: libraryStore.activeConversation?.title
            )
            notifyReplyIfNeeded(conversationId: conversationId, replyText: parsed.displayText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendFileAttachment(name: String) async {
        await sendPrompt(
            AppCopy.t("📎 Fichier : \(name)", en: "📎 File: \(name)"),
            persistUserMessage: true
        )
    }

    func copyMessage(_ message: CoachMessage) {
        UIPasteboard.general.string = message.text
        HapticManager.shared.notification(.success)
        ProcessToastCenter.shared.show(
            "Copié",
            en: "Copied",
            description: "Message copié dans le presse-papiers.",
            en: "Message copied to clipboard.",
            symbol: "doc.on.doc.fill",
            tintColor: .blue
        )
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

    private static func assistantMessage(
        from parsed: CoachMessageEnrichment,
        rawText: String,
        modelUsed: String?,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) -> CoachMessage {
        let base = CoachMessage.assistant(from: parsed, modelUsed: modelUsed)
        let text: String = {
            if let intro = MealSuggestionParser.coachIntro(from: rawText),
               MealSuggestionParser.parse(rawText)?.isValid == true {
                return intro
            }
            let display = parsed.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
            return display.isEmpty ? base.text : display
        }()

        return CoachMessage(
            id: id,
            role: .assistant,
            text: text,
            createdAt: createdAt,
            modelUsed: modelUsed,
            reasoning: nil,
            followUps: base.followUps,
            deepLinkAction: nil,
            deepLinkLabel: nil,
            contextualActions: base.contextualActions
        )
    }
}
