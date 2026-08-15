//
//  OnboardingView+Navigation.swift
//  Process
//
//  Navigation, HealthKit, finalisation onboarding et actions bouton Continuer.
//

import SwiftUI
import LocalAuthentication

extension SportOnboardingView {

// MARK: - Navigation

/// Avance automatiquement à travers les étapes transitoires (sans validation).
func skipTransientStep() {
    guard !isTransitioning else { return }
    guard let currentStep = OnboardingStep(rawValue: viewModel.currentStep),
          currentStep.isTransientSkippedStep else { return }

    guard let visibleStep = resolveFirstVisibleStep(from: viewModel.currentStep),
          visibleStep != viewModel.currentStep,
          visibleStep < totalSteps else {
        return
    }

    commitVisibleStepToHistory(viewModel.currentStep)

    previousStepIndex = viewModel.currentStep
    transitionDirection = .forward
    isTransitioning = true

    commitAnimatedStepChange(to: visibleStep)

    commitVisibleStepToHistory(visibleStep)

    unlockNavigationAfterTransition()

    OnboardingProgressService.shared.saveCurrentStep(visibleStep)
    viewModel.saveProgress()
    scheduleRefreshOnboardingFlowProgress()
}

/// Saute toutes les étapes transitoires d'un coup (évite les animations en chaîne).
private func resolveFirstVisibleStep(from step: Int) -> Int? {
    var cursor = step
    for _ in 0..<40 {
        guard let current = OnboardingStep(rawValue: cursor) else { return nil }
        if !current.isTransientSkippedStep { return cursor }
        guard let next = navigationEngine.nextStep(after: cursor) else { return nil }
        cursor = next
    }
    return nil
}

private func unlockNavigationAfterTransition() {
    DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingTransitionTiming.navigationUnlockDelay) {
        isTransitioning = false
    }
}

/// Après un paiement réussi : page merci + Apple Sign In (sans repasser par le moteur sleep/finalization).
func advanceFromPaymentToPostPaymentWelcome() {
    guard OnboardingStep(rawValue: viewModel.currentStep) == .payment else {
        nextStep()
        return
    }

    let targetStep = OnboardingStep.appleSignIn.rawValue

    HapticManager.shared.notification(.success)
    ProcessAnalytics.trackOnboardingAnswer(step: .payment, viewModel: viewModel)

    OnboardingProgressService.shared.saveLastCompletedStep(viewModel.currentStep)
    commitVisibleStepToHistory(viewModel.currentStep)

    previousStepIndex = viewModel.currentStep
    transitionDirection = .forward
    isTransitioning = true

    commitAnimatedStepChange(to: targetStep)

    commitVisibleStepToHistory(targetStep)

    unlockNavigationAfterTransition()

    OnboardingProgressService.shared.saveCurrentStep(targetStep)
    viewModel.saveProgress()
    scheduleRefreshOnboardingFlowProgress()
}

/// Relance sans paiement : « Ton dashboard t'attend », jamais le paywall ni les témoignages.
func reconcileUnpaidOnboardingResumeIfNeeded() {
    guard !AppSession.shared.hasCompletedOnboarding else { return }
    if SubscriptionService.shared.subscriptionStatus.isActive { return }
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else { return }

    let resume = step.unpaidResumeStep
    if resume != step {
        viewModel.currentStep = resume.rawValue
        OnboardingProgressService.shared.saveCurrentStep(resume.rawValue)
    }

    guard resume == .dashboardPreview else { return }
    commitVisibleStepToHistory(OnboardingStep.dashboardPreview.rawValue)
}

func reconcilePostPaymentStepIfNeeded() {
    guard !AppSession.shared.hasCompletedOnboarding else { return }
    guard SubscriptionService.shared.subscriptionStatus.isActive else { return }
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else { return }

    let shouldSkipToThankYou: Bool
    switch step {
    case .biometricAuth, .transformationPreview, .dashboardPreview, .dreamFaceCommit, .payment:
        shouldSkipToThankYou = true
    default:
        shouldSkipToThankYou = false
    }

    guard shouldSkipToThankYou else { return }

    let targetStep = OnboardingStep.appleSignIn.rawValue
    guard viewModel.currentStep != targetStep else { return }

    viewModel.currentStep = targetStep
    OnboardingProgressService.shared.saveCurrentStep(targetStep)
    viewModel.saveProgress()
    reconcileVisitedStepsForRestore(
        viewModel: viewModel,
        navigationEngine: navigationEngine
    )
    scheduleRefreshOnboardingFlowProgress()
}

