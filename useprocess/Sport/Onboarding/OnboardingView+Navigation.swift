//
//  OnboardingView+Navigation.swift
//  Process
//
//  Navigation, HealthKit, finalisation onboarding et actions bouton Continuer.
//

import SwiftUI

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
    DispatchQueue.main.asyncAfter(deadline: .now() + activeNavigationUnlockDelay) {
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

    reconcileFirstDashboardPreviewResumeIfNeeded(viewModel: viewModel)

    if OnboardingStep(rawValue: viewModel.currentStep) == .dashboardPreview {
        commitVisibleStepToHistory(OnboardingStep.dashboardPreview.rawValue)
    }
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

    performOnboardingStepAdvance()
}

func performOnboardingStepAdvance() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )

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

    if let previousOnboardingStep = OnboardingStep(rawValue: viewModel.currentStep),
       let nextOnboardingStep = OnboardingStep(rawValue: nextStepIndex) {
        viewModel.configureDashboardPreviewPresentation(
            entering: nextOnboardingStep,
            from: previousOnboardingStep
        )
    }

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

@MainActor
func advanceFromEarlyDashboardFaceScan() {
    guard OnboardingStep(rawValue: viewModel.currentStep) == .dashboardPreview else { return }

    isTransitioning = false
    HapticManager.shared.notification(.success)
    viewModel.dashboardPreviewPresentation = .firstScanPending
    viewModel.hasCompletedFirstDashboardPreview = true
    viewModel.clearDashboardScanPersistedState()

    let nextStepIndex = OnboardingStep.programCreation.rawValue
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

func previousStep() {
    guard !isTransitioning else { return }
    HapticManager.shared.impact(.light)

    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )

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

    if OnboardingStep(rawValue: viewModel.currentStep) == .dashboardPreview,
       viewModel.dashboardPreviewPresentation == .firstScanPending {
        viewModel.prepareForBackNavigation(to: .weightMotivation)
        previousStep()
        return
    }

    if OnboardingStep(rawValue: viewModel.currentStep) == .weightMotivation,
       viewModel.profileChatBackHandler?() == true {
        HapticManager.shared.impact(.light)
        return
    }
    previousStep()
}

func skipCreatorCodeStep() {
    guard !isTransitioning else { return }
    guard OnboardingStep(rawValue: viewModel.currentStep) == .referralCode else { return }

    HapticManager.shared.impact(.light)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    if viewModel.creatorCodeIsVerified {
        viewModel.commitCreatorCodeDraft()
    } else {
        viewModel.creatorCodeDraft = ""
        viewModel.creatorCodeIsVerified = false
    }
    performOnboardingStepAdvance()
}

func advanceFromVerifiedCreatorCode() {
    guard !isTransitioning else { return }
    guard OnboardingStep(rawValue: viewModel.currentStep) == .referralCode else { return }
    guard viewModel.creatorCodeIsVerified else { return }

    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
    viewModel.commitCreatorCodeDraft()
    performOnboardingStepAdvance()
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
    OnboardingProgressService.shared.migrateInProgressStorageIfNeeded()

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
    if OnboardingStep(rawValue: viewModel.currentStep) == .dashboardPreview {
        reconcileFirstDashboardPreviewResumeIfNeeded(viewModel: viewModel)
    }
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

}
