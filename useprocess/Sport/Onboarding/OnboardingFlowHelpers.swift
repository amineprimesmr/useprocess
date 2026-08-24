//
//  OnboardingFlowHelpers.swift
//  Process
//

import Foundation

// MARK: - Validation de disponibilité d'étape

func validateOnboardingStepAvailability(step: OnboardingStep, viewModel: OnboardingViewModel) -> Bool {
    switch step {
    case .faceLeverageIntro:
        return !viewModel.firstName.isEmpty
    default:
        return true
    }
}

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

func findLastValidOnboardingStepIndex(visitedSteps: [Int], viewModel: OnboardingViewModel) -> Int {
    for stepValue in visitedSteps.reversed() {
        guard let step = OnboardingStep(rawValue: stepValue) else { continue }
        if validateOnboardingStepAvailability(step: step, viewModel: viewModel) {
            return stepValue
        }
    }
    return OnboardingStep.genderSelection.rawValue
}

func buildOnboardingProgressFlowPath(
    viewModel: OnboardingViewModel,
    navigationEngine: OnboardingNavigationEngine
) -> [Int] {
    let activePath = navigationEngine.buildActiveFlowPath()
    var progressPath: [Int] = []

    for rawStep in activePath {
        let step = OnboardingStep.resolved(from: rawStep)
        if step == .firstNameInput {
            progressPath.append(rawStep)
            break
        }
        if isAfterQuestionnairePhase(step) { break }
        if step.isTransientSkippedStep { continue }
        progressPath.append(rawStep)
    }

    return progressPath
}

func isAfterQuestionnairePhase(_ step: OnboardingStep) -> Bool {
    switch step {
    case .programCreation, .weightEstimation, .biometricAuth, .transformationPreview,
         .dashboardPreview, .dreamFaceCommit, .payment, .appleSignIn, .complete:
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

private func progressCount(
    in path: [Int],
    viewModel: OnboardingViewModel
) -> Int {
    guard !path.isEmpty else { return 1 }

    if let index = path.firstIndex(of: viewModel.currentStep) {
        return index + 1
    }

    let step = OnboardingStep.resolved(from: viewModel.currentStep)
    if isAfterFirstNameProgressPhase(step) || isAfterQuestionnairePhase(step) {
        return path.count
    }

    let stack = normalizeOnboardingVisitedStack(
        visitedSteps: viewModel.visitedSteps,
        currentStep: viewModel.currentStep
    )

    let matchedIndices = stack.compactMap { path.firstIndex(of: $0) }
    if let bestMatched = matchedIndices.max() {
        return bestMatched + 1
    }

    return 1
}

func onboardingFlowMetrics(
    viewModel: OnboardingViewModel,
    navigationEngine: OnboardingNavigationEngine
) -> (progress: Double, totalSteps: Int, glowProgressCount: Int) {
    let path = buildOnboardingProgressFlowPath(
        viewModel: viewModel,
        navigationEngine: navigationEngine
    )
    guard !path.isEmpty else {
        return (progress: 0, totalSteps: 1, glowProgressCount: 1)
    }

    let totalSteps = max(path.count, 1)
    let current = OnboardingStep.resolved(from: viewModel.currentStep)

    if isAfterQuestionnairePhase(current) || isAfterFirstNameProgressPhase(current) {
        return (progress: 1.0, totalSteps: totalSteps, glowProgressCount: totalSteps)
    }

    let count = progressCount(in: path, viewModel: viewModel)
    return (
        progress: min(1.0, Double(count) / Double(totalSteps)),
        totalSteps: totalSteps,
        glowProgressCount: count
    )
}

func reconcileVisitedStepsForRestore(
    viewModel: OnboardingViewModel,
    navigationEngine: OnboardingNavigationEngine
) {
    let expectedPrefix = rebuildVisitedStepsPrefix(
        to: viewModel.currentStep,
        viewModel: viewModel,
        navigationEngine: navigationEngine
    )
    let normalized = normalizeOnboardingVisitedStack(
        visitedSteps: viewModel.visitedSteps,
        currentStep: viewModel.currentStep
    )

    let needsRebuild = normalized.isEmpty
        || normalized.last != viewModel.currentStep
        || normalized.count != expectedPrefix.count
        || normalized != expectedPrefix

    viewModel.visitedSteps = needsRebuild ? expectedPrefix : normalized
}

func rebuildVisitedStepsPrefix(
    to targetStep: Int,
    viewModel: OnboardingViewModel,
    navigationEngine: OnboardingNavigationEngine
) -> [Int] {
    let path = navigationEngine.buildActiveFlowPath()
    let visiblePath = path.filter {
        !OnboardingStep.resolved(from: $0).isTransientSkippedStep
    }

    if let index = visiblePath.firstIndex(of: targetStep) {
        return Array(visiblePath.prefix(index + 1))
    }

    let step = OnboardingStep.resolved(from: targetStep)
    if !step.isTransientSkippedStep {
        return [targetStep]
    }

    return visiblePath.isEmpty ? [OnboardingStep.genderSelection.rawValue] : [visiblePath[0]]
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