func nextStep() {
    viewModel.commitPendingStepAnswers()

    guard viewModel.isCurrentStepValidated() else {
        return
    }

    let warnings = viewModel.validateCrossStepConsistency()
    if !warnings.isEmpty {
    }

    guard let nextStepIndex = navigationEngine.resolveNextVisibleStep(from: viewModel.currentStep),
          nextStepIndex < totalSteps else {
        return
    }

    if let answeredStep = OnboardingStep(rawValue: viewModel.currentStep) {
        ProcessAnalytics.trackOnboardingAnswer(step: answeredStep, viewModel: viewModel)
    }

    HapticManager.shared.impact(.medium)

    OnboardingProgressService.shared.saveLastCompletedStep(viewModel.currentStep)

    commitVisibleStepToHistory(viewModel.currentStep)

    previousStepIndex = viewModel.currentStep
    transitionDirection = .forward
    isTransitioning = true

    commitAnimatedStepChange(to: nextStepIndex)

    commitVisibleStepToHistory(nextStepIndex)

    unlockNavigationAfterTransition()

    OnboardingProgressService.shared.saveCurrentStep(nextStepIndex)
    viewModel.saveProgress()
    scheduleRefreshOnboardingFlowProgress()
}

/// Dashboard preview → commit : hors `nextStep()` pour éviter un no-op silencieux
/// si la validation / le moteur skip la page.
func advanceFromDashboardPreview() {
    guard OnboardingStep(rawValue: viewModel.currentStep) == .dashboardPreview else {
        nextStep()
        return
    }

    // Tap explicite sur « Je le veux » — ne jamais no-op sur isTransitioning.
    isTransitioning = false
    HapticManager.shared.impact(.medium)
    WelcomePlanStore.shared.clearEphemeralPreviewPlan()
    PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)

    let nextStepIndex = OnboardingStep.dreamFaceCommit.rawValue
    ProcessAnalytics.trackOnboardingAnswer(step: .dashboardPreview, viewModel: viewModel)
    OnboardingProgressService.shared.saveLastCompletedStep(viewModel.currentStep)
    commitVisibleStepToHistory(viewModel.currentStep)

    previousStepIndex = viewModel.currentStep
    transitionDirection = .forward
    isTransitioning = true

    commitAnimatedStepChange(to: nextStepIndex)
    commitVisibleStepToHistory(nextStepIndex)

    unlockNavigationAfterTransition()

    OnboardingProgressService.shared.saveCurrentStep(nextStepIndex)
    viewModel.saveProgress()
    scheduleRefreshOnboardingFlowProgress()
}

func continueFromNutritionQuality() {
    viewModel.commitPendingStepAnswers()

    guard OnboardingStep(rawValue: viewModel.currentStep) == .nutritionQuality else {
        nextStep()
        return
    }

    ProcessAnalytics.trackOnboardingAnswer(step: .nutritionQuality, viewModel: viewModel)

    let nextStepIndex = OnboardingStep.biometricAuth.rawValue

    HapticManager.shared.impact(.medium)
    OnboardingProgressService.shared.saveLastCompletedStep(viewModel.currentStep)
    commitVisibleStepToHistory(viewModel.currentStep)

    previousStepIndex = viewModel.currentStep
    transitionDirection = .forward
    isTransitioning = true

    commitAnimatedStepChange(to: nextStepIndex)

    commitVisibleStepToHistory(nextStepIndex)

    unlockNavigationAfterTransition()

    OnboardingProgressService.shared.saveCurrentStep(nextStepIndex)
    viewModel.saveProgress()
    scheduleRefreshOnboardingFlowProgress()
}

// MARK: - Biometric Auth

func triggerBiometricAuthAndContinue() async {
    HapticManager.shared.impact(.medium)

    let context = LAContext()
    var error: NSError?

    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        nextStep()
        return
    }

    let biometricType = context.biometryType
    let reason: String

    switch biometricType {
    case .faceID:
        reason = OnboardingCopy.t(
            "Utilise Face ID pour confirmer ton engagement",
            en: "Use Face ID to confirm your commitment"
        )
    case .touchID:
        reason = OnboardingCopy.t(
            "Restez appuyé avec votre doigt pour confirmer votre engagement",
            en: "Keep your finger on the sensor to confirm your commitment"
        )
    default:
        reason = OnboardingCopy.t(
            "Authentifie-toi pour confirmer ton engagement",
            en: "Authenticate to confirm your commitment"
        )
    }

    do {
        let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        if success {
            HapticManager.shared.notification(.success)
            try? await Task.sleep(nanoseconds: 500_000_000)
            nextStep()
        }
    } catch {
        nextStep()
    }
}

