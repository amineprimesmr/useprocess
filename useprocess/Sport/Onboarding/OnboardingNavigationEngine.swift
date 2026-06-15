//
//  OnboardingNavigationEngine.swift
//  Process
//
//  Engine de navigation propre et maintenable pour remplacer la logique fragile
//

import Foundation

@MainActor
class OnboardingNavigationEngine {
    let viewModel: OnboardingViewModel
    let profileService: UnifiedProfileService

    /// Étape simulée pour `buildActiveFlowPath` sans toucher au `currentStep` publié.
    private var stepForNavigation: Int?

    private var resolvedCurrentStep: Int {
        stepForNavigation ?? viewModel.currentStep
    }

    /// `true` pendant `buildActiveFlowPath()` — ne pas écrire dans le ViewModel (@Published).
    private var isSimulatingNavigation: Bool {
        stepForNavigation != nil
    }

    /// File d'étapes objectifs : lecture seule en simulation, sinon cache ViewModel.
    private func pendingStepsQueue() -> [OnboardingStep] {
        if isSimulatingNavigation {
            return buildPendingStepsQueue()
        }
        if viewModel.pendingSpecificSteps.isEmpty {
            return buildPendingStepsQueue()
        }
        return viewModel.pendingSpecificSteps
    }

    init(viewModel: OnboardingViewModel, profileService: UnifiedProfileService) {
        self.viewModel = viewModel
        self.profileService = profileService
    }

    /// Parcours linéaire attendu (étapes affichées) selon l'état actuel du ViewModel — pour la barre de progression.
    func buildActiveFlowPath() -> [Int] {
        defer { stepForNavigation = nil }

        var path: [Int] = []
        var step = OnboardingStep.videoIntroduction.rawValue
        var visited = Set<Int>()

        for _ in 0..<100 {
            guard visited.insert(step).inserted else { break }
            path.append(step)
            stepForNavigation = step
            guard let next = getNextStep() else { break }
            step = next
        }

        return path
    }

    /// Prochaine étape simulée depuis une étape arbitraire (parcours / saut des étapes transitoires).
    func nextStep(after step: Int) -> Int? {
        stepForNavigation = step
        defer { stepForNavigation = nil }
        return getNextStep()
    }

    /// Première étape visible après `step`, en enchaînant les étapes transitoires.
    func resolveNextVisibleStep(from step: Int, maxHops: Int = 40) -> Int? {
        var cursor = step
        for _ in 0..<maxHops {
            guard let rawNext = nextStep(after: cursor) else { return nil }
            cursor = rawNext
            if let nextStep = OnboardingStep(rawValue: rawNext), !nextStep.isTransientSkippedStep {
                return rawNext
            }
        }
        return nil
    }

    // MARK: - Next Step
    
    func getNextStep() -> Int? {
        guard let current = OnboardingStep(rawValue: resolvedCurrentStep) else {
            return nil
        }
        
        // Flow initial
        switch current {
        case .videoIntroduction:
            return OnboardingStep.genderSelection.rawValue
        case .genderSelection:
            return OnboardingStep.ageSelection.rawValue
        case .ageSelection:
            return OnboardingStep.height.rawValue
        case .height:
            return OnboardingStep.weight.rawValue
        case .weight, .bodyScan:
            return OnboardingStep.firstNameInput.rawValue
        case .heightWeight:
            return OnboardingStep.firstNameInput.rawValue
        case .firstNameInput:
            return OnboardingStep.primaryGoal.rawValue
        case .personalizedWelcome, .processResultsDurability:
            return OnboardingStep.primaryGoal.rawValue
        case .primaryGoal:
            if viewModel.hasWeightGoal == true {
                return OnboardingStep.idealWeight.rawValue
            }
            return OnboardingStep.weightEstimation.rawValue
        default:
            break
        }
        
        // Flow objectifs spécifiques
        if let next = getNextStepInSpecificFlow(from: current) {
            return next
        }
        
        // Flow nutrition
        if let next = getNextStepInNutritionFlow(from: current) {
            return next
        }
        
        // Flow sommeil
        if let next = getNextStepInSleepFlow(from: current) {
            return next
        }
        
        // Flow finalisation
        if let next = getNextStepInFinalizationFlow(from: current) {
            return next
        }
        
        // Fallback : étape suivante
        let nextIndex = resolvedCurrentStep + 1
        return nextIndex < 53 ? nextIndex : nil  // ✅ Corrigé : 53 étapes totales
    }
    
    // MARK: - Previous Step
    
