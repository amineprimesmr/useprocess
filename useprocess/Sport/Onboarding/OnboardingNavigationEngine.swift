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
            return OnboardingStep.idealWeight.rawValue
        case .heightWeight:
            return OnboardingStep.firstNameInput.rawValue
        case .firstNameInput:
            return OnboardingStep.weightMotivation.rawValue
        case .personalizedWelcome, .processResultsDurability:
            return OnboardingStep.idealWeight.rawValue
        case .primaryGoal:
            if viewModel.hasWeightGoal == true {
                return OnboardingStep.idealWeight.rawValue
            }
            if viewModel.hasWeightGoal == false {
                return OnboardingStep.weightEstimation.rawValue
            }
            return OnboardingStep.idealWeight.rawValue
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
        
        // Fallback de compatibilité pour anciennes étapes non routées explicitement.
        let orderedSteps = OnboardingStep.semanticOrder
            .map(\.rawValue)
        guard let currentIndex = orderedSteps.firstIndex(of: resolvedCurrentStep) else {
            return nil
        }
        let nextIndex = currentIndex + 1
        return nextIndex < orderedSteps.count ? orderedSteps[nextIndex] : nil
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
        case .idealWeight:
            return OnboardingStep.weight.rawValue
        case .heightWeight:
            return OnboardingStep.ageSelection.rawValue
        case .firstNameInput:
            return OnboardingStep.idealWeight.rawValue
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
        
        // Fallback de compatibilité pour rawValues non linéaires.
        let orderedSteps = OnboardingStep.semanticOrder
            .map(\.rawValue)
        guard let currentIndex = orderedSteps.firstIndex(of: viewModel.currentStep),
              currentIndex > 0 else {
            return OnboardingStep.videoIntroduction.rawValue
        }
        return orderedSteps[currentIndex - 1]
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
            return OnboardingStep.firstNameInput.rawValue
            
        case .weightMotivation:
            return OnboardingStep.programCreation.rawValue

        case .programCreation:
            return OnboardingStep.weightEstimation.rawValue
            
        case .weightEstimation:
            return OnboardingStep.biometricAuth.rawValue
            
        case .goalProjection:
            return OnboardingStep.biometricAuth.rawValue
            
        case .hasSportActivity, .sportSelection:
            return OnboardingStep.biometricAuth.rawValue
            
        case .sportClub, .experienceLevel, .yearsOfExperience, .trainingFrequency, .deadlineSelection, .potentialPace:
            return OnboardingStep.biometricAuth.rawValue
            
        case .weightManagementExperience, .weightFailureReasons, .nutritionQuality:
            return OnboardingStep.biometricAuth.rawValue
            
        default:
            return nil
        }
    }
    
    private func getNextStepInNutritionFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .weightManagementExperience:
            if let experience = viewModel.nutritionProfile.weightManagementExperience,
               (experience == .triedMultiple || experience == .currentlyTrying) {
                return OnboardingStep.weightFailureReasons.rawValue
            }
            return OnboardingStep.nutritionQuality.rawValue
            
        case .weightFailureReasons:
            return OnboardingStep.nutritionQuality.rawValue
            
        case .nutritionQuality:
            return OnboardingStep.biometricAuth.rawValue

        case .hasDietaryRestrictions, .whichRestrictions:
            return OnboardingStep.biometricAuth.rawValue

        case .hardestMeal:
            return OnboardingStep.biometricAuth.rawValue

        case .faceAnalysis:
            return OnboardingStep.biometricAuth.rawValue

        case .programCreation:
            return OnboardingStep.weightEstimation.rawValue

        case .nutritionPotential,
             .nutritionObstacles, .perfectNutritionBelief, .hasSufficientHydration, .hydrationLevel,
             .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks, .sleepNeed, .planGeneration:
            return OnboardingStep.biometricAuth.rawValue
            
        default:
            return nil
        }
    }
    
    private func getNextStepInSleepFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .appleSignIn:
            return OnboardingStep.biometricAuth.rawValue

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
            return OnboardingStep.biometricAuth.rawValue
            
        case .carryOverCalories:
            return OnboardingStep.biometricAuth.rawValue
            
        case .biometricAuth:
            return OnboardingStep.notificationPermission.rawValue
            
        case .notificationPermission:
            return OnboardingStep.transformationPreview.rawValue

        case .transformationPreview:
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
            return OnboardingStep.weight.rawValue
            
        case .weightMotivation:
            return OnboardingStep.firstNameInput.rawValue
            
        case .goalPace, .hasSportActivity, .sportSelection,
             .weightManagementExperience, .weightFailureReasons, .nutritionQuality:
            return OnboardingStep.weightMotivation.rawValue
            
        case .weightEstimation:
            return OnboardingStep.programCreation.rawValue
            
        case .programCreation:
            return OnboardingStep.weightMotivation.rawValue
            
        case .sportClub, .experienceLevel, .yearsOfExperience, .trainingFrequency, .deadlineSelection, .potentialPace, .eventDetails:
            return OnboardingStep.weightEstimation.rawValue
            
        case .goalProjection:
            return OnboardingStep.weightEstimation.rawValue
            
        default:
            return nil
        }
    }
    
    private func getPreviousStepInNutritionFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .nutritionQuality, .weightFailureReasons, .weightManagementExperience:
            return OnboardingStep.weightMotivation.rawValue
            
        case .hasDietaryRestrictions, .whichRestrictions:
            return OnboardingStep.weightEstimation.rawValue

        case .faceAnalysis:
            return OnboardingStep.weightEstimation.rawValue

        case .programCreation:
            return OnboardingStep.weightMotivation.rawValue

        case .biometricAuth:
            return OnboardingStep.weightEstimation.rawValue

        case .nutritionPotential, .hasSufficientHydration, .hydrationLevel,
             .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks, .sleepNeed,
             .planGeneration, .alarmConfiguration, .sleepWindowReveal, .hardestMeal:
            return OnboardingStep.weightEstimation.rawValue

        default:
            return nil
        }
    }
    
    private func getPreviousStepInSleepFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks, .sleepNeed, .planGeneration:
            return OnboardingStep.weightEstimation.rawValue

        case .sleepDataRecovery, .newsStep, .sleepNeedReveal, .sleepDebtInfo:
            return OnboardingStep.weightEstimation.rawValue

        case .healthKitPermissions:
            return OnboardingStep.weightEstimation.rawValue

        case .appleSignIn:
            return OnboardingStep.weightEstimation.rawValue

        case .alarmConfiguration, .sleepWindowReveal:
            return OnboardingStep.weightEstimation.rawValue

        default:
            return nil
        }
    }
    
    private func getPreviousStepInFinalizationFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .referralCode:
            return OnboardingStep.weightEstimation.rawValue

        case .sleepWindowReveal, .alarmConfiguration:
            return OnboardingStep.weightEstimation.rawValue

        case .appRating, .caloriesGoal, .carryOverCalories:
            return OnboardingStep.weightEstimation.rawValue

        case .biometricAuth:
            return OnboardingStep.weightEstimation.rawValue
            
        case .notificationPermission:
            return OnboardingStep.biometricAuth.rawValue

        case .transformationPreview:
            return OnboardingStep.notificationPermission.rawValue

        case .payment:
            return OnboardingStep.transformationPreview.rawValue
            
        case .processWelcome, .referralReward, .featuresUnlock, .complete:
            return OnboardingStep.payment.rawValue
            
        default:
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDeadlineOrTrainingFrequency() -> Int {
        OnboardingStep.weightEstimation.rawValue
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
