//
//  OnboardingProfileChatViewModel.swift
//  useprocess
//
//  Chat Moss live : intros → questions profil → résumé → dashboard.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class OnboardingProfileChatViewModel {
    private(set) var conversationEngine: MossConversationEngine!

    var isSubmittingAnswer = false
    var shouldFinish = false
    var isGlowUpResultsPresented = false
    var currentQuestion: OnboardingProfileChatQuestion?

    /// Après relance : rouvrir les résultats scan si déjà fait.
    private(set) var pendingDedicatedResultsReopen: FaceScanResult?
    /// Après relance : chat terminé → enchaîner.
    private(set) var shouldAutoFinishAfterResume = false

    var showsAnswerOptions: Bool {
        guard let conversationEngine else { return false }
        return !shouldFinish
            && conversationEngine.controlsVisible
            && !conversationEngine.isTyping
            && !isSubmittingAnswer
            && currentQuestion != nil
            && isQuestionReadyForAnswers
    }

    private var glowUpPendingQuestion: OnboardingProfileChatQuestion?
    private var isCompletingGlowUpResults = false
    private var isQuestionReadyForAnswers = false
    private var onboardingViewModel: OnboardingViewModel?
    private var questions: [OnboardingProfileChatQuestion] = []
    private var currentIndex = 0
    private var hasStarted = false
    private var didFinish = false
    private var lastDedicatedScanResult: FaceScanResult?

    func bind(
        _ viewModel: OnboardingViewModel,
        engine: MossConversationEngine,
        healthManager _: HealthManager,
        permissionsManager _: PermissionsManager
    ) {
        conversationEngine = engine
        onboardingViewModel = viewModel
        guard !hasStarted else { return }
        questions = OnboardingProfileChatQuestionBank.questions(for: viewModel)
        let completed = OnboardingProfileChatQuestionBank.normalizedCompletedQuestionIDs(
            Set(viewModel.completedProfileChatQuestionIDs)
        )
        currentIndex = questions.firstIndex {
            !completed.contains($0.id)
        } ?? max(0, questions.count - 1)
        currentQuestion = nil
    }

    func startIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        guard let viewModel = onboardingViewModel else { return }
        if !viewModel.completedProfileChatQuestionIDs.isEmpty {
            restoreConversationFromSavedProgress()
            await resumeFromSavedProgress()
        } else {
            await presentFirstQuestionAfterOpening()
        }
    }

    // MARK: - Glow-up

    func submitInfoContinue() async {
        guard !isSubmittingAnswer,
              let question = currentQuestion,
              question.kind == .infoContinue else { return }

        if question.id == "intro_next" {
            isSubmittingAnswer = true
            glowUpPendingQuestion = question
            setGlowUpResultsPresented(true)
            isSubmittingAnswer = false
            return
        }

        isSubmittingAnswer = true
        await recordAnswer(
            display: question.continueLabel ?? OnboardingCopy.continueCTA,
            questionID: question.id
        )
    }

    func dismissGlowUpResults() {
        glowUpPendingQuestion = nil
        isCompletingGlowUpResults = false
        setGlowUpResultsPresented(false)
    }

    func completeGlowUpResults() async {
        guard !isCompletingGlowUpResults,
              isGlowUpResultsPresented,
              let question = glowUpPendingQuestion ?? currentQuestion,
              question.id == "intro_next" else { return }

        isCompletingGlowUpResults = true
        glowUpPendingQuestion = nil
        ProcessAnalytics.trackMossAction(page: .glowUpResults, action: "continued")
        setGlowUpResultsPresented(false)
        try? await Task.sleep(nanoseconds: glowUpResultsCoverDelayNanoseconds)

        isSubmittingAnswer = true
        await recordAnswer(
            display: question.continueLabel ?? OnboardingCopy.continueCTA,
            questionID: question.id
        )
        isCompletingGlowUpResults = false
    }

    // MARK: - Answers

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
                case ..<5: sleep.sleepQuality = .veryPoor
                case ..<6: sleep.sleepQuality = .poor
                case ..<7: sleep.sleepQuality = .average
                case ..<8: sleep.sleepQuality = .good
                default: sleep.sleepQuality = .excellent
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

        await recordAnswer(display: label, questionID: question.id, answerID: choiceId)
    }

    func submitProfileSummaryContinue() async {
        guard !shouldFinish,
              let question = currentQuestion,
              question.kind == .profileSummary else { return }

        let continueLabel = OnboardingCopy.t("Voir mon dashboard", en: "See my dashboard")
        ProcessAnalytics.trackMossAction(
            page: .profileSummary,
            action: "continued_to_dashboard",
            answerDisplay: continueLabel,
            extra: [
                "question_id": question.id,
                "question_index": currentIndex,
                "questions_total": questions.count
            ]
        )

        onboardingViewModel?.dashboardPreviewPresentation = .firstScanPending
        onboardingViewModel?.isWeightMotivationCompleted = true
        markQuestionCompleted(question.id)
        shouldFinish = true
    }

    // MARK: - Face scan (compat callbacks dashboard / fullScreenCover)

    func submitFaceScanLater() async {
        let isFaceScanStep = currentQuestion == nil
            || currentQuestion?.id == "face_scan_offer"
            || currentQuestion?.id == "profile_summary"
            || currentQuestion?.kind == .profileSummary
        guard !isSubmittingAnswer, isFaceScanStep else { return }
        isSubmittingAnswer = true
        onboardingViewModel?.isFaceAnalysisCompleted = true
        onboardingViewModel?.onboardingFaceMesh = nil
        onboardingViewModel?.onboardingFaceMarkers = nil
        markQuestionCompleted("profile_summary")
        markQuestionCompleted("face_scan_offer")
        ProcessAnalytics.trackMossAction(
            page: .faceScanOffer,
            action: "skipped",
            answerDisplay: OnboardingCopy.t("Faire mon scan plus tard", en: "I’ll scan later"),
            extra: [
                "question_id": "face_scan_offer",
                "question_index": currentIndex,
                "questions_total": questions.count
            ]
        )
        let scanLaterLabel = OnboardingCopy.t("Faire mon scan plus tard", en: "I’ll scan later")
        if conversationEngine.messages.last?.sender != .user
            || conversationEngine.messages.last?.text != scanLaterLabel {
            conversationEngine.userReplied(scanLaterLabel)
        }
        currentQuestion = nil
        isQuestionReadyForAnswers = false
        shouldFinish = true
        isSubmittingAnswer = false
    }

    func adoptDedicatedFaceScanResult(_ result: FaceScanResult) {
        lastDedicatedScanResult = result
        onboardingViewModel?.onboardingFaceMesh = OnboardingFaceMarkersStore.loadMesh()
        onboardingViewModel?.onboardingFaceMarkers = result.markers
        onboardingViewModel?.isFaceAnalysisCompleted = true
        markQuestionCompleted("profile_summary")
        markQuestionCompleted("face_scan_offer")
    }

    func restoreFaceScanOfferAnswers() {
        guard currentQuestion?.kind == .profileSummary
            || currentQuestion?.id == "face_scan_offer",
              !shouldFinish else { return }
        isSubmittingAnswer = false
        isQuestionReadyForAnswers = true
        ProcessAnalytics.lastMossPageName = nil
        trackCurrentChatQuestionViewed()
        ProcessAnalytics.trackMossAction(page: .faceScanOffer, action: "returned_from_scan")
    }

    func finishAfterDedicatedFaceAnalysis() {
        if let result = lastDedicatedScanResult {
            onboardingViewModel?.onboardingFaceMesh = OnboardingFaceMarkersStore.loadMesh()
            onboardingViewModel?.onboardingFaceMarkers = result.markers
            onboardingViewModel?.isFaceAnalysisCompleted = true
            markQuestionCompleted("profile_summary")
            markQuestionCompleted("face_scan_offer")
        }
        ProcessAnalytics.trackMossAction(page: .faceScanResults, action: "continued")
        currentQuestion = nil
        isQuestionReadyForAnswers = false
        shouldFinish = true
    }

    func faceScanDidSkip() {
        Task { await submitFaceScanLater() }
    }

    func finish(onComplete: () -> Void) {
        guard !didFinish else { return }
        didFinish = true
        conversationEngine.reset()
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

    // MARK: - Back

    @discardableResult
    func goBackInDiscussion() -> Bool {
        guard let viewModel = onboardingViewModel else { return false }

        if isGlowUpResultsPresented {
            dismissGlowUpResults()
            return true
        }

        conversationEngine.reset()
        isSubmittingAnswer = false

        let orderedIDs = questions.map(\.id)
        let orderedCompleted = orderedIDs.filter { viewModel.completedProfileChatQuestionIDs.contains($0) }

        guard let targetID = orderedCompleted.last,
              let targetIndex = orderedIDs.firstIndex(of: targetID) else {
            return false
        }

        viewModel.rewindProfileChat(from: targetID, orderedQuestionIDs: orderedIDs)
        clearSideEffectsIfNeeded(rewindingFrom: targetID)

        currentIndex = targetIndex
        shouldFinish = false

        let question = OnboardingProfileChatQuestionBank.resolvedQuestion(
            questions[targetIndex],
            for: viewModel
        )
        questions[targetIndex] = question
        currentQuestion = question
        isQuestionReadyForAnswers = true
        trackCurrentChatQuestionViewed()

        rebuildMessages(upToCompletedExclusiveOf: targetID)
        appendAssistantMessagesInstant(for: question)
        return true
    }

    // MARK: - Resume / restore

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

    func prepareForFaceScanResultsReopen() {
        didFinish = false
        shouldFinish = false
        shouldAutoFinishAfterResume = false
        conversationEngine.reset()
        isSubmittingAnswer = false
    }

    // MARK: - Private

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

        if viewModel.shouldReopenFaceScanResultsAfterBack || viewModel.presentedOnboardingFaceScan != nil {
            return
        }

        let allQuestionIDs = Set(questions.map(\.id))
        let completed = OnboardingProfileChatQuestionBank.normalizedCompletedQuestionIDs(
            Set(viewModel.completedProfileChatQuestionIDs)
        )

        if allQuestionIDs.isSubset(of: completed) {
            currentQuestion = nil
            isQuestionReadyForAnswers = false

            if AuthUser.current == nil, let result = restoredFaceScanResultIfAvailable() {
                lastDedicatedScanResult = result
                pendingDedicatedResultsReopen = result
                return
            }

            viewModel.dashboardPreviewPresentation = .firstScanPending
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
        trackCurrentChatQuestionViewed()
        appendAssistantMessagesInstant(for: question)
        isQuestionReadyForAnswers = true
    }

    private func appendAssistantMessagesInstant(for question: OnboardingProfileChatQuestion) {
        let progress = OnboardingMossChatHelpers.answerProgress(for: question, in: questions)
        conversationEngine.speak(
            OnboardingMossChatHelpers.mossLines(for: question, progress: progress),
            instant: true
        )
    }

    private func presentFirstQuestionAfterOpening() async {
        guard currentIndex < questions.count else { return }
        currentQuestion = questions[currentIndex]
        await presentCurrentQuestion()
    }

    private func presentCurrentQuestion() async {
        guard let question = currentQuestion else { return }

        isQuestionReadyForAnswers = false
        trackCurrentChatQuestionViewed()

        let progress = OnboardingMossChatHelpers.answerProgress(for: question, in: questions)
        let lines = OnboardingMossChatHelpers.mossLines(
            for: question,
            emotionalFirstBlock: question.id == "intro_swollen_face",
            progress: progress
        )
        guard !lines.isEmpty else {
            isQuestionReadyForAnswers = true
            return
        }

        await speakMossLines(lines)
        isQuestionReadyForAnswers = true
    }

    private func speakMossLines(_ lines: [MossLine]) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            conversationEngine.speak(lines, onBatchDone: {
                continuation.resume()
            })
        }
    }

    private func setGlowUpResultsPresented(_ presented: Bool) {
        if presented {
            ProcessAnalytics.trackMossPageViewed(.glowUpResults)
        }
        withAnimation(glowUpResultsCoverAnimation) {
            isGlowUpResultsPresented = presented
            onboardingViewModel?.profileChatHeaderProgress = OnboardingProfileChatCoachHeaderProgress.snapshot(
                questionID: currentQuestion?.id,
                engine: conversationEngine,
                isGlowUpResultsPresented: presented
            )
        }
    }

    private var glowUpResultsCoverAnimation: Animation {
        UIAccessibility.isReduceMotionEnabled
            ? .easeInOut(duration: 0.22)
            : .glowUpResultsCover
    }

    private var glowUpResultsCoverDelayNanoseconds: UInt64 {
        UIAccessibility.isReduceMotionEnabled ? 200_000_000 : 420_000_000
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
        case "face_scan_offer", "profile_summary":
            onboardingViewModel?.onboardingFaceMarkers = nil
            onboardingViewModel?.isFaceAnalysisCompleted = false
            lastDedicatedScanResult = nil
        default:
            break
        }
    }

    private func recordAnswer(
        display: String,
        questionID: String? = nil,
        answerID: String? = nil
    ) async {
        let completedQuestionID = questionID ?? currentQuestion?.id
        let kind = currentQuestion.map { mossQuestionKindName($0.kind) } ?? "unknown"
        let index = completedQuestionID.flatMap { id in
            questions.firstIndex(where: { $0.id == id })
        } ?? currentIndex

        if let completedQuestionID {
            markQuestionCompleted(completedQuestionID)
            var profileExtras: [String: Any] = [:]
            if let vm = onboardingViewModel {
                if let gender = vm.selectedGender { profileExtras["gender"] = gender.rawValue }
                if vm.isAgeSelected { profileExtras["age"] = vm.selectedAge }
                if OnboardingViewModel.isPlausibleWeight(vm.selectedWeight) {
                    profileExtras["weight_kg"] = vm.selectedWeight
                }
                if vm.selectedHeight > 0 { profileExtras["height_cm"] = vm.selectedHeight }
                let name = vm.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                if OnboardingViewModel.isRealUserFirstName(name) {
                    profileExtras["first_name"] = name
                }
            }
            ProcessAnalytics.trackMossChatAnswer(
                questionID: completedQuestionID,
                questionKind: kind,
                questionIndex: index,
                questionsTotal: questions.count,
                answerDisplay: display,
                answerID: answerID,
                profileExtras: profileExtras
            )
        }
        isQuestionReadyForAnswers = false
        currentQuestion = nil

        conversationEngine.stopSpeaking()
        conversationEngine.userReplied(display)
        let shouldTypeNextQuestion = advanceToNextQuestion()

        if shouldTypeNextQuestion {
            await presentCurrentQuestion()
        }

        isSubmittingAnswer = false
    }

    private func trackCurrentChatQuestionViewed() {
        guard let question = currentQuestion else { return }
        ProcessAnalytics.trackMossChatQuestionViewed(
            questionID: question.id,
            questionKind: mossQuestionKindName(question.kind),
            questionIndex: currentIndex,
            questionsTotal: questions.count
        )
    }

    private func mossQuestionKindName(_ kind: OnboardingProfileChatQuestionKind) -> String {
        switch kind {
        case .infoContinue: return "info_continue"
        case .singleChoice: return "single_choice"
        case .profileSummary: return "profile_summary"
        }
    }

    private func markQuestionCompleted(_ questionID: String) {
        guard !questionID.isEmpty else { return }
        onboardingViewModel?.markProfileChatQuestionCompleted(questionID)
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
        return currentQuestion != nil
    }
}