func previousStep() {
    guard !isTransitioning else { return }
    HapticManager.shared.impact(.light)

    viewModel.visitedSteps = normalizeOnboardingVisitedStack(
        visitedSteps: viewModel.visitedSteps,
        currentStep: viewModel.currentStep
    )

    guard viewModel.visitedSteps.count > 1 else {
        return
    }

    var stack = viewModel.visitedSteps
    if stack.last == viewModel.currentStep {
        stack.removeLast()
    } else if let index = stack.lastIndex(of: viewModel.currentStep) {
        stack = Array(stack.prefix(index))
    } else {
        return
    }

    guard let stepToGoBackTo = stack.last else {
        return
    }

    if let targetStep = OnboardingStep(rawValue: stepToGoBackTo) {
        viewModel.prepareForBackNavigation(to: targetStep)
    }

    viewModel.visitedSteps = stack

    previousStepIndex = viewModel.currentStep
    transitionDirection = .backward
    isTransitioning = true

    commitAnimatedStepChange(to: stepToGoBackTo)

    OnboardingProgressService.shared.saveCurrentStep(stepToGoBackTo)
    viewModel.saveProgress()
    scheduleRefreshOnboardingFlowProgress()

    unlockNavigationAfterTransition()
}

/// Retour header : dans la discussion, remonte le fil ; sinon étape précédente.
func handleOnboardingBack() {
    guard !isTransitioning else { return }

    if OnboardingStep(rawValue: viewModel.currentStep) == .programCreation {
        handleBackFromProgramCreation()
        return
    }

    if OnboardingStep(rawValue: viewModel.currentStep) == .weightMotivation,
       viewModel.profileChatBackHandler?() == true {
        HapticManager.shared.impact(.light)
        return
    }
    previousStep()
}

/// Retour création programme → réouvre l'analyse du premier scan (pas la discussion).
func handleBackFromProgramCreation() {
    HapticManager.shared.impact(.light)
    viewModel.isProgramCreationCompleted = false

    if let result = viewModel.restoredFaceScanResultForNavigation() {
        viewModel.isFaceAnalysisCompleted = true
        viewModel.presentOnboardingFaceScan(initialResult: result, usesChatCallbacks: false)
        return
    }

    if let targetStep = OnboardingStep(rawValue: OnboardingStep.weightMotivation.rawValue) {
        viewModel.prepareForBackNavigation(to: targetStep)
    }
    previousStep()
}

@MainActor
func completeProgramCreationBackFaceScan() async {
    viewModel.dismissOnboardingFaceScan()
}

/// Ajoute une étape visible à la pile (tronque une éventuelle branche future).
func commitVisibleStepToHistory(_ step: Int) {
    guard let onboardingStep = OnboardingStep(rawValue: step),
          !onboardingStep.isTransientSkippedStep else {
        return
    }

    if let existingIndex = viewModel.visitedSteps.lastIndex(of: step) {
        viewModel.visitedSteps = Array(viewModel.visitedSteps.prefix(existingIndex + 1))
        return
    }

    if viewModel.visitedSteps.last != step {
        viewModel.visitedSteps.append(step)
    }
}

// MARK: - Progression header (hors body)

