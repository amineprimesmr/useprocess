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
        defer {
            stepForNavigation = nil
        }

        var path: [Int] = []
        var step = OnboardingStep.genderSelection.rawValue
        var visitCounts: [Int: Int] = [:]

        for _ in 0..<100 {
            let visits = visitCounts[step, default: 0]
            guard visits == 0 else { break }

            visitCounts[step, default: 0] += 1
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
            if !isSimulatingNavigation {
                viewModel.refreshBodyCompositionRouting()
            }
            return OnboardingStep.firstNameInput.rawValue
        case .heightWeight:
            return OnboardingStep.firstNameInput.rawValue
        case .firstNameInput:
            return OnboardingStep.faceLeverageIntro.rawValue
        case .faceLeverageIntro, .personalizedWelcome:
            return OnboardingStep.weightMotivation.rawValue
        case .processResultsDurability:
            return OnboardingStep.weightMotivation.rawValue
        case .primaryGoal, .idealWeight, .weightGoalIncompatible:
            return OnboardingStep.firstNameInput.rawValue
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
    
    // MARK: - Specific Flow (Objectifs)
    
    private func buildPendingStepsQueue() -> [OnboardingStep] {
        [.hasSportActivity]
    }
    
    private func getNextStepInSpecificFlow(from current: OnboardingStep) -> Int? {
        switch current {
        case .weightGoal:
            return getNextStepInQueue(after: .weightGoal) ?? OnboardingStep.hasSportActivity.rawValue
            
        case .weightGoalIncompatible, .idealWeight:
            return OnboardingStep.firstNameInput.rawValue
            
        case .weightMotivation:
            return OnboardingStep.dashboardPreview.rawValue

        case .programCreation, .notificationPermission:
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
        case .referralCode:
            return OnboardingStep.dreamFaceCommit.rawValue

        case .appRating:
            return OnboardingStep.biometricAuth.rawValue
            
        case .caloriesGoal:
            return OnboardingStep.biometricAuth.rawValue
            
        case .carryOverCalories:
            return OnboardingStep.biometricAuth.rawValue
            
        case .biometricAuth:
            return OnboardingStep.transformationPreview.rawValue

        case .transformationPreview:
            return OnboardingConstants.showsReferralCodeStepInOnboarding
                ? OnboardingStep.referralCode.rawValue
                : OnboardingStep.dreamFaceCommit.rawValue

        case .dashboardPreview:
            return OnboardingStep.programCreation.rawValue

        case .dreamFaceCommit:
            return OnboardingStep.payment.rawValue

        case .payment:
            return OnboardingStep.appleSignIn.rawValue

        case .appleSignIn:
            // Étape terminale post-paiement — fin du parcours onboarding.
            return nil

        case .processWelcome, .referralReward, .featuresUnlock, .complete:
            return nil
            
        default:
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
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
}