    func getPreviousStep() -> Int? {
        guard let current = OnboardingStep(rawValue: viewModel.currentStep) else {
            return nil
        }
        
        // Flow initial inversé
        switch current {
        case .genderSelection:
            return OnboardingStep.videoIntroduction.rawValue
        case .ageSelection:
            return OnboardingStep.genderSelection.rawValue
        case .height:
            return OnboardingStep.ageSelection.rawValue
        case .weight:
            return OnboardingStep.height.rawValue
        case .heightWeight:
            return OnboardingStep.ageSelection.rawValue
        case .firstNameInput:
            return OnboardingStep.weight.rawValue
        case .bodyScan:
            return OnboardingStep.weight.rawValue
        case .personalizedWelcome, .processResultsDurability:
            return OnboardingStep.firstNameInput.rawValue
        case .primaryGoal:
            return OnboardingStep.firstNameInput.rawValue
        default:
            break
        }
        
        // Flow objectifs spécifiques inversé
        if let previous = getPreviousStepInSpecificFlow(from: current) {
            return previous
        }
        
        // Flow nutrition inversé
        if let previous = getPreviousStepInNutritionFlow(from: current) {
            return previous
        }
        
        // Flow sommeil inversé
        if let previous = getPreviousStepInSleepFlow(from: current) {
            return previous
        }
        
        // Flow finalisation inversé
        if let previous = getPreviousStepInFinalizationFlow(from: current) {
            return previous
        }
        
        // Fallback : étape précédente
        return max(0, viewModel.currentStep - 1)
    }
    
    // MARK: - Specific Flow (Objectifs)
    
    private func buildPendingStepsQueue() -> [OnboardingStep] {
        [.hasSportActivity]
    }
    
    private func getNextStepInSpecificFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .weightGoal:
            return getNextStepInQueue(after: .weightGoal) ?? OnboardingStep.hasSportActivity.rawValue
            
        case .weightGoalIncompatible:
            return OnboardingStep.idealWeight.rawValue
            
        case .idealWeight:
            if isSimulatingNavigation {
                if wouldWeightGoalBeIncompatibleWithBMI() {
                    return OnboardingStep.weightGoalIncompatible.rawValue
                }
            } else {
                viewModel.syncInferredWeightGoal()
                if viewModel.isWeightGoalIncompatibleWithBMI() {
                    return OnboardingStep.weightGoalIncompatible.rawValue
                }
            }
            return OnboardingStep.weightMotivation.rawValue
            
        case .weightMotivation:
            return OnboardingStep.goalPace.rawValue
            
        case .goalPace:
            return OnboardingStep.weightEstimation.rawValue
            
        case .weightEstimation:
            // ✅ CORRECTION: Après weightEstimation, aller aux questions sportives (hasSportActivity)
            // Même si l'objectif est uniquement "changer mon poids", on doit poser les questions sportives
            return OnboardingStep.hasSportActivity.rawValue
            
        case .hasSportActivity:
            // Si l'utilisateur pratique un sport, aller à sportSelection
            if viewModel.hasSportActivity == true {
                return OnboardingStep.sportSelection.rawValue
            } else {
                // ✅ NOUVELLE LOGIQUE: Si l'utilisateur ne pratique pas de sport
                // - Si l'utilisateur a choisi "changer mon poids" → aller à weightManagementExperience
                // - Sinon → aller directement à nutritionQuality
                if viewModel.hasWeightObjective {
                    return OnboardingStep.weightManagementExperience.rawValue
                } else {
                    return OnboardingStep.goalProjection.rawValue
                }
            }
            
        case .sportSelection:
            return OnboardingStep.goalProjection.rawValue
            
        case .sportClub, .experienceLevel, .yearsOfExperience, .trainingFrequency, .deadlineSelection, .potentialPace:
            return OnboardingStep.goalProjection.rawValue
            
        case .goalProjection:
            if viewModel.hasWeightObjective {
                return OnboardingStep.weightManagementExperience.rawValue
            }
            return OnboardingStep.nutritionQuality.rawValue
            
