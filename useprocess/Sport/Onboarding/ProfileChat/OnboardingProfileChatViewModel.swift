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
    var shouldPresentFaceScan = false

    var showsAnswerOptions: Bool {
        !shouldFinish
            && !isMessageAnimating
            && !isSubmittingAnswer
            && !shouldPresentFaceScan
            && currentQuestion != nil
            && isQuestionReadyForAnswers
            && currentQuestion?.kind != .answersAnalysis
    }

    var showsAnalysisSection: Bool {
        !shouldFinish
            && currentQuestion?.kind == .answersAnalysis
            && analysisProgressPanelVisible
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
    private var pendingSportQuestion = false
    private var pendingObstaclesQuestion = false
    private var typewriterTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
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
        currentIndex = 0
        currentQuestion = nil
    }

    func startIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true
        await presentOpeningLine()
        await presentFirstQuestionAfterOpening()
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
        await advanceAfterAnswer()
    }

    func submitYesNo(_ yes: Bool) async {
        guard !isSubmittingAnswer, let question = currentQuestion else { return }
        isSubmittingAnswer = true

        switch question.id {
        case "sport_activity":
            onboardingViewModel?.hasSportActivity = yes
            pendingSportQuestion = yes
            await recordAnswer(display: yes ? "Oui" : "Non")
        default:
            await recordAnswer(display: yes ? "Oui" : "Non")
        }
    }

    func submitSingleChoice(_ choiceId: String) async {
        guard !isSubmittingAnswer, let question = currentQuestion else { return }
        isSubmittingAnswer = true
        let label = question.choices.first(where: { $0.id == choiceId })?.label ?? choiceId

        switch question.id {
        case "goal_pace":
            onboardingViewModel?.selectedGoalPace = GoalPace(rawValue: choiceId)
            onboardingViewModel?.isGoalPaceSelected = true
        case "sport_pick":
            if let choice = question.choices.first(where: { $0.id == choiceId }) {
                let stored = OnboardingSportCatalog.storedValue(label: choice.label, emoji: choice.emoji)
                OnboardingDataModel.shared.selectedSports = [stored]
            } else {
                OnboardingDataModel.shared.selectedSports = [label]
            }
            onboardingViewModel?.isSportsSelected = true
        case "weight_experience":
            var profile = onboardingViewModel?.nutritionProfile ?? NutritionProfile()
            profile.weightManagementExperience = WeightManagementExperience(rawValue: choiceId)
            onboardingViewModel?.nutritionProfile = profile
            onboardingViewModel?.isWeightManagementExperienceSelected = true
            if choiceId == WeightManagementExperience.triedMultiple.rawValue
                || choiceId == WeightManagementExperience.currentlyTrying.rawValue {
                pendingObstaclesQuestion = true
            }
        case "nutrition_quality":
            onboardingViewModel?.updateNutritionQuality(NutritionQuality(rawValue: choiceId) ?? .average)
        default:
            break
        }

        await recordAnswer(display: label)
    }

    func submitMultiChoice(_ choiceIds: Set<String>) async {
        guard !isSubmittingAnswer, let question = currentQuestion else { return }
        isSubmittingAnswer = true
        let labels = question.choices
            .filter { choiceIds.contains($0.id) }
            .map(\.label)
        let obstacles = Set(choiceIds.compactMap { NutritionObstacle(rawValue: $0) })
        var profile = onboardingViewModel?.nutritionProfile ?? NutritionProfile()
        profile.nutritionObstacles = obstacles
        onboardingViewModel?.nutritionProfile = profile
        onboardingViewModel?.isNutritionObstaclesSelected = !obstacles.isEmpty
        await recordAnswer(display: labels.joined(separator: ", "))
    }

    func submitSearchedSport(_ sport: String) async {
        guard !isSubmittingAnswer,
              currentQuestion?.id == "sport_pick" else { return }
        isSubmittingAnswer = true
        let display = OnboardingSportCatalog.nameWithoutEmoji(sport)
        OnboardingDataModel.shared.selectedSports = [sport]
        onboardingViewModel?.isSportsSelected = true
        await recordAnswer(display: display)
    }

    func submitFaceScanNow() async {
        guard !isSubmittingAnswer, currentQuestion?.id == "face_scan_offer" else { return }
        isSubmittingAnswer = true

        typewriterTask?.cancel()
        isQuestionReadyForAnswers = false
        currentQuestion = nil

        animate(OnboardingProfileChatDepthStyle.historySpring) {
            appendUserMessage("Lancer le scan")
        }

        try? await Task.sleep(nanoseconds: 280_000_000)
        shouldPresentFaceScan = true
        isSubmittingAnswer = false
    }

    func submitFaceScanLater() async {
        guard !isSubmittingAnswer, currentQuestion?.id == "face_scan_offer" else { return }
        isSubmittingAnswer = true
        onboardingViewModel?.isFaceAnalysisCompleted = true
        await recordAnswer(display: "Plus tard")
    }

    func faceScanDidComplete(payload: FaceScanCapturePayload, markers: FaceWellnessMarkers) {
        shouldPresentFaceScan = false
        onboardingViewModel?.onboardingFaceMesh = payload.mesh
        onboardingViewModel?.onboardingFaceMarkers = markers
        onboardingViewModel?.isFaceAnalysisCompleted = true
        OnboardingFaceMarkersStore.save(markers: markers, mesh: payload.mesh)
        FaceScanImageStore.deleteMedia(forScanId: payload.scanId)
        Task { await advanceAfterFaceScanResponse() }
    }

    func faceScanDidSkip() {
        shouldPresentFaceScan = false
        onboardingViewModel?.onboardingFaceMesh = nil
        onboardingViewModel?.onboardingFaceMarkers = nil
        onboardingViewModel?.isFaceAnalysisCompleted = true
        Task { await advanceAfterFaceScanResponse() }
    }

    func faceScanDidCancel() {
        shouldPresentFaceScan = false
        isSubmittingAnswer = false

        guard currentIndex < questions.count,
              questions[currentIndex].id == "face_scan_offer" else { return }

        if messages.last?.role == .user, messages.last?.text == "Lancer le scan" {
            animate(OnboardingProfileChatDepthStyle.historySpring) {
                if !messages.isEmpty {
                    messages.removeLast()
                }
            }
        }

        currentQuestion = questions[currentIndex]
        isQuestionReadyForAnswers = true
    }

    func finish(onComplete: () -> Void) {
        guard !didFinish else { return }
        didFinish = true
        typewriterTask?.cancel()
        analysisTask?.cancel()
        stopAnalysisElapsedTimer()

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

        onboardingViewModel?.isWeightMotivationCompleted = true
        onboardingViewModel?.commitPendingStepAnswers()
        onboardingViewModel?.saveProgress()
        onComplete()
    }

    // MARK: - Private

    private func advanceAfterFaceScanResponse() async {
        isSubmittingAnswer = true
        let shouldType = prepareNextQuestionMessage()
        if shouldType {
            await runTypewriter(initialDelay: false)
            await finalizeQuestionPresentation()
        }
        isSubmittingAnswer = false
    }

    private func recordAnswer(display: String) async {
        typewriterTask?.cancel()
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
        let totalDuration: TimeInterval = 14.0

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

        if pendingSportQuestion {
            pendingSportQuestion = false
            questions.insert(OnboardingProfileChatQuestionBank.sportQuestion(), at: currentIndex)
        }

        if pendingObstaclesQuestion {
            pendingObstaclesQuestion = false
            questions.insert(OnboardingProfileChatQuestionBank.failureReasonsQuestion(), at: currentIndex)
        }

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

        if question.id == "answers_analysis", let viewModel = onboardingViewModel {
            question = OnboardingProfileChatQuestionBank.analysisQuestion(for: viewModel)
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

                if character != " " && character != "\n" && character != "\t" {
                    HapticManager.shared.impact(.soft)
                }
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
            return 35_000_000
        case ".", "!", "?", "…":
            return 160_000_000
        case ",", ";", ":":
            return 110_000_000
        case "%":
            return 80_000_000
        default:
            return 62_000_000
        }
    }

    private func updateMessage(id: UUID, text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        let anchor = messages[index].layoutAnchorText
        messages[index] = .init(id: id, role: .assistant, text: text, layoutAnchorText: anchor)
    }
}
