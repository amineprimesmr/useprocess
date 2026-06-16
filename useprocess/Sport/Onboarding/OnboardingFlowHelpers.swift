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
    case .videoIntroduction, .genderSelection, .ageSelection, .height, .weight,
         .hasSportActivity, .deadlineSelection, .eventDetails, .nutritionQuality,
         .hasSufficientHydration,
         .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks,
         .healthKitPermissions, .planGeneration, .sleepDataRecovery,
         .newsStep, .sleepNeedReveal, .sleepDebtInfo,
         .nutritionPotential, .alarmConfiguration, .sleepWindowReveal,
         .sleepNeed, .referralCode, .referralReward,
         .featuresUnlock, .payment, .appRating, .appleSignIn,
         .biometricAuth, .notificationPermission, .processWelcome, .complete,
         .nutritionScanFeature, .yearsOfExperience,
         .hasDietaryRestrictions, .whichRestrictions, .faceAnalysis:
        return true

    case .heightWeight:
        return true
    case .bodyScan:
        return true
    case .primaryGoal:
        return true
    case .firstNameInput:
        return true
    case .personalizedWelcome:
        return !viewModel.firstName.isEmpty
    case .processResultsDurability:
        return true

    case .weightGoal:
        return true
    case .idealWeight:
        return true
    case .weightMotivation, .goalPace,
         .weightManagementExperience, .weightFailureReasons:
        return viewModel.hasWeightObjective

    case .weightEstimation:
        return true

    case .weightGoalIncompatible:
        return viewModel.selectedWeightGoal != nil
    case .goalProjection, .potentialPace:
        return true

    case .sportSelection:
        return viewModel.hasSportActivity == true
    case .sportClub, .experienceLevel, .hardestMeal:
        return true

    case .hydrationLevel:
        return viewModel.nutritionProfile.hasSufficientHydration == false

    case .nutritionObstacles:
        return true

    case .perfectNutritionBelief:
        return true

    case .trainingFrequency:
        return true

    case .planReady, .onboardingInfo,
         .caloriesGoal, .carryOverCalories:
        return false
    case .programCreation:
        return true
    }
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
    return OnboardingStep.videoIntroduction.rawValue
}

// MARK: - Progression barre / lueur

/// Parcours utilisé pour la barre : uniquement le questionnaire, terminé à `nutritionQuality`.
func buildOnboardingProgressFlowPath(
    viewModel: OnboardingViewModel
) -> [Int] {
    return buildExplicitOnboardingProgressFlowPath(viewModel: viewModel)
}

private func buildExplicitOnboardingProgressFlowPath(viewModel: OnboardingViewModel) -> [Int] {
    var steps: [OnboardingStep] = [
        .genderSelection, .ageSelection, .height, .weight, .firstNameInput, .idealWeight
    ]

    if viewModel.hasWeightObjective {
        steps.append(contentsOf: [.weightMotivation, .goalPace, .weightEstimation])
    } else {
        steps.append(.weightEstimation)
    }

    steps.append(.hasSportActivity)

    if viewModel.hasSportActivity == true {
        steps.append(.sportSelection)
    }

    steps.append(.goalProjection)

    if viewModel.hasWeightObjective {
        steps.append(.weightManagementExperience)
        if let experience = viewModel.nutritionProfile.weightManagementExperience,
           experience == .triedMultiple || experience == .currentlyTrying {
            steps.append(.weightFailureReasons)
        }
    }

    steps.append(.nutritionQuality)
    return steps.map(\.rawValue)
}

func isAfterQuestionnairePhase(_ step: OnboardingStep) -> Bool {
    switch step {
    case .faceAnalysis, .programCreation, .healthKitPermissions, .sleepDataRecovery,
         .biometricAuth, .notificationPermission, .payment, .processWelcome,
         .complete, .referralReward, .featuresUnlock:
        return true
    default:
        return false
    }
}

func furthestProgressIndex(in path: [Int], viewModel: OnboardingViewModel) -> Int? {
    path.enumerated()
        .filter { viewModel.visitedSteps.contains($0.element) }
        .map(\.offset)
        .max()
}

/// Calcule en une seule passe les métriques utilisées par la barre et la lueur.
func onboardingFlowMetrics(viewModel: OnboardingViewModel) -> (progress: Double, totalSteps: Int, glowProgressCount: Int) {
    let path = buildOnboardingProgressFlowPath(viewModel: viewModel)
    guard !path.isEmpty else {
        return (progress: 0, totalSteps: 1, glowProgressCount: 1)
    }

    let totalSteps = max(path.count, 1)

    if let current = OnboardingStep(rawValue: viewModel.currentStep),
       isAfterQuestionnairePhase(current) {
        return (progress: 1.0, totalSteps: totalSteps, glowProgressCount: totalSteps)
    }

    if let index = path.firstIndex(of: viewModel.currentStep) {
        let count = index + 1
        return (
            progress: min(1.0, Double(count) / Double(totalSteps)),
            totalSteps: totalSteps,
            glowProgressCount: count
        )
    }

    if let furthestIndex = furthestProgressIndex(in: path, viewModel: viewModel) {
        var progress = Double(furthestIndex + 1) / Double(totalSteps)
        let glowProgressCount = furthestIndex + 1

        return (
            progress: min(1.0, progress),
            totalSteps: totalSteps,
            glowProgressCount: glowProgressCount
        )
    }

    return (progress: 0, totalSteps: totalSteps, glowProgressCount: 1)
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

    if let index = visiblePath.firstIndex(of: targetStep) {
        return Array(visiblePath.prefix(index + 1))
    }

    if let step = OnboardingStep(rawValue: targetStep), !step.isTransientSkippedStep {
        return [targetStep]
    }

    return visiblePath.isEmpty ? [OnboardingStep.videoIntroduction.rawValue] : [visiblePath[0]]
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
