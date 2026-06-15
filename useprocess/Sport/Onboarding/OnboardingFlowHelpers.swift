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
    case .idealWeight, .weightMotivation, .goalPace, .weightEstimation,
         .weightManagementExperience, .weightFailureReasons:
        return viewModel.hasWeightObjective

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
func buildOnboardingProgressFlowPath(navigationEngine: OnboardingNavigationEngine) -> [Int] {
    var result: [Int] = []
    for stepValue in navigationEngine.buildActiveFlowPath() {
        guard let step = OnboardingStep(rawValue: stepValue) else { continue }
        if step == .faceAnalysis { break }
        if step.isTransientSkippedStep { continue }
        if onboardingProgressExcludedSteps.contains(step) { continue }
        result.append(stepValue)
    }
    return result
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

/// Clé pour recalculer la progression sans appeler `buildActiveFlowPath` à chaque frame SwiftUI.
func onboardingFlowProgressCacheKey(viewModel: OnboardingViewModel) -> String {
    let weightGoalFlag = viewModel.hasWeightGoal.map { $0 ? "1" : "0" } ?? "n"
    let inferredGoal = viewModel.selectedWeightGoal?.rawValue ?? ""
    let sport = viewModel.hasSportActivity.map { $0 ? "1" : "0" } ?? "n"
    return "\(viewModel.currentStep)|\(weightGoalFlag)|\(inferredGoal)|\(sport)|\(viewModel.isIdealWeightEntered)"
}

/// Progression normalisée 0…1 — complète à 100 % sur la dernière étape questionnaire (nutrition).
func onboardingFlowProgress(
    viewModel: OnboardingViewModel,
    navigationEngine: OnboardingNavigationEngine
) -> Double {
    let path = buildOnboardingProgressFlowPath(navigationEngine: navigationEngine)
    guard !path.isEmpty else { return 0 }

    if let current = OnboardingStep(rawValue: viewModel.currentStep),
       isPostFaceScanOnboardingPhase(current) {
        return 1.0
    }

    if let index = path.firstIndex(of: viewModel.currentStep) {
        return min(1.0, Double(index + 1) / Double(path.count))
    }

    let visitedInPath = path.filter { viewModel.visitedSteps.contains($0) }.count
    return min(1.0, Double(visitedInPath) / Double(path.count))
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
    max(buildOnboardingProgressFlowPath(navigationEngine: navigationEngine).count, 1)
}
