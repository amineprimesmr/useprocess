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
         .notificationPermission, .processWelcome, .complete,
         .nutritionScanFeature, .yearsOfExperience,
         .hasDietaryRestrictions, .whichRestrictions, .faceAnalysis:
        return true

    case .heightWeight:
        return true
    case .bodyScan:
        return true
    case .primaryGoal:
        return viewModel.hasWeightGoal != nil
    case .firstNameInput:
        return true
    case .personalizedWelcome:
        return !viewModel.firstName.isEmpty
    case .processResultsDurability:
        return true

    case .weightGoal:
        return true
    case .idealWeight, .weightMotivation, .goalPace,
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
         .biometricAuth, .caloriesGoal, .carryOverCalories:
        return false
    case .programCreation:
        return true
    }
}

// MARK: - Dernière étape valide (reprise)

/// Parcourt l'historique des étapes visitées et retourne la dernière étape affichable.
func findLastValidOnboardingStepIndex(visitedSteps: [Int], viewModel: OnboardingViewModel) -> Int {
    let sorted = visitedSteps.sorted()
    for stepValue in sorted.reversed() {
        guard let step = OnboardingStep(rawValue: stepValue) else { continue }
        if validateOnboardingStepAvailability(step: step, viewModel: viewModel) {
            return stepValue
        }
    }
    return OnboardingStep.videoIntroduction.rawValue
}

// MARK: - Progression barre / lueur

/// Étapes du questionnaire affichant la barre de progression (jusqu'à nutrition, avant le scan facial).
private let onboardingProgressExcludedSteps: Set<OnboardingStep> = [
    .videoIntroduction,
    .goalProjection,
    .weightEstimation,
    .faceAnalysis
]

/// Parcours utilisé pour la barre : du genre à la nutrition (dernière étape avec barre), scan facial exclu.
func buildOnboardingProgressFlowPath(
    viewModel: OnboardingViewModel,
    navigationEngine: OnboardingNavigationEngine
) -> [Int] {
    var result: [Int] = []
    var cursor: Int? = OnboardingStep.genderSelection.rawValue
    var visited = Set<Int>()

    for _ in 0..<80 {
        guard let stepValue = cursor else { break }
        guard visited.insert(stepValue).inserted else { break }
        guard let step = OnboardingStep(rawValue: stepValue) else { break }
        if step == .faceAnalysis { break }
        if !step.isTransientSkippedStep && !onboardingProgressExcludedSteps.contains(step) {
            result.append(stepValue)
        }
        cursor = navigationEngine.resolveNextVisibleStep(from: stepValue)
    }

    if !result.isEmpty {
        return result
    }

    return buildExplicitOnboardingProgressFlowPath(viewModel: viewModel)
}

/// Parcours déterministe de secours si la simulation échoue.
private func buildExplicitOnboardingProgressFlowPath(viewModel: OnboardingViewModel) -> [Int] {
    var steps: [OnboardingStep] = [
        .genderSelection, .ageSelection, .height, .weight, .firstNameInput, .primaryGoal
    ]

    if viewModel.hasWeightObjective {
        steps.append(contentsOf: [.idealWeight, .weightMotivation, .goalPace])
    }

    steps.append(.hasSportActivity)

    if viewModel.hasSportActivity == true {
        steps.append(.sportSelection)
    }

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

func isPostFaceScanOnboardingPhase(_ step: OnboardingStep) -> Bool {
    switch step {
    case .faceAnalysis, .programCreation, .healthKitPermissions, .sleepDataRecovery,
         .biometricAuth, .notificationPermission, .payment, .processWelcome,
         .complete, .referralReward, .featuresUnlock:
        return true
    default:
        return false
    }
}

/// Clé pour recalculer la progression sans recalculer le parcours à chaque frame SwiftUI.
func onboardingFlowProgressCacheKey(viewModel: OnboardingViewModel) -> String {
    let weightGoalFlag = viewModel.hasWeightGoal.map { $0 ? "1" : "0" } ?? "n"
    let sport = viewModel.hasSportActivity.map { $0 ? "1" : "0" } ?? "n"
    let weightExperience = viewModel.nutritionProfile.weightManagementExperience?.rawValue ?? ""
    return "\(viewModel.currentStep)|\(weightGoalFlag)|\(sport)|\(viewModel.isIdealWeightEntered)|\(weightExperience)"
}

func furthestProgressIndex(in path: [Int], viewModel: OnboardingViewModel) -> Int? {
    path.enumerated()
        .filter { viewModel.visitedSteps.contains($0.element) }
        .map(\.offset)
        .max()
}

/// Progression normalisée 0…1 — complète à 100 % sur la dernière étape questionnaire (nutrition).
func onboardingFlowProgress(
    viewModel: OnboardingViewModel,
    navigationEngine: OnboardingNavigationEngine
) -> Double {
    let path = buildOnboardingProgressFlowPath(viewModel: viewModel, navigationEngine: navigationEngine)
    guard !path.isEmpty else { return 0 }

    if let current = OnboardingStep(rawValue: viewModel.currentStep),
       isPostFaceScanOnboardingPhase(current) {
        return 1.0
    }

    if let index = path.firstIndex(of: viewModel.currentStep) {
        return min(1.0, Double(index + 1) / Double(path.count))
    }

    if let furthestIndex = furthestProgressIndex(in: path, viewModel: viewModel) {
        var progress = Double(furthestIndex + 1) / Double(path.count)

        if let current = OnboardingStep(rawValue: viewModel.currentStep),
           onboardingProgressExcludedSteps.contains(current),
           current != .videoIntroduction {
            progress = min(1.0, progress + (0.35 / Double(path.count)))
        }

        return min(1.0, progress)
    }

    return 0
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

/// Nombre d'étapes du questionnaire (barre complète avant le scan facial).
func calculateTotalOnboardingStepsForFlow(
    viewModel: OnboardingViewModel,
    navigationEngine: OnboardingNavigationEngine
) -> Int {
    max(buildOnboardingProgressFlowPath(viewModel: viewModel, navigationEngine: navigationEngine).count, 1)
}
