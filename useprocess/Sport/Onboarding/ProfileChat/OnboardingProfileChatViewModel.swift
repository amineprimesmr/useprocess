//
//  OnboardingProfileChatViewModel.swift
//  useprocess
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class OnboardingProfileChatViewModel {
    enum AnalysisPhase: Equatable {
        case idle
        case running
        case complete
    }

    private(set) var conversationEngine: MossConversationEngine!

    var isMessageAnimating: Bool { conversationEngine?.isTyping ?? false }
    var isSubmittingAnswer = false
    var shouldFinish = false
    var currentQuestion: OnboardingProfileChatQuestion?
    var analysisPhase: AnalysisPhase = .idle
    var analysisProgressPanelVisible = false
    var analysisProgress: Double = 0
    var analysisDisplayedPercentage = 0
    var analysisPhaseLabel = OnboardingAnalysisProgressConfig.answersAnalysisSteps[0].phaseLabel
    var analysisPhaseIndex = 0
    var analysisElapsedSeconds = 0
    var analysisIsPaused = false
    var analysisLetsGoUnlocked = false

    enum ProgramCreationPhase: Equatable {
        case idle
        case running
        case complete
    }

    var programCreationPhase: ProgramCreationPhase = .idle
    var programCreationProgress: Double = 0
    var programCreationDisplayedPercentage = 0

    enum FaceScanInlinePhase: Equatable {
        case idle
        case capturing
        case analyzing
        case results
    }

    var faceScanInlinePhase: FaceScanInlinePhase = .idle
    var inlineFaceScanResult: FaceScanResult?
    var inlineFaceScanResultsUnlocked = false
    var inlineFaceScanProgress: Double = 0
    var inlineFaceScanDisplayedPercentage = 0
    var inlineFaceScanPhaseIndex = 0
    var inlineFaceScanPhaseLabel = OnboardingAnalysisProgressConfig.faceScanAnalysisSteps[0].phaseLabel
    var inlineFaceScanElapsedSeconds = 0

    var showsInlineFaceScanFlow: Bool {
        false
    }

    var showsInlineFaceScanSection: Bool {
        guard let conversationEngine else { return false }
        return currentQuestion?.id == "face_scan_offer"
            && !shouldFinish
            && conversationEngine.controlsVisible
            && !conversationEngine.isTyping
            && !isSubmittingAnswer
            && isQuestionReadyForAnswers
    }

    var inlineFaceScanCapturedPayload: FaceScanCapturePayload? {
        inlineFaceScanPayload
    }

    private var inlineFaceScanPayload: FaceScanCapturePayload?
    private var inlineFaceScanMarkers: FaceWellnessMarkers?
    private var inlineFaceScanTask: Task<Void, Never>?
    private var inlineFaceScanElapsedTask: Task<Void, Never>?

    var showsAnswerOptions: Bool {
        guard let conversationEngine else { return false }
        return !shouldFinish
            && conversationEngine.controlsVisible
            && !conversationEngine.isTyping
            && !isSubmittingAnswer
            && !showsInlineFaceScanFlow
            && currentQuestion != nil
            && isQuestionReadyForAnswers
            && currentQuestion?.kind != .answersAnalysis
    }

    var showsAnalysisSection: Bool {
        !shouldFinish
            && currentQuestion?.kind == .answersAnalysis
            && analysisProgressPanelVisible
    }

    var showsProgramCreationSection: Bool {
        !shouldFinish && (programCreationPhase == .running || programCreationPhase == .complete)
    }

    /// Ancien CTA Apple dans le chat — toujours off. Auth uniquement sur la page résultats scan.
    var showsContinueAfterAnalysis: Bool { false }

    /// Après relance : rouvrir la page résultats (Sign in Apple) si scan déjà fait.
    private(set) var pendingDedicatedResultsReopen: FaceScanResult?
    /// Après relance : chat terminé sans auth à refaire → enchaîner l’étape suivante.
    private(set) var shouldAutoFinishAfterResume = false

    private func animate(_ animation: Animation, _ changes: () -> Void) {
        withAnimation(animation, changes)
    }

    private var isQuestionReadyForAnswers = false

    private var onboardingViewModel: OnboardingViewModel?
    private var healthManager: HealthManager?
    private var permissionsManager: PermissionsManager?
    private var questions: [OnboardingProfileChatQuestion] = []
    private var currentIndex = 0
    private var hasStarted = false
    private var didFinish = false
    private var analysisTask: Task<Void, Never>?
    private var programCreationTask: Task<Void, Never>?
    private var analysisElapsedTask: Task<Void, Never>?

    func bind(
        _ viewModel: OnboardingViewModel,
        engine: MossConversationEngine,
        healthManager: HealthManager,
        permissionsManager: PermissionsManager
    ) {
        conversationEngine = engine
        onboardingViewModel = viewModel
        self.healthManager = healthManager
        self.permissionsManager = permissionsManager
        guard !hasStarted else { return }
        questions = OnboardingProfileChatQuestionBank.questions(for: viewModel)
        currentIndex = questions.firstIndex {
            !viewModel.completedProfileChatQuestionIDs.contains($0.id)
        } ?? max(0, questions.count - 1)
        currentQuestion = nil
    }

    func startIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        guard let viewModel = onboardingViewModel else { return }
        let hasSavedProgress = !viewModel.completedProfileChatQuestionIDs.isEmpty

        if hasSavedProgress {
            restoreConversationFromSavedProgress()
            await resumeFromSavedProgress()
        } else {
            await presentFirstQuestionAfterOpening()
        }
    }

    private func restoreConversationFromSavedProgress() {
        guard let viewModel = onboardingViewModel else { return }
        OnboardingMossChatHelpers.replaySavedConversation(
            engine: conversationEngine,
            questions: questions,
            completedIDs: Set(viewModel.completedProfileChatQuestionIDs),
            viewModel: viewModel
        )
    }

    private func resumeFromSavedProgress() async {
        guard let viewModel = onboardingViewModel else { return }

        if viewModel.shouldReopenFaceScanResultsAfterBack || viewModel.presentedFaceScanResult != nil {
            return
        }

        let completed = viewModel.completedProfileChatQuestionIDs
        let allQuestionIDs = Set(questions.map(\.id))

        if allQuestionIDs.isSubset(of: completed) {
            analysisLetsGoUnlocked = false
            currentQuestion = nil
            isQuestionReadyForAnswers = false

            if let result = restoredFaceScanResultForAuthGate() {
                inlineFaceScanResult = result
                pendingDedicatedResultsReopen = result
                return
            }

            // Scan sauté / déjà connecté / pas de Firebase → on enchaîne, pas de Sign in dans le chat.
            shouldAutoFinishAfterResume = true
            return
        }

        guard currentIndex < questions.count else { return }

        let question = OnboardingProfileChatQuestionBank.resolvedQuestion(
            questions[currentIndex],
            for: viewModel
        )
        questions[currentIndex] = question
        currentQuestion = question
        isQuestionReadyForAnswers = false

        appendAssistantMessagesInstant(for: question)

        switch question.kind {
        case .autoPlanCreation:
            await beginProgramCreationFlow()
        case .answersAnalysis:
            isQuestionReadyForAnswers = true
            beginAnswersAnalysisPanel()
            startAnswersAnalysisAnimation()
            await analysisTask?.value
            if analysisPhase == .complete {
                await presentAnalysisDetailMessage()
            }
        case .faceScanOffer:
            isQuestionReadyForAnswers = true
        default:
            isQuestionReadyForAnswers = true
        }
    }

    private func appendAssistantMessagesInstant(for question: OnboardingProfileChatQuestion) {
        conversationEngine.speak(
            OnboardingMossChatHelpers.mossLines(for: question),
            instant: true
        )
    }

    private func presentCurrentQuestion(initialDelay: Bool) async {
        guard let question = currentQuestion else { return }

        isQuestionReadyForAnswers = false

        let lines = OnboardingMossChatHelpers.mossLines(
            for: question,
            emotionalFirstBlock: question.id == "intro_swollen_face"
        )
        guard !lines.isEmpty else {
            await finalizeQuestionPresentation()
            return
        }

        if initialDelay {
            try? await Task.sleep(nanoseconds: 320_000_000)
        }

        await speakMossLines(lines)
        await finalizeQuestionPresentation()
    }

    private func speakMossLines(_ lines: [MossLine]) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            conversationEngine.speak(lines, onBatchDone: {
                continuation.resume()
            })
        }
    }

    private func presentFirstQuestionAfterOpening() async {
        guard currentIndex < questions.count else { return }
        currentQuestion = questions[currentIndex]
        await presentCurrentQuestion(initialDelay: true)
    }

    func submitContinueAfterAnalysis() {
        guard showsContinueAfterAnalysis else { return }
        shouldFinish = true
    }

    func submitInfoContinue() async {
        guard !isSubmittingAnswer,
              let question = currentQuestion,
              question.kind == .infoContinue else { return }
        isSubmittingAnswer = true
        await recordAnswer(
            display: question.continueLabel ?? "Continuer",
            questionID: question.id
        )
    }

    /// Remonte d’une question / d’un texte dans le fil. `false` = quitter la discussion.
    @discardableResult
    func goBackInDiscussion() -> Bool {
        guard let viewModel = onboardingViewModel else { return false }

        // Annule animations / jobs en cours pour pouvoir remonter proprement.
        conversationEngine.reset()
        analysisTask?.cancel()
        programCreationTask?.cancel()
        inlineFaceScanTask?.cancel()
        stopAnalysisElapsedTimer()
        stopInlineFaceScanElapsedTimer()
        isSubmittingAnswer = false

        // Scan inline : d’abord sortir du flux capture/analyse/résultats.
        if faceScanInlinePhase != .idle {
            resetInlineFaceScanState()
            if let index = questions.firstIndex(where: { $0.id == "face_scan_offer" }) {
                currentIndex = index
                let question = OnboardingProfileChatQuestionBank.resolvedQuestion(
                    questions[index],
                    for: viewModel
                )
                questions[index] = question
                currentQuestion = question
                isQuestionReadyForAnswers = true
                rebuildMessages(upToCompletedExclusiveOf: "face_scan_offer")
                appendAssistantMessagesInstant(for: question)
            }
            analysisLetsGoUnlocked = false
            analysisPhase = .idle
            analysisProgressPanelVisible = false
            programCreationPhase = .idle
            shouldFinish = false
            return true
        }

        let orderedIDs = questions.map(\.id)
        let orderedCompleted = orderedIDs.filter { viewModel.completedProfileChatQuestionIDs.contains($0) }

        // Rien de validé : on est sur la 1re bulle → sortie vers l’étape précédente.
        guard let targetID = orderedCompleted.last,
              let targetIndex = orderedIDs.firstIndex(of: targetID) else {
            return false
        }

        viewModel.rewindProfileChat(from: targetID, orderedQuestionIDs: orderedIDs)
        clearSideEffectsIfNeeded(rewindingFrom: targetID)

        currentIndex = targetIndex
        analysisLetsGoUnlocked = false
        analysisPhase = .idle
        analysisProgressPanelVisible = false
        analysisProgress = 0
        programCreationPhase = .idle
        programCreationProgress = 0
        shouldFinish = false
        resetInlineFaceScanState()

        let question = OnboardingProfileChatQuestionBank.resolvedQuestion(
            questions[targetIndex],
            for: viewModel
        )
        questions[targetIndex] = question
        currentQuestion = question
        isQuestionReadyForAnswers = true

        rebuildMessages(upToCompletedExclusiveOf: targetID)
        appendAssistantMessagesInstant(for: question)

        return true
    }

    private func rebuildMessages(upToCompletedExclusiveOf excludedID: String) {
        guard let viewModel = onboardingViewModel else { return }
        let completed = Set(
            viewModel.completedProfileChatQuestionIDs.filter { $0 != excludedID }
        )
        OnboardingMossChatHelpers.replaySavedConversation(
            engine: conversationEngine,
            questions: questions,
            completedIDs: completed,
            viewModel: viewModel
        )
    }

    private func clearSideEffectsIfNeeded(rewindingFrom questionID: String) {
        switch questionID {
        case "debloat_driver":
            onboardingViewModel?.onboardingDebloatDrivers = []
        case "hydration_level":
            guard var profile = onboardingViewModel?.nutritionProfile else { break }
            profile.hydrationLevel = nil
            profile.hasSufficientHydration = nil
            onboardingViewModel?.nutritionProfile = profile
        case "junk_food":
            onboardingViewModel?.updateNutritionQuality(nil)
        case "sleep_hours":
            guard var sleep = onboardingViewModel?.sleepProfile else { break }
            sleep.averageSleepHours = nil
            sleep.sleepQuality = nil
            onboardingViewModel?.sleepProfile = sleep
        case "cardio_frequency":
            onboardingViewModel?.selectedTrainingFrequency = nil
            onboardingViewModel?.isTrainingFrequencySelected = false
        case "face_scan_offer", "scan_explanation":
            onboardingViewModel?.onboardingFaceMarkers = nil
            onboardingViewModel?.isFaceAnalysisCompleted = false
            inlineFaceScanResult = nil
        default:
            break
        }
    }

    func submitYesNo(_ yes: Bool) async {
        guard !isSubmittingAnswer, currentQuestion != nil else { return }
        isSubmittingAnswer = true
        await recordAnswer(display: yes ? "Oui" : "Non")
    }

    func submitSingleChoice(_ choiceId: String) async {
        guard !isSubmittingAnswer, let question = currentQuestion else { return }
        isSubmittingAnswer = true
        let label = question.choices.first(where: { $0.id == choiceId })?.label ?? choiceId

        switch question.id {
        case "debloat_driver":
            if let driver = OnboardingDebloatDriver(rawValue: choiceId) {
                onboardingViewModel?.onboardingDebloatDrivers = [driver]
            }
        case "hydration_level":
            if let level = HydrationLevel(rawValue: choiceId) {
                guard var profile = onboardingViewModel?.nutritionProfile else { break }
                profile.hydrationLevel = level
                profile.hasSufficientHydration = level != .poor && level != .veryPoor
                onboardingViewModel?.nutritionProfile = profile
            }
        case "junk_food":
            onboardingViewModel?.updateNutritionQuality(
                NutritionQuality(rawValue: choiceId) ?? .average
            )
        case "sleep_hours":
            if let hours = Double(choiceId) {
                guard var sleep = onboardingViewModel?.sleepProfile else { break }
                sleep.averageSleepHours = hours
                switch hours {
                case ..<5:
                    sleep.sleepQuality = .veryPoor
                case ..<6:
                    sleep.sleepQuality = .poor
                case ..<7:
                    sleep.sleepQuality = .average
                case ..<8:
                    sleep.sleepQuality = .good
                default:
                    sleep.sleepQuality = .excellent
                }
                onboardingViewModel?.sleepProfile = sleep
            }
        case "cardio_frequency":
            onboardingViewModel?.selectedTrainingFrequency = choiceId
            onboardingViewModel?.isTrainingFrequencySelected = true
            onboardingViewModel?.hasSportActivity = choiceId != "0-2"
        default:
            break
        }

        await recordAnswer(display: label, questionID: question.id)
    }

    func submitMultiChoice(_ choiceIds: Set<String>) async {
        guard !isSubmittingAnswer, let question = currentQuestion else { return }
        isSubmittingAnswer = true
        let labels = question.choices
            .filter { choiceIds.contains($0.id) }
            .map(\.label)
        if question.id == "debloat_driver" {
            onboardingViewModel?.onboardingDebloatDrivers = Set(
                choiceIds.compactMap(OnboardingDebloatDriver.init(rawValue:))
            )
        }
        await recordAnswer(display: labels.joined(separator: ", "), questionID: question.id)
    }

    func submitSearchedSport(_ sport: String) async {
        guard !isSubmittingAnswer,
              currentQuestion?.id == "sport_pick" else { return }
        isSubmittingAnswer = true
        let display = OnboardingSportCatalog.nameWithoutEmoji(sport)
        OnboardingDataModel.shared.selectedSports = [sport]
        OnboardingDataModel.shared.persistSelectedSports()
        onboardingViewModel?.isSportsSelected = true
        await recordAnswer(display: display, questionID: "sport_pick")
    }

    func submitFaceScanNow() async {
        guard !isSubmittingAnswer, currentQuestion?.id == "face_scan_offer" else { return }
        isSubmittingAnswer = true

        if !ProcessPrivacyConsentStore.shared.canCaptureFaceScan {
            ProcessPrivacyConsentStore.shared.acceptFaceScanCapture()
        }

        if conversationEngine.messages.last?.sender != .user
            || conversationEngine.messages.last?.text != "Lancer le scan" {
            conversationEngine.userReplied("Lancer le scan")
        }
        isQuestionReadyForAnswers = false
        isSubmittingAnswer = false
        // La View ouvre la page de scan dédiée.
    }

    func submitFaceScanLater() async {
        guard !isSubmittingAnswer, currentQuestion?.id == "face_scan_offer" else { return }
        isSubmittingAnswer = true
        onboardingViewModel?.isFaceAnalysisCompleted = true
        onboardingViewModel?.onboardingFaceMesh = nil
        onboardingViewModel?.onboardingFaceMarkers = nil
        markQuestionCompleted("face_scan_offer")
        if conversationEngine.messages.last?.sender != .user
            || conversationEngine.messages.last?.text != "Faire mon scan plus tard" {
            conversationEngine.userReplied("Faire mon scan plus tard")
        }
        currentQuestion = nil
        isQuestionReadyForAnswers = false
        analysisLetsGoUnlocked = false
        // Pas de Sign in Apple dans le chat — on enchaîne directement.
        shouldFinish = true
        isSubmittingAnswer = false
    }

    func adoptDedicatedFaceScanResult(_ result: FaceScanResult) {
        inlineFaceScanResult = result
        onboardingViewModel?.onboardingFaceMesh = OnboardingFaceMarkersStore.loadMesh()
        onboardingViewModel?.onboardingFaceMarkers = result.markers
        onboardingViewModel?.isFaceAnalysisCompleted = true
        markQuestionCompleted("face_scan_offer")
    }

    func restoreFaceScanOfferAnswers() {
        guard currentQuestion?.id == "face_scan_offer", !shouldFinish else { return }
        isSubmittingAnswer = false
        isQuestionReadyForAnswers = true
    }

    func submitFaceScanResultsContinue() {
        // Compat — plus utilisé (page dédiée hors chat).
    }

    /// Persiste le scan et clôture la discussion (connexion Apple après le paywall).
    func finishAfterDedicatedFaceAnalysis() {
        if let result = inlineFaceScanResult {
            onboardingViewModel?.onboardingFaceMesh = OnboardingFaceMarkersStore.loadMesh()
            onboardingViewModel?.onboardingFaceMarkers = result.markers
            onboardingViewModel?.isFaceAnalysisCompleted = true
            markQuestionCompleted("face_scan_offer")
        }
        currentQuestion = nil
        isQuestionReadyForAnswers = false
        programCreationPhase = .idle
        analysisLetsGoUnlocked = false
        resetInlineFaceScanState()
        shouldFinish = true
    }

    func faceScanDidSkip() {
        Task { await submitFaceScanLater() }
    }

    func finish(onComplete: () -> Void) {
        guard !didFinish else { return }
        didFinish = true
        conversationEngine.reset()
        analysisTask?.cancel()
        inlineFaceScanTask?.cancel()
        programCreationTask?.cancel()
        stopAnalysisElapsedTimer()
        stopInlineFaceScanElapsedTimer()

        prepareAnswersForAuthentication()
        onboardingViewModel?.isWeightMotivationCompleted = true
        onboardingViewModel?.commitPendingStepAnswers()
        onboardingViewModel?.saveProgress()
        onComplete()
    }

    func prepareAnswersForAuthentication() {
        if onboardingViewModel?.hasSportActivity == nil {
            onboardingViewModel?.hasSportActivity = false
        }
        if onboardingViewModel?.nutritionProfile.nutritionQuality == nil {
            onboardingViewModel?.updateNutritionQuality(.average)
        }
        if onboardingViewModel?.selectedGoalPace == nil {
            onboardingViewModel?.selectedGoalPace = .moderate
            onboardingViewModel?.isGoalPaceSelected = true
        }
        if onboardingViewModel?.hasWeightObjective != true {
            onboardingViewModel?.isWeightManagementExperienceSelected = true
        }
        onboardingViewModel?.commitPendingStepAnswers()
        onboardingViewModel?.saveProgress()
    }

    // MARK: - Private

    private func resetInlineFaceScanState() {
        inlineFaceScanTask?.cancel()
        inlineFaceScanTask = nil
        stopInlineFaceScanElapsedTimer()
        inlineFaceScanPayload = nil
        inlineFaceScanMarkers = nil
        inlineFaceScanResult = nil
        inlineFaceScanResultsUnlocked = false
        inlineFaceScanProgress = 0
        inlineFaceScanDisplayedPercentage = 0
        inlineFaceScanPhaseIndex = 0
        inlineFaceScanElapsedSeconds = 0
        inlineFaceScanPhaseLabel = OnboardingAnalysisProgressConfig.faceScanAnalysisSteps[0].phaseLabel
        faceScanInlinePhase = .idle
    }

    private func runInlineFaceScanAnalysis() async {
        guard let payload = inlineFaceScanPayload,
              let markers = inlineFaceScanMarkers else { return }

        try? await Task.sleep(nanoseconds: 450_000_000)

        animate(OnboardingProfileChatAnswerReveal.spring) {
            faceScanInlinePhase = .analyzing
        }

        beginInlineFaceScanPanel()
        startInlineFaceScanProgressAnimation()

        let analysisStartedAt = Date()

        let result = await FaceScanService.recordScan(
            payload: payload,
            markers: markers,
            profile: nil
        )

        FaceScanHistoryStore.shared.reloadForUser(userId: UserScopedStorage.currentUserId())

        let minimumAnalysisDuration: TimeInterval = 9
        let elapsed = Date().timeIntervalSince(analysisStartedAt)
        if elapsed < minimumAnalysisDuration {
            try? await Task.sleep(nanoseconds: UInt64((minimumAnalysisDuration - elapsed) * 1_000_000_000))
        }

        inlineFaceScanTask?.cancel()
        await finishInlineFaceScanProgressAnimation()
        stopInlineFaceScanElapsedTimer()
        HapticManager.shared.notification(.success)

        try? await Task.sleep(nanoseconds: 520_000_000)

        inlineFaceScanResult = result
        animate(OnboardingProfileChatAnswerReveal.spring) {
            faceScanInlinePhase = .results
            inlineFaceScanResultsUnlocked = false
        }

        // Court délai puis bouton « Voir l’analyse ».
        try? await Task.sleep(nanoseconds: 450_000_000)

        animate(OnboardingProfileChatAnswerReveal.spring) {
            inlineFaceScanResultsUnlocked = true
        }
    }

    private func beginInlineFaceScanPanel() {
        let steps = OnboardingAnalysisProgressConfig.faceScanAnalysisSteps
        inlineFaceScanProgress = 0
        inlineFaceScanDisplayedPercentage = 0
        inlineFaceScanPhaseLabel = steps[0].phaseLabel
        inlineFaceScanPhaseIndex = 0
        inlineFaceScanElapsedSeconds = 0
        startInlineFaceScanElapsedTimer()
    }

    private func startInlineFaceScanElapsedTimer() {
        inlineFaceScanElapsedTask?.cancel()
        inlineFaceScanElapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                guard faceScanInlinePhase == .analyzing else { continue }
                inlineFaceScanElapsedSeconds += 1
            }
        }
    }

    private func stopInlineFaceScanElapsedTimer() {
        inlineFaceScanElapsedTask?.cancel()
        inlineFaceScanElapsedTask = nil
    }

    private func startInlineFaceScanProgressAnimation() {
        inlineFaceScanTask?.cancel()

        let steps = OnboardingAnalysisProgressConfig.faceScanAnalysisSteps
        let tickInterval = OnboardingAnalysisProgressConfig.tickIntervalNs
        let leadDuration: TimeInterval = 9

        inlineFaceScanTask = Task {
            try? await Task.sleep(nanoseconds: OnboardingAnalysisProgressConfig.startDelayNs)
            guard !Task.isCancelled else { return }

            let startTime = Date()

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let normalized = min(0.92, elapsed / leadDuration)
                let eased = 1.0 - pow(1.0 - normalized, 2.1)
                let stepIndex = min(steps.count - 1, Int(eased * Double(steps.count)))

                inlineFaceScanProgress = eased
                inlineFaceScanDisplayedPercentage = Int((eased * 100).rounded())
                inlineFaceScanPhaseIndex = stepIndex
                inlineFaceScanPhaseLabel = steps[stepIndex].phaseLabel

                if normalized >= 0.92 { break }
                try? await Task.sleep(nanoseconds: tickInterval)
            }
        }
    }

    private func finishInlineFaceScanProgressAnimation() async {
        inlineFaceScanTask?.cancel()

        let steps = OnboardingAnalysisProgressConfig.faceScanAnalysisSteps
        let start = inlineFaceScanProgress
        let stepsCount = 12
        for step in 1...stepsCount {
            let t = Double(step) / Double(stepsCount)
            let eased = start + (1 - start) * (1 - pow(1 - t, 2))
            inlineFaceScanProgress = eased
            inlineFaceScanDisplayedPercentage = Int((eased * 100).rounded())
            inlineFaceScanPhaseIndex = min(steps.count - 1, Int(eased * Double(steps.count)))
            inlineFaceScanPhaseLabel = steps[inlineFaceScanPhaseIndex].phaseLabel
            try? await Task.sleep(nanoseconds: 45_000_000)
        }

        inlineFaceScanProgress = 1
        inlineFaceScanDisplayedPercentage = 100
        inlineFaceScanPhaseIndex = steps.count - 1
        inlineFaceScanPhaseLabel = steps.last?.phaseLabel ?? inlineFaceScanPhaseLabel
    }

    private func advanceAfterFaceScanResponse() async {
        isSubmittingAnswer = true
        resetInlineFaceScanState()
        let shouldType = advanceToNextQuestion()
        if shouldType {
            await presentCurrentQuestion(initialDelay: false)
        }
        isSubmittingAnswer = false
    }

    private func recordAnswer(display: String, questionID: String? = nil) async {
        let completedQuestionID = questionID ?? currentQuestion?.id
        if let completedQuestionID {
            markQuestionCompleted(completedQuestionID)
            var props: [String: Any] = [
                "question_id": completedQuestionID,
                "answer_display": display,
                "answer_length": display.count
            ]
            if let vm = onboardingViewModel {
                if let gender = vm.selectedGender { props["gender"] = gender.rawValue }
                if vm.isAgeSelected { props["age"] = vm.selectedAge }
                if OnboardingViewModel.isPlausibleWeight(vm.selectedWeight) {
                    props["weight_kg"] = vm.selectedWeight
                }
                if vm.selectedHeight > 0 { props["height_cm"] = vm.selectedHeight }
                let name = vm.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                if OnboardingViewModel.isRealUserFirstName(name) {
                    props["first_name"] = name
                }
            }
            ProcessAnalytics.capture("onboarding_chat_answer", properties: props)
        }
        isQuestionReadyForAnswers = false
        currentQuestion = nil

        conversationEngine.userReplied(display)
        let shouldTypeNextQuestion = advanceToNextQuestion()

        if shouldTypeNextQuestion {
            await presentCurrentQuestion(initialDelay: false)
        }

        isSubmittingAnswer = false
    }

    private func markQuestionCompleted(_ questionID: String) {
        guard !questionID.isEmpty else { return }
        onboardingViewModel?.markProfileChatQuestionCompleted(questionID)
    }

    private func finalizeQuestionPresentation() async {
        if currentQuestion?.kind == .answersAnalysis {
            isQuestionReadyForAnswers = true
            beginAnswersAnalysisPanel()
            startAnswersAnalysisAnimation()
            await analysisTask?.value
            guard analysisPhase == .complete else { return }
            await presentAnalysisDetailMessage()
            return
        }

        if currentQuestion?.kind == .autoPlanCreation {
            markQuestionCompleted("scan_explanation")
            await beginProgramCreationFlow()
            return
        }

        isQuestionReadyForAnswers = true
    }

    private func beginAnswersAnalysisPanel() {
        let steps = OnboardingAnalysisProgressConfig.answersAnalysisSteps

        analysisPhase = .running
        analysisProgress = 0
        analysisDisplayedPercentage = 0
        analysisPhaseLabel = steps[0].phaseLabel
        analysisPhaseIndex = 0
        analysisElapsedSeconds = 0
        analysisProgressPanelVisible = true
        analysisIsPaused = false
        analysisLetsGoUnlocked = false
        startAnalysisElapsedTimer()
    }

    private func startAnalysisElapsedTimer() {
        analysisElapsedTask?.cancel()
        analysisElapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                guard analysisPhase == .running else { continue }
                analysisElapsedSeconds += 1
            }
        }
    }

    private func stopAnalysisElapsedTimer() {
        analysisElapsedTask?.cancel()
        analysisElapsedTask = nil
    }

    private func beginProgramCreationFlow() async {
        isQuestionReadyForAnswers = false
        currentQuestion = nil
        analysisLetsGoUnlocked = false
        programCreationTask?.cancel()

        programCreationPhase = .running
        programCreationProgress = 0
        programCreationDisplayedPercentage = 0

        programCreationTask = Task {
            let totalDuration: TimeInterval = 5.5
            let tickInterval: UInt64 = 28_000_000

            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }

            let startTime = Date()

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let normalized = min(1.0, elapsed / totalDuration)
                let eased = 1.0 - pow(1.0 - normalized, 2.1)

                programCreationProgress = eased
                programCreationDisplayedPercentage = Int((eased * 100).rounded())

                if normalized >= 1.0 { break }
                try? await Task.sleep(nanoseconds: tickInterval)
            }

            guard !Task.isCancelled else { return }

            HapticManager.shared.notification(.success)
            programCreationProgress = 1
            programCreationDisplayedPercentage = 100
            programCreationPhase = .complete

            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }

            animate(OnboardingProfileChatAnswerReveal.spring) {
                programCreationPhase = .idle
            }
            shouldFinish = true
        }

        await programCreationTask?.value
    }

    private func presentAnalysisDetailMessage() async {
        guard let detail = currentQuestion?.detailText, !detail.isEmpty else { return }

        analysisLetsGoUnlocked = false

        animate(OnboardingProfileChatAnswerReveal.spring) {
            analysisProgressPanelVisible = false
        }

        try? await Task.sleep(nanoseconds: 320_000_000)
        guard currentQuestion?.kind == .answersAnalysis else { return }

        await speakMossLines([
            MossLine("process.chat.answers_analysis.detail", detail, profile: .explanatory)
        ])

        try? await Task.sleep(nanoseconds: 180_000_000)
        guard currentQuestion?.kind == .answersAnalysis else { return }

        markQuestionCompleted(currentQuestion?.id ?? "answers_analysis")
        if advanceToNextQuestion() {
            await presentCurrentQuestion(initialDelay: false)
        } else {
            shouldFinish = true
        }
    }

    /// Scan déjà capturé + pas encore connecté → rouvrir la page résultats (seul endroit du Sign in Apple).
    private func restoredFaceScanResultForAuthGate() -> FaceScanResult? {
        guard AuthUser.current == nil else { return nil }
        return restoredFaceScanResultIfAvailable()
    }

    /// Premier scan déjà fait — réafficher la page d'analyse (ex. retour depuis création programme).
    func restoredFaceScanResultIfAvailable() -> FaceScanResult? {
        guard onboardingViewModel?.isFaceAnalysisCompleted == true else { return nil }

        if let latest = FaceScanHistoryStore.shared.latestResult {
            return latest
        }

        guard let markers = onboardingViewModel?.onboardingFaceMarkers ?? OnboardingFaceMarkersStore.load() else {
            return nil
        }

        return FaceScanResult(
            id: "onboarding-restored-scan",
            userId: UserScopedStorage.currentUserId() ?? "local-user",
            markers: markers,
            source: .onboarding
        )
    }

    func consumePendingDedicatedResultsReopen() -> FaceScanResult? {
        let result = pendingDedicatedResultsReopen
        pendingDedicatedResultsReopen = nil
        return result
    }

    /// Réinitialise l'état terminal du chat avant de rouvrir la page résultats du scan.
    func prepareForFaceScanResultsReopen() {
        didFinish = false
        shouldFinish = false
        shouldAutoFinishAfterResume = false
        programCreationPhase = .idle
        programCreationProgress = 0
        analysisPhase = .idle
        analysisProgressPanelVisible = false
        conversationEngine.reset()
        analysisTask?.cancel()
        programCreationTask?.cancel()
        inlineFaceScanTask?.cancel()
        stopAnalysisElapsedTimer()
        stopInlineFaceScanElapsedTimer()
        isSubmittingAnswer = false
    }

    private func startAnswersAnalysisAnimation() {
        analysisTask?.cancel()

        let steps = OnboardingAnalysisProgressConfig.answersAnalysisSteps
        let tickInterval = OnboardingAnalysisProgressConfig.tickIntervalNs
        let totalDuration: TimeInterval = 7.0

        analysisTask = Task {
            try? await Task.sleep(nanoseconds: OnboardingAnalysisProgressConfig.startDelayNs)
            guard !Task.isCancelled else { return }

            let startTime = Date()

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let normalized = min(1.0, elapsed / totalDuration)
                let eased = 1.0 - pow(1.0 - normalized, 2.2)
                let stepIndex = min(steps.count - 1, Int(eased * Double(steps.count)))

                analysisProgress = eased
                analysisDisplayedPercentage = Int((eased * 100).rounded())
                analysisPhaseIndex = stepIndex
                analysisPhaseLabel = steps[stepIndex].phaseLabel

                if normalized >= 1.0 { break }
                try? await Task.sleep(nanoseconds: tickInterval)
            }

            guard !Task.isCancelled else { return }
            stopAnalysisElapsedTimer()
            HapticManager.shared.notification(.success)
            analysisProgress = 1
            analysisDisplayedPercentage = 100
            analysisPhaseIndex = steps.count - 1
            analysisPhaseLabel = steps.last?.phaseLabel ?? analysisPhaseLabel
            analysisPhase = .complete
        }
    }

    @discardableResult
    private func advanceToNextQuestion() -> Bool {
        currentIndex += 1

        if currentIndex >= questions.count {
            isQuestionReadyForAnswers = false
            shouldFinish = true
            return false
        }

        currentQuestion = questions[currentIndex]
        guard let question = currentQuestion else { return false }

        if question.kind == .answersAnalysis {
            analysisPhase = .idle
            analysisProgress = 0
            analysisDisplayedPercentage = 0
            analysisPhaseIndex = 0
            analysisElapsedSeconds = 0
            stopAnalysisElapsedTimer()
            analysisProgressPanelVisible = false
            analysisLetsGoUnlocked = false
            analysisPhaseLabel = OnboardingAnalysisProgressConfig.answersAnalysisSteps[0].phaseLabel
        }

        return true
    }

    private func advanceAfterAnswer() async {
        defer { isSubmittingAnswer = false }

        let shouldType = advanceToNextQuestion()
        if shouldType {
            await presentCurrentQuestion(initialDelay: true)
        }
    }
}
