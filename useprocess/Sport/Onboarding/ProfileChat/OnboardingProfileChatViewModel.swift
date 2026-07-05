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

    var messages: [OnboardingProfileChatMessage] = []
    var isMessageAnimating = false
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
        faceScanInlinePhase != .idle
    }

    var showsInlineFaceScanSection: Bool {
        currentQuestion?.id == "face_scan_offer" && showsInlineFaceScanFlow
    }

    var inlineFaceScanCapturedPayload: FaceScanCapturePayload? {
        inlineFaceScanPayload
    }

    private var inlineFaceScanPayload: FaceScanCapturePayload?
    private var inlineFaceScanMarkers: FaceWellnessMarkers?
    private var inlineFaceScanTask: Task<Void, Never>?
    private var inlineFaceScanElapsedTask: Task<Void, Never>?

    var showsAnswerOptions: Bool {
        !shouldFinish
            && !isMessageAnimating
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
        !shouldFinish && programCreationPhase == .running
    }

    var showsContinueAfterAnalysis: Bool {
        analysisLetsGoUnlocked
    }

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
    private var typewriterTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var programCreationTask: Task<Void, Never>?
    private var analysisElapsedTask: Task<Void, Never>?
    private var pendingTypewriterMessageID: UUID?
    private var pendingTypewriterText: String?

    func bind(
        _ viewModel: OnboardingViewModel,
        healthManager: HealthManager,
        permissionsManager: PermissionsManager
    ) {
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
            await presentOpeningLine()
            await presentFirstQuestionAfterOpening()
        }
    }

    private func restoreConversationFromSavedProgress() {
        guard let viewModel = onboardingViewModel else { return }
        let completed = viewModel.completedProfileChatQuestionIDs

        messages.removeAll(keepingCapacity: true)
        appendAssistantMessageInstant(OnboardingProfileChatQuestionBank.openingLine(for: viewModel))

        for question in questions where completed.contains(question.id) {
            let resolved = OnboardingProfileChatQuestionBank.resolvedQuestion(question, for: viewModel)
            appendAssistantMessageInstant(resolved.prompt)
            if let answer = OnboardingProfileChatQuestionBank.savedAnswerDisplay(
                for: resolved.id,
                viewModel: viewModel
            ) {
                appendUserMessage(answer)
            }
        }
    }

    private func resumeFromSavedProgress() async {
        guard let viewModel = onboardingViewModel else { return }
        let completed = viewModel.completedProfileChatQuestionIDs
        let allQuestionIDs = Set(questions.map(\.id))

        if allQuestionIDs.isSubset(of: completed) {
            analysisLetsGoUnlocked = true
            currentQuestion = nil
            isQuestionReadyForAnswers = false
            isMessageAnimating = false
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
        isMessageAnimating = false

        appendAssistantMessageInstant(question.prompt)

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

    private func appendAssistantMessageInstant(_ text: String) {
        messages.append(
            .init(
                role: .assistant,
                text: text,
                layoutAnchorText: text
            )
        )
    }

    private func presentFirstQuestionAfterOpening() async {
        guard currentIndex < questions.count else { return }
        isQuestionReadyForAnswers = false
        currentQuestion = questions[currentIndex]
        guard let question = currentQuestion else { return }

        let messageID = UUID()
        pendingTypewriterMessageID = messageID
        pendingTypewriterText = question.prompt

        animate(OnboardingProfileChatDepthStyle.historySpring) {
            messages.append(
                .init(
                    id: messageID,
                    role: .assistant,
                    text: "",
                    layoutAnchorText: question.prompt
                )
            )
            isMessageAnimating = true
        }

        try? await Task.sleep(nanoseconds: 320_000_000)
        await runTypewriter(initialDelay: true)
        await finalizeQuestionPresentation()
    }

    private func presentOpeningLine() async {
        guard let viewModel = onboardingViewModel else { return }
        await appendAssistantMessage(OnboardingProfileChatQuestionBank.openingLine(for: viewModel))
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
        markQuestionCompleted(question.id)
        await advanceAfterAnswer()
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
        case "primary_focus":
            if let focus = OnboardingPrimaryFocus(rawValue: choiceId) {
                onboardingViewModel?.onboardingPrimaryFocus = focus
                switch focus {
                case .face:
                    onboardingViewModel?.selectedPrimaryGoals.insert(.reduceStress)
                case .weight:
                    onboardingViewModel?.selectedPrimaryGoals.insert(.manageWeight)
                case .health:
                    onboardingViewModel?.selectedPrimaryGoals.insert(.improveFitness)
                case .energy:
                    onboardingViewModel?.selectedPrimaryGoals.insert(.optimizeEnergy)
                }
            }
        case "nutrition_quality":
            if choiceId == "snacking" {
                onboardingViewModel?.updateNutritionQuality(.poor)
                var profile = onboardingViewModel?.nutritionProfile ?? NutritionProfile()
                profile.nutritionObstacles.insert(.snacking)
                onboardingViewModel?.nutritionProfile = profile
            } else if choiceId == "unknown" {
                onboardingViewModel?.updateNutritionQuality(.average)
            } else {
                onboardingViewModel?.updateNutritionQuality(
                    NutritionQuality(rawValue: choiceId) ?? .average
                )
            }
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

        typewriterTask?.cancel()
        isQuestionReadyForAnswers = false

        animate(OnboardingProfileChatDepthStyle.historySpring) {
            appendUserMessage("Lancer le scan")
        }

        try? await Task.sleep(nanoseconds: 280_000_000)

        animate(OnboardingProfileChatAnswerReveal.spring) {
            faceScanInlinePhase = .capturing
        }
        isSubmittingAnswer = false
    }

    func submitFaceScanLater() async {
        guard !isSubmittingAnswer, currentQuestion?.id == "face_scan_offer" else { return }
        isSubmittingAnswer = true
        onboardingViewModel?.isFaceAnalysisCompleted = true
        await recordAnswer(display: "Faire mon scan plus tard", questionID: "face_scan_offer")
    }

    func faceScanCaptureCompleted(payload: FaceScanCapturePayload, markers: FaceWellnessMarkers) {
        inlineFaceScanPayload = payload
        inlineFaceScanMarkers = OnboardingFaceScanMarkerCalibration.calibrate(markers)
        Task { await runInlineFaceScanAnalysis() }
    }

    func submitFaceScanResultsContinue() {
        guard faceScanInlinePhase == .results,
              let result = inlineFaceScanResult else { return }
        HapticManager.shared.impact(.medium)
        onboardingViewModel?.onboardingFaceMesh = OnboardingFaceMarkersStore.loadMesh()
        onboardingViewModel?.onboardingFaceMarkers = result.markers
        onboardingViewModel?.isFaceAnalysisCompleted = true
        markQuestionCompleted("face_scan_offer")
        Task { await advanceAfterFaceScanResponse() }
    }

    func faceScanDidSkip() {
        resetInlineFaceScanState()
        onboardingViewModel?.onboardingFaceMesh = nil
        onboardingViewModel?.onboardingFaceMarkers = nil
        onboardingViewModel?.isFaceAnalysisCompleted = true
        markQuestionCompleted("face_scan_offer")
        Task { await advanceAfterFaceScanResponse() }
    }

    func finish(onComplete: () -> Void) {
        guard !didFinish else { return }
        didFinish = true
        typewriterTask?.cancel()
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

        // Laisse l'anneau WHOOP et les 5 indicateurs se révéler avant le bouton Continuer.
        try? await Task.sleep(nanoseconds: 4_800_000_000)

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
        let shouldType = prepareNextQuestionMessage()
        if shouldType {
            await runTypewriter(initialDelay: false)
            await finalizeQuestionPresentation()
        }
        isSubmittingAnswer = false
    }

    private func recordAnswer(display: String, questionID: String? = nil) async {
        typewriterTask?.cancel()
        let completedQuestionID = questionID ?? currentQuestion?.id
        if let completedQuestionID {
            markQuestionCompleted(completedQuestionID)
        }
        isQuestionReadyForAnswers = false
        currentQuestion = nil

        var shouldTypeNextQuestion = false

        animate(OnboardingProfileChatDepthStyle.historySpring) {
            appendUserMessage(display)
            shouldTypeNextQuestion = prepareNextQuestionMessage()
        }

        if shouldTypeNextQuestion {
            await runTypewriter(initialDelay: false)
            await finalizeQuestionPresentation()
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

            try? await Task.sleep(nanoseconds: 420_000_000)
            guard !Task.isCancelled else { return }

            animate(OnboardingProfileChatAnswerReveal.spring) {
                programCreationPhase = .idle
                analysisLetsGoUnlocked = true
            }
        }

        await programCreationTask?.value
    }

    private func presentAnalysisDetailMessage() async {
        guard let detail = currentQuestion?.detailText, !detail.isEmpty else { return }

        isMessageAnimating = true
        analysisLetsGoUnlocked = false

        animate(OnboardingProfileChatDepthStyle.historySpring) {
            analysisProgressPanelVisible = false
        }

        try? await Task.sleep(nanoseconds: 320_000_000)
        guard currentQuestion?.kind == .answersAnalysis else { return }

        let messageID = UUID()
        pendingTypewriterMessageID = messageID
        pendingTypewriterText = detail

        animate(OnboardingProfileChatDepthStyle.historySpring) {
            messages.append(
                .init(
                    id: messageID,
                    role: .assistant,
                    text: "",
                    layoutAnchorText: detail
                )
            )
        }

        await runTypewriter(initialDelay: false)

        try? await Task.sleep(nanoseconds: 180_000_000)
        guard currentQuestion?.kind == .answersAnalysis else { return }

        animate(OnboardingProfileChatAnswerReveal.spring) {
            analysisLetsGoUnlocked = true
        }
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
            isMessageAnimating = true
        }
    }

    @discardableResult
    private func prepareNextQuestionMessage() -> Bool {
        currentIndex += 1

        if currentIndex >= questions.count {
            isQuestionReadyForAnswers = false
            shouldFinish = true
            pendingTypewriterMessageID = nil
            pendingTypewriterText = nil
            isMessageAnimating = false
            return false
        }

        currentQuestion = questions[currentIndex]
        guard var question = currentQuestion else { return false }

        if question.id == "scan_explanation", let viewModel = onboardingViewModel {
            question = OnboardingProfileChatQuestionBank.scanExplanationQuestion(for: viewModel)
            questions[currentIndex] = question
            currentQuestion = question
        }

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

        let messageID = UUID()
        pendingTypewriterMessageID = messageID
        pendingTypewriterText = question.prompt
        messages.append(
            .init(
                id: messageID,
                role: .assistant,
                text: "",
                layoutAnchorText: question.prompt
            )
        )
        isMessageAnimating = true
        return true
    }

    private func advanceAfterAnswer() async {
        defer { isSubmittingAnswer = false }

        let shouldType = prepareNextQuestionMessage()
        if shouldType {
            await runTypewriter(initialDelay: true)
            await finalizeQuestionPresentation()
        }
    }

    private func appendUserMessage(_ text: String) {
        messages.append(.init(role: .user, text: text))
    }

    private func appendAssistantMessage(_ text: String) async {
        let messageID = UUID()
        pendingTypewriterMessageID = messageID
        pendingTypewriterText = text
        messages.append(
            .init(
                id: messageID,
                role: .assistant,
                text: "",
                layoutAnchorText: text
            )
        )
        isMessageAnimating = true
        await runTypewriter(initialDelay: true)
    }

    private func runTypewriter(initialDelay: Bool) async {
        typewriterTask?.cancel()
        guard let messageID = pendingTypewriterMessageID,
              let text = pendingTypewriterText else {
            isMessageAnimating = false
            return
        }

        isMessageAnimating = true

        if initialDelay {
            try? await Task.sleep(nanoseconds: 450_000_000)
        } else {
            try? await Task.sleep(nanoseconds: 80_000_000)
        }

        typewriterTask = Task {
            var displayed = ""
            for character in Array(text) {
                guard !Task.isCancelled else { return }

                let delayNs = typewriterDelay(for: character)
                try? await Task.sleep(nanoseconds: delayNs)
                guard !Task.isCancelled else { return }

                displayed.append(character)
                updateMessage(id: messageID, text: displayed)

                if character == "!" || character == "." || character == "?" {
                    HapticManager.shared.impact(.light)
                }
            }
        }

        await typewriterTask?.value
        isMessageAnimating = false
        pendingTypewriterMessageID = nil
        pendingTypewriterText = nil
    }

    private func typewriterDelay(for character: Character) -> UInt64 {
        switch character {
        case " ", "\n", "\t":
            return 15_000_000
        case ".", "!", "?", "…":
            return 90_000_000
        case ",", ";", ":":
            return 55_000_000
        case "%":
            return 45_000_000
        default:
            return 28_000_000
        }
    }

    private func updateMessage(id: UUID, text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        let anchor = messages[index].layoutAnchorText
        messages[index] = .init(id: id, role: .assistant, text: text, layoutAnchorText: anchor)
    }
}