func restoreOnboardingProgressFromSavedState() {
    let savedStep = OnboardingProgressService.shared.loadCurrentStep()

    guard let step = OnboardingStep(rawValue: savedStep), savedStep >= 0, savedStep < totalSteps else {
        viewModel.currentStep = OnboardingStep.genderSelection.rawValue
        viewModel.visitedSteps = [OnboardingStep.genderSelection.rawValue]
        viewModel.saveProgress()
        return
    }

    if step == .videoIntroduction {
        viewModel.currentStep = OnboardingStep.genderSelection.rawValue
        viewModel.visitedSteps = [OnboardingStep.genderSelection.rawValue]
        viewModel.saveProgress()
        return
    }

    let canDisplayStep = validateOnboardingStepAvailability(step: step, viewModel: viewModel)

    if canDisplayStep && savedStep > 0 {
        if step.isTransientSkippedStep,
           let visibleStep = navigationEngine.resolveNextVisibleStep(from: savedStep) {
            viewModel.currentStep = visibleStep
        } else {
            viewModel.currentStep = savedStep
        }
    } else if !canDisplayStep && savedStep > 0 {
        let activePath = navigationEngine.buildActiveFlowPath()
        if activePath.contains(savedStep) {
            viewModel.currentStep = savedStep
        } else {
            let lastValidStep = findLastValidOnboardingStepIndex(
                visitedSteps: viewModel.visitedSteps,
                viewModel: viewModel
            )
            viewModel.currentStep = lastValidStep
        }
    } else {
        if viewModel.visitedSteps.isEmpty {
            viewModel.visitedSteps = [OnboardingStep.genderSelection.rawValue]
        }
        if viewModel.currentStep == 0 {
            viewModel.currentStep = OnboardingStep.genderSelection.rawValue
        }
    }

    reconcileVisitedStepsForRestore(
        viewModel: viewModel,
        navigationEngine: navigationEngine
    )
    reconcileUnpaidOnboardingResumeIfNeeded()
    reconcilePostPaymentStepIfNeeded()
    viewModel.saveProgress()
}

func refreshOnboardingFlowProgress() {
    let metrics = onboardingFlowMetrics(
        viewModel: viewModel,
        navigationEngine: navigationEngine
    )
    flowProgress = metrics.progress
    flowTotalSteps = metrics.totalSteps
    flowGlowProgressCount = metrics.glowProgressCount
    viewModel.saveFlowProgress(metrics.progress)
}

/// Regroupe les appels rapprochés (onChange, visitedSteps, branches).
func scheduleRefreshOnboardingFlowProgress() {
    flowProgressRefreshTask?.cancel()
    flowProgressRefreshTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(48))
        guard !Task.isCancelled else { return }
        refreshOnboardingFlowProgress()
    }
}

func cancelScheduledFlowProgressRefresh() {
    flowProgressRefreshTask?.cancel()
    flowProgressRefreshTask = nil
}

func buildPendingStepsQueue() {
    viewModel.pendingSpecificSteps = [.hasSportActivity]
}

// MARK: - HealthKit

func requestHealthKitAndContinue() async {
    HapticManager.shared.impact(.heavy)
    viewModel.isRequestingHealthKit = true

    ProcessAnalytics.trackHealthKitPromptShown(source: "onboarding_legacy")
    await healthManager.requestAuthorizationAsync(analyticsSource: "onboarding_legacy")

    viewModel.healthKitGranted = healthManager.isAuthorized
    viewModel.isRequestingHealthKit = false

    nextStep()
}

func checkPermissions() {
    viewModel.healthKitGranted = healthManager.isAuthorized
}

// MARK: - Completion

    func completeOnboarding() async {
        guard !viewModel.isCompleting else { return }

        HapticManager.shared.impact(.heavy)
        viewModel.isCompleting = true

        do {
            ProcessReferralAttribution.applyPendingIfNeeded(to: viewModel)
            await OnboardingProgressService.shared.savePendingDataIfNeeded(to: profileService)
            let coordinator = OnboardingCoordinator(viewModel: viewModel, profileService: profileService)
            try await coordinator.saveAllOnboardingData()
            try await OnboardingService.shared.completeOnboarding()
            OnboardingProgressService.shared.resetProgress()
            AppSession.shared.completeOnboarding()
            ProcessAnalytics.trackOnboardingCompletedWithProfile(viewModel: viewModel)
            HapticManager.shared.notification(.success)
        } catch {
            ProcessAnalytics.trackOnboardingFailed(error: error.localizedDescription)
            HapticManager.shared.notification(.error)
            viewModel.errorMessage = OnboardingCopy.t(
                "Erreur lors de la finalisation. Veuillez réessayer.",
                en: "Couldn't finish setup. Please try again."
            )
        }

        viewModel.isCompleting = false
    }

// MARK: - Helpers

func savePlanDataProgressively() async {
    await OnboardingProgressService.shared.savePlanData(
        mainGoal: nil,
        experienceLevel: viewModel.selectedExperienceLevel,
        yearsOfExperience: viewModel.selectedYearsOfExperience,
        sessionsPerWeek: viewModel.selectedSessionsPerWeek,
        sessionDuration: viewModel.selectedSessionDuration,
        trainingLocation: viewModel.selectedTrainingLocation,
        equipment: viewModel.selectedEquipment,
        weightGoal: viewModel.selectedWeightGoal,
        to: profileService
    )
}
}
