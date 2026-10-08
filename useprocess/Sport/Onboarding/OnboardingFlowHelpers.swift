//
//  OnboardingFlowHelpers.swift
//  Process
//

import Foundation

// MARK: - Reprise 1er dashboard preview

/// Étapes réelles après le 1er dashboard (scan) et avant le paywall.
private let onboardingStepsAfterFirstDashboardPreview: [OnboardingStep] = [
    .programCreation,
    .weightEstimation,
    .biometricAuth,
    .transformationPreview,
    .referralCode
]

func hasPassedFirstDashboardPreviewSection(viewModel: OnboardingViewModel) -> Bool {
    if viewModel.hasCompletedFirstDashboardPreview { return true }
    if viewModel.isFaceAnalysisCompleted { return true }
    if viewModel.isProgramCreationCompleted { return true }

    let markerRawValues = Set(onboardingStepsAfterFirstDashboardPreview.map(\.rawValue))
    if viewModel.visitedSteps.contains(where: markerRawValues.contains) {
        return true
    }

    let lastCompleted = OnboardingProgressService.shared.loadLastCompletedStep()
    if markerRawValues.contains(lastCompleted) {
        return true
    }

    return false
}

func bestMidOnboardingResumeStep(viewModel: OnboardingViewModel) -> Int {
    let orderedSteps = onboardingStepsAfterFirstDashboardPreview
    let visited = Set(viewModel.visitedSteps)

    if let match = orderedSteps.reversed().first(where: { visited.contains($0.rawValue) }) {
        return match.rawValue
    }

    let lastCompleted = OnboardingProgressService.shared.loadLastCompletedStep()
    let lastStep = OnboardingStep.resolved(from: lastCompleted)
    if orderedSteps.contains(lastStep) {
        return lastCompleted
    }

    return OnboardingStep.programCreation.rawValue
}

func reconcileFirstDashboardPreviewResumeIfNeeded(viewModel: OnboardingViewModel) {
    guard !AppSession.shared.hasCompletedOnboarding else { return }
    guard SubscriptionService.shared.hasResolvedInitialSubscriptionStatus else { return }
    if SubscriptionService.shared.subscriptionStatus.isActive { return }
    let step = OnboardingStep.resolved(from: viewModel.currentStep)

    if onboardingStepsAfterFirstDashboardPreview.contains(step) {
        return
    }

    guard step == .dashboardPreview else { return }

    let hasSeenLateOnboarding = viewModel.visitedSteps.contains(
        OnboardingStep.transformationPreview.rawValue
    ) || viewModel.visitedSteps.contains(OnboardingStep.referralCode.rawValue)

    if hasSeenLateOnboarding {
        viewModel.currentStep = OnboardingStep.dreamFaceCommit.rawValue
        OnboardingProgressService.shared.saveCurrentStep(OnboardingStep.dreamFaceCommit.rawValue)
        return
    }

    if viewModel.hasActiveFirstDashboardScanSession {
        return
    }

    if viewModel.isFaceAnalysisCompleted, !viewModel.hasCompletedFirstDashboardPreview {
        return
    }

    guard hasPassedFirstDashboardPreviewSection(viewModel: viewModel) else { return }

    let target = bestMidOnboardingResumeStep(viewModel: viewModel)
    guard target != OnboardingStep.dashboardPreview.rawValue else { return }

    if viewModel.isFaceAnalysisCompleted, !viewModel.hasCompletedFirstDashboardPreview {
        viewModel.hasCompletedFirstDashboardPreview = true
    }

    viewModel.currentStep = target
    OnboardingProgressService.shared.saveCurrentStep(target)
}

func isAfterQuestionnairePhase(_ step: OnboardingStep) -> Bool {
    switch step {
    case .programCreation, .weightEstimation, .biometricAuth, .transformationPreview,
         .dashboardPreview, .dreamFaceCommit, .payment, .appleSignIn, .complete,
         .postPaymentWelcome, .explainerBodyFat, .explainerWaterRetention, .explainerLymphDrainage:
        return true
    default:
        return false
    }
}

func showsBackOnlyOnboardingHeader(_ step: OnboardingStep) -> Bool {
    switch step {
    case .biometricAuth, .transformationPreview, .programCreation:
        return true
    default:
        return false
    }
}

func isAfterFirstNameProgressPhase(_ step: OnboardingStep) -> Bool {
    switch step {
    case .genderSelection, .ageSelection, .height, .weight, .firstNameInput:
        return false
    default:
        return true
    }
}

/// La barre de progression ne couvre que le questionnaire initial (genre → prénom).
private let onboardingProgressBarSteps: [OnboardingStep] = [
    .genderSelection, .ageSelection, .height, .weight, .firstNameInput
]

func onboardingFlowMetrics(
    currentStep: Int
) -> (progress: Double, totalSteps: Int, glowProgressCount: Int) {
    let totalSteps = onboardingProgressBarSteps.count
    let current = OnboardingStep.resolved(from: currentStep)

    guard let index = onboardingProgressBarSteps.firstIndex(of: current) else {
        return (progress: 1.0, totalSteps: totalSteps, glowProgressCount: totalSteps)
    }

    let count = index + 1
    return (
        progress: Double(count) / Double(totalSteps),
        totalSteps: totalSteps,
        glowProgressCount: count
    )
}

/// Le parcours est linéaire : la pile « retour » est toujours le préfixe du flow jusqu'à l'étape courante.
func reconcileVisitedStepsForRestore(viewModel: OnboardingViewModel) {
    let expected = visitedStepsPrefix(to: viewModel.currentStep)
    if viewModel.visitedSteps != expected {
        viewModel.visitedSteps = expected
    }
}

func visitedStepsPrefix(to targetStep: Int) -> [Int] {
    let flow = OnboardingStep.visibleFlow.map(\.rawValue)
    guard let index = flow.firstIndex(of: targetStep) else {
        return [targetStep]
    }
    return Array(flow.prefix(index + 1))
}

func normalizeOnboardingVisitedStack(
    visitedSteps: [Int],
    currentStep: Int
) -> [Int] {
    var stack = visitedSteps.filter { OnboardingStep(rawValue: $0) != nil }

    let step = OnboardingStep.resolved(from: currentStep)
    guard !step.isTransientSkippedStep else {
        return stack
    }

    if let index = stack.lastIndex(of: currentStep) {
        stack = Array(stack.prefix(index + 1))
    } else {
        stack.append(currentStep)
    }

    return stack
}
