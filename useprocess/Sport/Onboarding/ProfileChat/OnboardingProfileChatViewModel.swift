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
    var analysisPhaseLabel = OnboardingAnalysisProgressConfig.phases[0]
    var analysisShowPopup = false
    var analysisPopupQuestion = ""
    var analysisPopupSubtitle = OnboardingAnalysisProgressConfig.popups[0].subtitle
    var analysisPopupAffirmativeTitle = "Oui"
    var analysisPopupNegativeTitle = "Non"
    var analysisPopupKind = OnboardingAnalysisProgressConfig.PopupKind.yesNo
    var analysisPopupOffset: CGFloat = 200
    var analysisPopupPhaseIndex = -1
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
            && currentQuestion?.kind != .analysisProgress
    }

    var showsAnalysisSection: Bool {
        !shouldFinish
            && currentQuestion?.kind == .analysisProgress
            && analysisProgressPanelVisible
    }

    var showsLetsGoButton: Bool {
        analysisLetsGoUnlocked
    }

    func handleAnalysisPopupAnswer(_ answer: Bool) {
        let popupKind = analysisPopupKind
        let popupIndex = analysisPopupPhaseIndex

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            self.analysisPopupOffset = 200
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.analysisShowPopup = false
            self.analysisPopupOffset = 200
        }

        Task {
            if popupKind == .healthKit {
                await handleHealthKitPopupAnswer(answer)
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            self.analysisIsPaused = false

            let phases = OnboardingAnalysisProgressConfig.phases
            guard popupIndex >= 0, popupIndex < phases.count else { return }

            withAnimation(.easeInOut(duration: 0.35)) {
                self.analysisProgress = Double(popupIndex + 1) / Double(phases.count)
                let percentagePerPhase = 100.0 / Double(phases.count)
                let total = Int((Double(popupIndex + 1) * percentagePerPhase).rounded())
                self.analysisDisplayedPercentage = min(total, 100)
            }
        }
    }

    private func handleHealthKitPopupAnswer(_ answer: Bool) async {
        guard let healthManager else { return }

        onboardingViewModel?.isRequestingHealthKit = true

        if answer {
            await healthManager.requestAuthorizationAsync()
            if let permissionsManager {
                _ = await permissionsManager.requestMotionPermission()
            }
            HapticManager.shared.notification(.success)
        }

        onboardingViewModel?.healthKitGranted = healthManager.isAuthorized
        onboardingViewModel?.isRequestingHealthKit = false
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

        withAnimation(OnboardingProfileChatDepthStyle.historySpring) {
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

    func submitLetsGo() {
        guard showsLetsGoButton else { return }
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

        withAnimation(OnboardingProfileChatDepthStyle.historySpring) {
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
            withAnimation(OnboardingProfileChatDepthStyle.historySpring) {
                messages.removeLast()
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
        onboardingViewModel?.isProgramCreationCompleted = true
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

        withAnimation(OnboardingProfileChatDepthStyle.historySpring) {
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
        if currentQuestion?.kind == .analysisProgress {
            isQuestionReadyForAnswers = true
            beginAnalysisProgressPanel()
            startAnalysisProgressAnimation()
            await analysisTask?.value
            guard analysisPhase == .complete else { return }
            await presentAnalysisDetailMessage()
            return
        }
        isQuestionReadyForAnswers = true
    }

    private func beginAnalysisProgressPanel() {
        let phases = OnboardingAnalysisProgressConfig.phases

        analysisPhase = .running
        analysisProgress = 0
        analysisDisplayedPercentage = 0
        analysisPhaseLabel = phases[0]
        analysisProgressPanelVisible = true
        analysisIsPaused = false
        analysisShowPopup = false
        analysisPopupOffset = 200
        analysisLetsGoUnlocked = false
    }

    private func presentAnalysisDetailMessage() async {
        guard let detail = currentQuestion?.detailText, !detail.isEmpty else { return }

        isMessageAnimating = true
        analysisLetsGoUnlocked = false

        withAnimation(OnboardingProfileChatDepthStyle.historySpring) {
            analysisProgressPanelVisible = false
        }

        try? await Task.sleep(nanoseconds: 320_000_000)
        guard currentQuestion?.kind == .analysisProgress else { return }

        let messageID = UUID()
        pendingTypewriterMessageID = messageID
        pendingTypewriterText = detail

        withAnimation(OnboardingProfileChatDepthStyle.historySpring) {
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
        guard currentQuestion?.kind == .analysisProgress else { return }

        withAnimation(OnboardingProfileChatAnswerReveal.spring) {
            analysisLetsGoUnlocked = true
        }
    }

    private func startAnalysisProgressAnimation() {
        analysisTask?.cancel()

        let phases = OnboardingAnalysisProgressConfig.phases
        let popups = OnboardingAnalysisProgressConfig.popups
        let tickInterval = OnboardingAnalysisProgressConfig.tickIntervalNs
        let segmentStep = OnboardingAnalysisProgressConfig.segmentStep

        analysisTask = Task {
            try? await Task.sleep(nanoseconds: OnboardingAnalysisProgressConfig.startDelayNs)
            guard !Task.isCancelled else { return }

            for index in 0..<phases.count {
                guard !Task.isCancelled else { return }

                analysisPhaseLabel = phases[index]

                var segmentProgress = 0.0
                while segmentProgress < 0.5 {
                    while analysisIsPaused {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        guard !Task.isCancelled else { return }
                    }

                    try? await Task.sleep(nanoseconds: tickInterval)
                    segmentProgress += segmentStep

                    let percentagePerPhase = 100.0 / Double(phases.count)
                    let base = Double(index) * percentagePerPhase
                    let total = Int((base + segmentProgress * percentagePerPhase).rounded())

                    analysisProgress = (Double(index) + segmentProgress) / Double(phases.count)
                    analysisDisplayedPercentage = min(total, 100)
                }

                analysisIsPaused = true
                let popup = popups[index]
                analysisPopupQuestion = popup.question
                analysisPopupSubtitle = popup.subtitle
                analysisPopupAffirmativeTitle = popup.affirmativeTitle
                analysisPopupNegativeTitle = popup.negativeTitle
                analysisPopupKind = popup.kind
                analysisPopupPhaseIndex = index
                analysisPopupOffset = 200
                analysisShowPopup = true

                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    analysisPopupOffset = 0
                }

                while analysisIsPaused {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    guard !Task.isCancelled else { return }
                }

                while segmentProgress < 1.0 {
                    while analysisIsPaused {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        guard !Task.isCancelled else { return }
                    }

                    try? await Task.sleep(nanoseconds: tickInterval)
                    segmentProgress += segmentStep

                    let percentagePerPhase = 100.0 / Double(phases.count)
                    let base = Double(index) * percentagePerPhase
                    let total = Int((base + segmentProgress * percentagePerPhase).rounded())

                    analysisProgress = (Double(index) + segmentProgress) / Double(phases.count)
                    if index == phases.count - 1 && segmentProgress >= 1.0 {
                        analysisDisplayedPercentage = 100
                        analysisProgress = 1
                    } else {
                        analysisDisplayedPercentage = min(total, 100)
                    }
                }
            }

            guard !Task.isCancelled else { return }
            HapticManager.shared.notification(.success)
            analysisProgress = 1
            analysisDisplayedPercentage = 100
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

        if question.kind == .analysisProgress {
            analysisPhase = .idle
            analysisProgress = 0
            analysisDisplayedPercentage = 0
            analysisProgressPanelVisible = false
            analysisShowPopup = false
            analysisPopupOffset = 200
            analysisPhaseLabel = OnboardingAnalysisProgressConfig.phases[0]
            analysisLetsGoUnlocked = false
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