        default:
            return nil
        }
    }
    
    private func getNextStepInNutritionFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .weightManagementExperience:
            // ✅ NOUVELLE LOGIQUE: Si l'utilisateur a répondu "J'ai essayé plusieurs fois" ou "J'essaie actuellement"
            // Aller à weightFailureReasons, sinon aller directement à nutritionQuality
            if let experience = viewModel.nutritionProfile.weightManagementExperience,
               (experience == .triedMultiple || experience == .currentlyTrying) {
                return OnboardingStep.weightFailureReasons.rawValue
            }
            return OnboardingStep.nutritionQuality.rawValue
            
        case .weightFailureReasons:
            // ✅ Après weightFailureReasons, aller à nutritionQuality
            return OnboardingStep.nutritionQuality.rawValue
            
        case .nutritionQuality:
            return OnboardingStep.faceAnalysis.rawValue

        case .hasDietaryRestrictions, .whichRestrictions:
            return OnboardingStep.faceAnalysis.rawValue

        case .hardestMeal:
            return OnboardingStep.faceAnalysis.rawValue

        case .faceAnalysis:
            return OnboardingStep.programCreation.rawValue

        case .programCreation:
            return OnboardingStep.healthKitPermissions.rawValue

        case .nutritionPotential,
             .nutritionObstacles, .perfectNutritionBelief, .hasSufficientHydration, .hydrationLevel,
             .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks, .sleepNeed, .planGeneration:
            return OnboardingStep.healthKitPermissions.rawValue
            
        default:
            return nil
        }
    }
    
    private func getNextStepInSleepFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .appleSignIn:
            return OnboardingStep.healthKitPermissions.rawValue

        case .healthKitPermissions:
            return OnboardingStep.biometricAuth.rawValue

        case .sleepDataRecovery, .newsStep, .sleepNeedReveal, .sleepDebtInfo:
            return OnboardingStep.biometricAuth.rawValue

        case .alarmConfiguration, .sleepWindowReveal:
            return OnboardingStep.biometricAuth.rawValue

        default:
            return nil
        }
    }
    
    private func getNextStepInFinalizationFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .appleSignIn:
            return OnboardingStep.biometricAuth.rawValue
            
        case .referralCode:
            return OnboardingStep.biometricAuth.rawValue
            
        case .appRating:
            return OnboardingStep.biometricAuth.rawValue
            
        case .caloriesGoal:
            // ✅ TEMPORAIRE : Page désactivée, ne devrait pas être atteinte
            return OnboardingStep.biometricAuth.rawValue
            
        case .carryOverCalories:
            // ✅ TEMPORAIRE : Page désactivée, ne devrait pas être atteinte
            return OnboardingStep.biometricAuth.rawValue
            
        case .biometricAuth:
            return OnboardingStep.notificationPermission.rawValue
            
        case .notificationPermission:
            return OnboardingStep.payment.rawValue

        case .payment:
            return nil

        case .processWelcome, .referralReward, .featuresUnlock, .complete:
            return nil
            
        default:
            return nil
        }
    }
    
    // MARK: - Previous Steps (Inverse)
    
    private func getPreviousStepInSpecificFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .weightGoalIncompatible:
            return OnboardingStep.idealWeight.rawValue
            
        case .idealWeight:
            return OnboardingStep.primaryGoal.rawValue
            
        case .weightMotivation:
            return OnboardingStep.idealWeight.rawValue
            
        case .goalPace:
            if viewModel.hasWeightObjective,
               viewModel.selectedWeightGoal != nil,
               viewModel.isIdealWeightEntered {
                return OnboardingStep.weightMotivation.rawValue
            }
            if viewModel.hasWeightObjective {
                return OnboardingStep.idealWeight.rawValue
            }
            return OnboardingStep.trainingFrequency.rawValue
            
        case .weightEstimation:
            if viewModel.hasWeightObjective && viewModel.isIdealWeightEntered {
                return OnboardingStep.goalPace.rawValue
            }
            return OnboardingStep.primaryGoal.rawValue
            
        case .hasSportActivity:
            return OnboardingStep.weightEstimation.rawValue
            
        case .sportSelection:
            return OnboardingStep.hasSportActivity.rawValue
            
        case .sportClub, .experienceLevel, .yearsOfExperience, .trainingFrequency, .deadlineSelection, .potentialPace, .eventDetails:
            if viewModel.hasSportActivity == true {
                return OnboardingStep.sportSelection.rawValue
            }
            return OnboardingStep.hasSportActivity.rawValue
            
        case .goalProjection:
            if viewModel.hasSportActivity == true {
                return OnboardingStep.sportSelection.rawValue
            }
            return OnboardingStep.hasSportActivity.rawValue
            
        case .weightManagementExperience:
            // ✅ NOUVELLE LOGIQUE: Si l'utilisateur est arrivé depuis hasSportActivity (pas de sport + objectif poids)
            // Revenir à hasSportActivity, sinon revenir à goalProjection
            if viewModel.hasSportActivity == false && viewModel.hasWeightObjective {
                return OnboardingStep.hasSportActivity.rawValue
            }
            return OnboardingStep.goalProjection.rawValue
            
        default:
            return nil
        }
    }
    
    private func getPreviousStepInNutritionFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .nutritionQuality:
            // ✅ NOUVELLE LOGIQUE: Si l'utilisateur est arrivé depuis hasSportActivity (pas de sport + pas d'objectif poids)
            // Revenir à hasSportActivity, sinon revenir à weightFailureReasons ou goalProjection
            if viewModel.hasSportActivity == false && !viewModel.hasWeightObjective {
                return OnboardingStep.goalProjection.rawValue
            }
            // Si on vient de weightFailureReasons, revenir à weightFailureReasons
            if let experience = viewModel.nutritionProfile.weightManagementExperience,
               (experience == .triedMultiple || experience == .currentlyTrying) {
                return OnboardingStep.weightFailureReasons.rawValue
            }
            return OnboardingStep.goalProjection.rawValue
            
        case .weightFailureReasons:
            // ✅ Revenir à weightManagementExperience depuis weightFailureReasons
            return OnboardingStep.weightManagementExperience.rawValue
            
        case .hasDietaryRestrictions, .whichRestrictions:
            return OnboardingStep.nutritionQuality.rawValue

        case .faceAnalysis:
            return OnboardingStep.nutritionQuality.rawValue

        case .programCreation:
            return OnboardingStep.faceAnalysis.rawValue

        case .nutritionPotential, .hasSufficientHydration, .hydrationLevel,
             .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks, .sleepNeed,
             .planGeneration, .alarmConfiguration, .sleepWindowReveal, .hardestMeal:
            return OnboardingStep.nutritionQuality.rawValue

        default:
            return nil
        }
    }
    
    private func getPreviousStepInSleepFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks, .sleepNeed, .planGeneration:
            return OnboardingStep.nutritionQuality.rawValue

        case .sleepDataRecovery, .newsStep, .sleepNeedReveal, .sleepDebtInfo:
            return OnboardingStep.healthKitPermissions.rawValue

        case .healthKitPermissions:
            return OnboardingStep.programCreation.rawValue

        case .appleSignIn:
            return OnboardingStep.faceAnalysis.rawValue

        case .alarmConfiguration, .sleepWindowReveal:
            return OnboardingStep.healthKitPermissions.rawValue

        default:
            return nil
        }
    }
    
    private func getPreviousStepInFinalizationFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .referralCode:
            return OnboardingStep.healthKitPermissions.rawValue

        case .sleepWindowReveal, .alarmConfiguration:
            return OnboardingStep.healthKitPermissions.rawValue

        case .appRating, .caloriesGoal, .carryOverCalories:
            return OnboardingStep.healthKitPermissions.rawValue

        case .biometricAuth:
            return OnboardingStep.healthKitPermissions.rawValue
            
        case .notificationPermission:
            return OnboardingStep.biometricAuth.rawValue

        case .payment:
            return OnboardingStep.notificationPermission.rawValue
            
        case .processWelcome, .referralReward, .featuresUnlock, .complete:
            return OnboardingStep.payment.rawValue
            
        default:
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDeadlineOrTrainingFrequency() -> Int {
        OnboardingStep.goalProjection.rawValue
    }
    
    private func getNextStepInQueue(after step: OnboardingStep) -> Int? {
        let queue = pendingStepsQueue()
        guard let stepIndex = queue.firstIndex(of: step) else {
            return nil
        }

        let nextIndex = stepIndex + 1
        if nextIndex < queue.count {
            return queue[nextIndex].rawValue
        }

        return nil
    }
    
    private func getPreviousStepInQueue(from step: OnboardingStep) -> Int? {
        let queue = pendingStepsQueue()
        guard let stepIndex = queue.firstIndex(of: step),
              stepIndex > 0 else {
            return nil
        }

        return queue[stepIndex - 1].rawValue
    }
    
    private func getLastSpecificStepInQueue() -> Int {
        if viewModel.hasWeightObjective {
            if viewModel.isIdealWeightEntered {
                return OnboardingStep.idealWeight.rawValue
            }
        }

        return pendingStepsQueue().last?.rawValue ?? OnboardingStep.primaryGoal.rawValue
    }

    /// Lecture seule — utilisé pendant `buildActiveFlowPath` sans muter le ViewModel.
    private func wouldWeightGoalBeIncompatibleWithBMI() -> Bool {
        guard viewModel.hasWeightGoal == true, viewModel.isIdealWeightEntered else { return false }

        let goal: WeightGoal?
        if viewModel.idealWeightValue < viewModel.selectedWeight {
            goal = .lose
        } else if viewModel.idealWeightValue > viewModel.selectedWeight {
            goal = .gain
        } else {
            goal = nil
        }
        guard let goal else { return false }

        let heightInMeters = viewModel.selectedHeight / 100.0
        guard heightInMeters > 0 else { return false }

        let currentBMI = viewModel.selectedWeight / (heightInMeters * heightInMeters)
        return (currentBMI >= 25.0 && goal == .gain) || (currentBMI < 18.5 && goal == .lose)
    }
}
