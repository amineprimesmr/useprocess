//
//  OnboardingFlowHelpers.swift
//  Process
//
//  Validation d'étapes, reprise de progression et estimation du nombre d'étapes — extraits de OnboardingView.
//

import Foundation

// MARK: - Validation de disponibilité d'étape

/// Indique si une étape peut être affichée avec les données actuelles du ViewModel (reprise de progression).
func validateOnboardingStepAvailability(step: OnboardingStep, viewModel: OnboardingViewModel) -> Bool {
    switch step {
    case .goalPace, .weightManagementExperience, .weightFailureReasons:
        return viewModel.hasWeightObjective

    case .idealWeight, .weightGoalIncompatible, .primaryGoal, .weightGoal:
        return false

    case .notificationPermission:
        return false

    case .personalizedWelcome:
        return false

    case .faceLeverageIntro:
        return !viewModel.firstName.isEmpty

    case .sportSelection:
        return viewModel.hasSportActivity == true

    case .hydrationLevel:
        return viewModel.nutritionProfile.hasSufficientHydration == false

    case .planReady, .onboardingInfo, .caloriesGoal, .carryOverCalories:
        return false

    default:
        return true
    }
}

// MARK: - Reprise 1er dashboard preview

/// Étapes réelles après le 1er dashboard (scan) et avant le paywall.
private let onboardingStepsAfterFirstDashboardPreview: [OnboardingStep] = [
    .programCreation,
    .weightEstimation,
    .goalProjection,
    .faceAnalysis,
    .biometricAuth,
    .transformationPreview,
    .referralCode
]

/// L'utilisateur a dépassé le 1er tour dashboard (carrousel + scan).
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

/// Meilleure étape mid-flow quand le 1er dashboard ne doit plus s'afficher.
func bestMidOnboardingResumeStep(viewModel: OnboardingViewModel) -> Int {
    let orderedSteps = onboardingStepsAfterFirstDashboardPreview
    let visited = Set(viewModel.visitedSteps)

    if let match = orderedSteps.reversed().first(where: { visited.contains($0.rawValue) }) {
        return match.rawValue
    }

    let lastCompleted = OnboardingProgressService.shared.loadLastCompletedStep()
    if let step = OnboardingStep(rawValue: lastCompleted),
       orderedSteps.contains(step) {
        return lastCompleted
    }

    if viewModel.isProgramCreationCompleted || viewModel.isFaceAnalysisCompleted {
        return OnboardingStep.programCreation.rawValue
    }

    return OnboardingStep.programCreation.rawValue
}

/// Reprise onboarding : ne pas rouvrir le 1er dashboard si déjà dépassé.
func reconcileFirstDashboardPreviewResumeIfNeeded(viewModel: OnboardingViewModel) {
    guard !AppSession.shared.hasCompletedOnboarding else { return }
    if SubscriptionService.shared.subscriptionStatus.isActive { return }
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else { return }

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

// MARK: - Dernière étape valide (reprise)

/// Parcourt l'historique des étapes visitées et retourne la dernière étape affichable.
func findLastValidOnboardingStepIndex(visitedSteps: [Int], viewModel: OnboardingViewModel) -> Int {
    for stepValue in visitedSteps.reversed() {
        guard let step = OnboardingStep(rawValue: stepValue) else { continue }
        if validateOnboardingStepAvailability(step: step, viewModel: viewModel) {
            return stepValue
        }
    }
    return OnboardingStep.genderSelection.rawValue
}

// MARK: - Progression barre / lueur

/// Parcours utilisé pour la barre : dérivé du moteur de navigation (questionnaire jusqu'à `nutritionQuality`).
func buildOnboardingProgressFlowPath(
    viewModel: OnboardingViewModel,
    navigationEngine: OnboardingNavigationEngine
) -> [Int] {
    let activePath = navigationEngine.buildActiveFlowPath()
    var progressPath: [Int] = []

    for rawStep in activePath {
        guard let step = OnboardingStep(rawValue: rawStep) else { continue }
        if step == .videoIntroduction { continue }
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
    case .faceAnalysis, .programCreation, .healthKitPermissions, .sleepDataRecovery,
         .biometricAuth, .notificationPermission, .transformationPreview, .dashboardPreview, .dreamFaceCommit, .payment, .appleSignIn, .processWelcome,
         .complete, .referralReward, .featuresUnlock:
        return true
    default:
        return false
    }
}

/// Étapes finales qui gardent le header « retour seul » (sans barre ni drapeau).
func showsBackOnlyOnboardingHeader(_ step: OnboardingStep) -> Bool {
    switch step {
    case .biometricAuth, .transformationPreview, .programCreation:
        return true
    default:
        return false
    }
}

/// Étapes après la page prénom — pas de barre de progression ni lueur header.
func isAfterFirstNameProgressPhase(_ step: OnboardingStep) -> Bool {
    switch step {
    case .genderSelection, .ageSelection, .height, .weight, .heightWeight, .bodyScan,
         .idealWeight, .weightGoalIncompatible, .firstNameInput:
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

    if let step = OnboardingStep(rawValue: viewModel.currentStep),
       isAfterFirstNameProgressPhase(step) || isAfterQuestionnairePhase(step) {
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

/// Calcule en une seule passe les métriques utilisées par la barre et la lueur.
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

    if let current = OnboardingStep(rawValue: viewModel.currentStep),
       isAfterQuestionnairePhase(current) || isAfterFirstNameProgressPhase(current) {
        return (progress: 1.0, totalSteps: totalSteps, glowProgressCount: totalSteps)
    }

    let count = progressCount(in: path, viewModel: viewModel)
    return (
        progress: min(1.0, Double(count) / Double(totalSteps)),
        totalSteps: totalSteps,
        glowProgressCount: count
    )
}

/// Réaligne l'historique visité sur le parcours actif (reprise après relance ou changement de branche).
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

/// Reconstruit l'historique visité comme préfixe du parcours jusqu'à l'étape cible (étapes visibles uniquement).
func rebuildVisitedStepsPrefix(
    to targetStep: Int,
    viewModel: OnboardingViewModel,
    navigationEngine: OnboardingNavigationEngine
) -> [Int] {
    let path = navigationEngine.buildActiveFlowPath()
    let visiblePath = path.filter {
        guard let step = OnboardingStep(rawValue: $0) else { return false }
        return !step.isTransientSkippedStep
    }

    let pathIndex = visiblePath.firstIndex(of: targetStep)

    if let index = pathIndex {
        return Array(visiblePath.prefix(index + 1))
    }

    if let step = OnboardingStep(rawValue: targetStep), !step.isTransientSkippedStep {
        return [targetStep]
    }

    return visiblePath.isEmpty ? [OnboardingStep.genderSelection.rawValue] : [visiblePath[0]]
}

/// Normalise la pile : étapes visibles uniquement, dernière = étape courante.
func normalizeOnboardingVisitedStack(
    visitedSteps: [Int],
    currentStep: Int
) -> [Int] {
    var stack = visitedSteps.filter {
        guard let step = OnboardingStep(rawValue: $0) else { return false }
        return !step.isTransientSkippedStep
    }

    guard let step = OnboardingStep(rawValue: currentStep), !step.isTransientSkippedStep else {
        return stack
    }

    if let index = stack.lastIndex(of: currentStep) {
        stack = Array(stack.prefix(index + 1))
    } else {
        stack.append(currentStep)
    }

    return stack
}

// MARK: - Nombre d'étapes pour la barre / lueur
