//
//  OnboardingView+Navigation.swift
//  Process
//
//  Navigation, reprise, finalisation onboarding et actions bouton Continuer.
//

import SwiftUI

extension SportOnboardingView {

// MARK: - Navigation

private func unlockNavigationAfterTransition(from: Int, to: Int) {
    navigationUnlockTask?.cancel()
    let duration = navigationLockDuration(from: from, to: to)
    navigationUnlockTask = Task { @MainActor in
        try? await Task.sleep(for: .seconds(duration))
        guard !Task.isCancelled else { return }
        isTransitioning = false
    }
}

private func navigationLockDuration(from: Int, to: Int) -> TimeInterval {
    if reduceMotion { return 0.12 }
    if Self.usesDashboardRevealTransition(from: from, to: to) { return 0.48 }
    if Self.usesScanStylePagePush(from: from, to: to) { return 0.42 }
    if Self.usesEarlyOnboardingTransition(from: from, to: to) { return 0.44 }
    return 0.36
}

/// Transition animée vers `targetStep` + historique + persistance — seul point d'avance du flow.
private func advance(to targetStep: Int) {
    let fromStep = viewModel.currentStep

    OnboardingProgressService.shared.saveLastCompletedStep(fromStep)
    commitVisibleStepToHistory(fromStep)

    previousStepIndex = fromStep
    transitionDirection = .forward
    isTransitioning = true

    commitAnimatedStepChange(to: targetStep)
    commitVisibleStepToHistory(targetStep)

    unlockNavigationAfterTransition(from: fromStep, to: targetStep)

    // `onChange(of: currentStep)` persiste l'étape et rafraîchit la progression.
}

/// Après un paiement réussi : page merci, même si une transition est encore en cours.
func advanceFromPaymentToPostPaymentWelcome() {
    guard OnboardingStep(rawValue: viewModel.currentStep) == .payment else {
        nextStep()
        return
    }

    HapticManager.shared.notification(.success)
    ProcessAnalytics.trackOnboardingAnswer(step: .payment, viewModel: viewModel)
    advance(to: OnboardingStep.postPaymentWelcome.rawValue)
}

/// Relance sans paiement : « Ton dashboard t'attend », jamais le paywall ni les témoignages.
func reconcileUnpaidOnboardingResumeIfNeeded() {
    guard !AppSession.shared.hasCompletedOnboarding else { return }
    // Statut encore `.unknown` au lancement : ne pas renvoyer un abonné vers l'écran d'engagement.
    guard SubscriptionService.shared.hasResolvedInitialSubscriptionStatus else { return }
    // Vérification échouée (hors ligne, timeout) : statut `.unknown`, on ne rétrograde pas un abonné potentiel.
    guard SubscriptionService.shared.subscriptionStatus != .unknown else { return }
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
    case .programCreation, .weightEstimation, .biometricAuth, .transformationPreview,
         .referralCode, .dashboardPreview, .dreamFaceCommit, .payment:
        shouldSkipToThankYou = true
    default:
        shouldSkipToThankYou = false
    }

    guard shouldSkipToThankYou else { return }

    let targetStep = OnboardingStep.postPaymentWelcome.rawValue
    guard viewModel.currentStep != targetStep else { return }

    viewModel.currentStep = targetStep
    OnboardingProgressService.shared.saveCurrentStep(targetStep)
    viewModel.saveProgress()
    reconcileVisitedStepsForRestore(viewModel: viewModel)
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
    guard !isTransitioning else { return }

    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )

    let current = OnboardingStep.resolved(from: viewModel.currentStep)
    guard let next = current.nextVisibleStep else { return }

    if current == .weight {
        viewModel.refreshBodyCompositionRouting()
    }

    ProcessAnalytics.trackOnboardingAnswer(step: current, viewModel: viewModel)
    HapticManager.shared.impact(.medium)
    advance(to: next.rawValue)
}

@MainActor
func advanceFromEarlyDashboardFaceScan() {
    guard OnboardingStep(rawValue: viewModel.currentStep) == .dashboardPreview else { return }

    HapticManager.shared.notification(.success)
    viewModel.hasCompletedFirstDashboardPreview = true
    viewModel.clearDashboardScanPersistedState()

    ProcessAnalytics.trackOnboardingAnswer(step: .dashboardPreview, viewModel: viewModel)
    advance(to: OnboardingStep.programCreation.rawValue)
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

    unlockNavigationAfterTransition(from: previousStepIndex ?? stepToGoBackTo, to: stepToGoBackTo)
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

func handleReferralCodeContinue() {
    guard !isTransitioning else { return }
    guard OnboardingStep(rawValue: viewModel.currentStep) == .referralCode else { return }

    if viewModel.creatorCodeIsVerified {
        advanceFromVerifiedCreatorCode()
        return
    }

    let normalized = ProcessReferralCode.normalize(viewModel.creatorCodeDraft)
    if normalized.isEmpty {
        skipCreatorCodeStep()
        return
    }

    viewModel.creatorCodeContinueAttempt += 1
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
    let step = OnboardingStep.resolved(from: savedStep)

    if savedStep < 0 {
        viewModel.currentStep = OnboardingStep.genderSelection.rawValue
        viewModel.visitedSteps = [OnboardingStep.genderSelection.rawValue]
        viewModel.saveProgress()
        return
    }

    if savedStep > 0 {
        // Étape désactivée (code créateur) : on reprend sur l'écran suivant.
        if step.isTransientSkippedStep, let visible = step.nextVisibleStep {
            viewModel.currentStep = visible.rawValue
        } else {
            viewModel.currentStep = step.rawValue
        }
    } else if OnboardingStep(rawValue: viewModel.currentStep) == nil {
        viewModel.currentStep = OnboardingStep.genderSelection.rawValue
    }

    reconcileVisitedStepsForRestore(viewModel: viewModel)
    reconcileUnpaidOnboardingResumeIfNeeded()
    reconcilePostPaymentStepIfNeeded()
    if OnboardingStep(rawValue: viewModel.currentStep) == .dashboardPreview {
        reconcileFirstDashboardPreviewResumeIfNeeded(viewModel: viewModel)
    }
    viewModel.saveProgress()
}

func refreshOnboardingFlowProgress() {
    let metrics = onboardingFlowMetrics(currentStep: viewModel.currentStep)
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
        guard !viewModel.isCompleting, !AppSession.shared.hasCompletedOnboarding else { return }

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
