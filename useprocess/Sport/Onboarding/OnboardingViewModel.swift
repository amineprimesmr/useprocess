//
//  OnboardingViewModel.swift
//  Process
//
//  ViewModel unifié pour remplacer tous les @State dispersés dans OnboardingView
//

import SwiftUI
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    // MARK: - Progression
    @Published var currentStep: Int = 0
    @Published var visitedSteps: [Int] = [] // Historique des étapes visitées pour navigation retour
    @Published var isCompleting: Bool = false
    @Published var isLoading: Bool = false
    @Published var isRequestingHealthKit: Bool = false
    @Published var healthKitGranted: Bool = false
    @Published var errorMessage: String? = nil
    
    // MARK: - Informations personnelles
    @Published var selectedGender: Gender? = nil
    @Published var selectedAge: Int = 21
    @Published var selectedHeight: Double = 170 // cm — défaut 1m70
    @Published var selectedWeight: Double = 0 // kg — 0 = pas encore saisi
    @Published var firstName: String = ""
    @Published var idealWeightValue: Double = 0
    
    // MARK: - Objectifs
    @Published var hasWeightGoal: Bool? = nil
    @Published var selectedPrimaryGoals: Set<PrimaryGoal> = []
    @Published var selectedWeightGoal: WeightGoal? = nil
    @Published var goalDeadline: GoalDeadline = GoalDeadline()
    @Published var selectedGoalPace: GoalPace? = nil
    
    // MARK: - Sport et expérience
    @Published var hasSportActivity: Bool? = nil  // ✨ Pratiques-tu une activité sportive ?
    @Published var isInClub: Bool? = nil  // ✨ Fais-tu du sport en club ?
    @Published var selectedExperienceLevel: ExperienceLevel? = nil
    @Published var selectedYearsOfExperience: Int = 0
    @Published var selectedTrainingFrequency: String? = nil
    @Published var selectedSessionsPerWeek: Int = 3
    @Published var selectedSessionDuration: Int = 60
    @Published var selectedTrainingLocation: TrainingLocation = .mixed
    @Published var selectedEquipment: Set<PlanEquipment> = []
    
    // MARK: - Nutrition
    @Published var nutritionProfile = NutritionProfile()
    @Published var hasDietaryRestrictions: Bool? = nil
    @Published var otherDietaryRestriction: String = ""
    
    // MARK: - Navigation
    @Published var pendingSpecificSteps: [OnboardingStep] = []
    @Published var hasDoneFirstGoalPace: Bool = false
    
    // MARK: - États de validation
    @Published var isGenderSelected: Bool = false
    @Published var isAgeSelected: Bool = false
    @Published var isHeightWeightSelected: Bool = false
    @Published var isFirstNameEntered: Bool = false
    @Published var isPrimaryGoalSelected: Bool = false // Conservé compat — reflète hasWeightGoal != nil
    @Published var isWeightGoalSelected: Bool = false
    @Published var isIdealWeightEntered: Bool = false
    @Published var isSportsSelected: Bool = false
    @Published var isExperienceLevelSelected: Bool = false
    @Published var isTrainingFrequencySelected: Bool = false
    @Published var isDeadlineSelected: Bool = false
    @Published var isGoalPaceSelected: Bool = false
    @Published var isWeightEstimationCompleted: Bool = false
    @Published var isGoalProjectionCompleted: Bool = false
    @Published var isNutritionQualitySelected: Bool = false
    @Published var isHasDietaryRestrictionsSelected: Bool = false
    @Published var isWhichRestrictionsSelected: Bool = false
    @Published var isNutritionObstaclesSelected: Bool = false
    @Published var isWeightManagementExperienceSelected: Bool = false
    @Published var isHardestMealSelected: Bool = false
    @Published var isHasSufficientHydrationSelected: Bool = false
    @Published var isHydrationLevelSelected: Bool = false
    @Published var isSleepQualitySelected: Bool = false
    @Published var isFatigueFrequencySelected: Bool = false
    @Published var isFatiguePeaksSelected: Bool = false
    @Published var isPersonalizedWelcomeCompleted: Bool = false
    @Published var isFaceLeverageIntroCompleted: Bool = false
    @Published var isWeightMotivationCompleted: Bool = false
    @Published var isFaceAnalysisCompleted: Bool = false
    @Published var onboardingFaceMarkers: FaceWellnessMarkers?
    @Published var onboardingFaceMesh: FaceMesh3DData?
    @Published var isProgramCreationCompleted: Bool = false
    
    // MARK: - Sleep Profile (migré complètement vers ViewModel)
    @Published var sleepProfile = SleepProfile()
    
    // MARK: - Referral
    @Published var referralCode: String? = nil // Code de parrainage utilisé à l'inscription
    @Published var completedProfileChatQuestionIDs: Set<String> = []
    @Published var onboardingPrimaryFocus: OnboardingPrimaryFocus?
    @Published var onboardingDebloatDrivers: Set<OnboardingDebloatDriver> = []
    @Published var onboardingRoutineChallenges: Set<OnboardingRoutineChallenge> = []
    
    // MARK: - Initialization
    
    init() {
        // Charger la progression sauvegardée
        let savedStep = OnboardingProgressService.shared.loadCurrentStep()
        
        // ✅ CORRECTION: Charger l'historique complet des étapes visitées depuis UserDefaults
        let savedVisitedSteps = OnboardingProgressService.shared.loadVisitedSteps()

        if let cached = OnboardingProgressService.shared.loadAnswers() {
            applyCachedAnswers(cached)
        }
        
        if savedStep > 0, let saved = OnboardingStep(rawValue: savedStep) {
            let resumeStep = saved.unpaidResumeStep.rawValue
            currentStep = resumeStep

            if !savedVisitedSteps.isEmpty {
                visitedSteps = normalizeOnboardingVisitedStack(
                    visitedSteps: savedVisitedSteps,
                    currentStep: resumeStep
                )
            } else {
                visitedSteps = [resumeStep]
            }
        } else {
            currentStep = OnboardingStep.genderSelection.rawValue
            if !savedVisitedSteps.isEmpty {
                visitedSteps = savedVisitedSteps.filter {
                    guard let step = OnboardingStep(rawValue: $0) else { return false }
                    return !step.isTransientSkippedStep
                }
                if visitedSteps.isEmpty {
                    visitedSteps = [OnboardingStep.genderSelection.rawValue]
                }
            } else {
                visitedSteps = [OnboardingStep.genderSelection.rawValue]
            }
        }

        let shouldRestoreFaceScan = isFaceAnalysisCompleted
            || hasReachedFaceScanStep(
                savedStep: OnboardingProgressService.shared.loadCurrentStep(),
                visited: OnboardingProgressService.shared.loadVisitedSteps()
            )
        if let payload = OnboardingFaceMarkersStore.loadPayload(),
           shouldRestoreFaceScan {
            onboardingFaceMarkers = payload.markers
            onboardingFaceMesh = payload.mesh.isValid ? payload.mesh : nil
            isFaceAnalysisCompleted = true
        } else if let markers = OnboardingFaceMarkersStore.load(),
                  shouldRestoreFaceScan {
            onboardingFaceMarkers = markers
            onboardingFaceMesh = OnboardingFaceMarkersStore.loadMesh()
            isFaceAnalysisCompleted = true
        } else {
            isFaceAnalysisCompleted = false
        }

        if hasWeightGoal == nil, selectedPrimaryGoals.contains(.manageWeight) {
            hasWeightGoal = true
        }
        
        // ✅ La synchronisation avec le profil se fait dans OnboardingView.onAppear et onChange
        // car le profil n'est pas encore chargé à ce stade
    }
    
    // MARK: - Synchronization
    
    /// Synchronise le ViewModel avec le profil existant sans écraser les réponses déjà saisies.
    func syncWithExistingProfile(_ profile: UnifiedUserProfile?) {
        guard let profile = profile else { return }

        if Self.isRealUserFirstName(profile.firstName),
           firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !Self.isRealUserFirstName(firstName) {
            firstName = profile.firstName
            isFirstNameEntered = true
        }

        if profile.age > 0, profile.age <= 120, !isAgeSelected {
            selectedAge = profile.age
            isAgeSelected = true
        } else if profile.birthDate != Date(timeIntervalSince1970: 0), !isAgeSelected {
            let calendar = Calendar.current
            if let calculatedAge = calendar.dateComponents([.year], from: profile.birthDate, to: Date()).year,
               calculatedAge > 0, calculatedAge <= 120 {
                selectedAge = calculatedAge
                isAgeSelected = true
            }
        }

        if profile.height > 0, selectedHeight <= 0 {
            selectedHeight = profile.height
        }

        if Self.isPlausibleWeight(profile.weight), selectedWeight <= 0 {
            selectedWeight = profile.weight
        }

        if let ideal = profile.idealWeight, Self.isPlausibleWeight(ideal), !isIdealWeightEntered {
            idealWeightValue = ideal
            isIdealWeightEntered = true
        }

        if profile.gender != .preferNotToSay, !isGenderSelected {
            selectedGender = profile.gender
            isGenderSelected = true
        }
    }
    
    // MARK: - Validation
    
    func isCurrentStepValidated() -> Bool {
        switch OnboardingStep(rawValue: currentStep) {
        case .genderSelection:
            return isGenderSelected && selectedGender != nil
        case .ageSelection:
            return isAgeSelected && selectedAge > 0 && selectedAge <= 120
        case .height:
            return selectedHeight > 0
        case .weight:
            return Self.isPlausibleWeight(selectedWeight)
        case .heightWeight:
            return isHeightWeightSelected && selectedHeight > 0 && Self.isPlausibleWeight(selectedWeight)
        case .firstNameInput:
            return isFirstNameEntered && !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case .faceLeverageIntro:
            return isFaceLeverageIntroCompleted
        case .personalizedWelcome:
            return true
        case .bodyScan:
            return true
        case .processResultsDurability, .weightGoalIncompatible:
            return true
        case .weightMotivation:
            return isWeightMotivationCompleted
        case .sportClub, .experienceLevel, .hardestMeal:
            return true
        case .appleSignIn:
            return true
        case .hasSportActivity:
            return hasSportActivity != nil
        case .primaryGoal:
            return hasWeightGoal != nil
        case .weightGoal:
            return true
        case .idealWeight:
            return isIdealWeightEntered
                && Self.isPlausibleWeight(idealWeightValue)
                && abs(idealWeightValue - selectedWeight) >= 0.5
                && Self.isReasonableIdealWeight(
                    idealWeightValue,
                    currentWeight: selectedWeight,
                    height: selectedHeight,
                    gender: selectedGender
                )
        case .sportSelection:
            return isSportsSelected
        case .yearsOfExperience:
            return selectedYearsOfExperience > 0 || selectedYearsOfExperience == -1
        case .deadlineSelection:
            return isDeadlineSelected
        case .goalPace, .potentialPace:
            return isGoalPaceSelected && selectedGoalPace != nil
        case .weightEstimation:
            return isWeightEstimationCompleted
        case .goalProjection:
            return isWeightEstimationCompleted
        case .trainingFrequency:
            return isTrainingFrequencySelected && selectedTrainingFrequency != nil
        case .nutritionQuality:
            // Toujours validée : valeur par défaut + commit explicite au tap Continuer
            return true
        case .nutritionObstacles, .nutritionPotential:
            return true
        case .perfectNutritionBelief:
            return nutritionProfile.hasPerfectNutrition != nil
        case .hasDietaryRestrictions, .whichRestrictions:
            return true
        case .hasSufficientHydration:
            return isHasSufficientHydrationSelected
        case .hydrationLevel:
            return isHydrationLevelSelected
        case .sleepQuality:
            return isSleepQualitySelected
        case .fatigueFrequency:
            return isFatigueFrequencySelected
        case .fatiguePeaks:
            return isFatiguePeaksSelected
        case .sleepNeed:
            // ✅ Page informative, toujours validée
            return true
        case .faceAnalysis:
            return isFaceAnalysisCompleted
        case .programCreation:
            return isProgramCreationCompleted
        case .weightManagementExperience:
            if hasWeightGoal != true {
                return true
            }
            return isWeightManagementExperienceSelected
        default:
            return true
        }
    }
    
    // MARK: - Cross-step Validation
    
    func validateCrossStepConsistency() -> [String] {
        var warnings: [String] = []
        
        // Cohérence expérience
        if let level = selectedExperienceLevel {
            if level == .debutant && selectedYearsOfExperience > 2 {
                warnings.append("Débutant avec \(selectedYearsOfExperience) années d'expérience")
            } else if level == .intermediaire && (selectedYearsOfExperience < 1 || selectedYearsOfExperience > 5) {
                warnings.append("Cohérence à vérifier entre niveau et années d'expérience")
            }
        }
        
        // Cohérence poids idéal
        if let weightGoal = selectedWeightGoal {
            if weightGoal == .lose && idealWeightValue >= selectedWeight {
                warnings.append("Poids idéal supérieur ou égal au poids actuel pour perte de poids")
            } else if weightGoal == .gain && idealWeightValue <= selectedWeight {
                warnings.append("Poids idéal inférieur ou égal au poids actuel pour prise de poids")
            }
        }
        
        return warnings
    }

    // MARK: - Objectif poids (flux simplifié)

    var hasWeightObjective: Bool { hasWeightGoal == true }

    var bodyCompositionAssessment: BodyCompositionAssessment? {
        BodyCompositionAssessment.evaluate(
            weight: selectedWeight,
            height: selectedHeight,
            age: selectedAge,
            gender: selectedGender
        )
    }

    /// Étape « poids de référence / objectif de poids » retirée du parcours — toujours sautée.
    var shouldSkipIdealWeightStep: Bool { true }

    func refreshBodyCompositionRouting() {
        // Défauts debloat une seule fois — évite une tempête de @Published pendant la nav.
        guard hasWeightGoal != false else { return }
        applyFitProfileDebloatDefaults()
    }

    /// Profil déjà fit — pas d'objectif poids, trajectoire debloat visage.
    func applyFitProfileDebloatDefaults() {
        applyHasWeightGoal(false)
        idealWeightValue = selectedWeight
        isIdealWeightEntered = false
        selectedWeightGoal = nil
        isWeightGoalSelected = false
    }

    func applyHasWeightGoal(_ value: Bool) {
        hasWeightGoal = value
        isPrimaryGoalSelected = true

        if value {
            selectedPrimaryGoals.insert(.manageWeight)
        } else {
            selectedPrimaryGoals.remove(.manageWeight)
            selectedWeightGoal = nil
            isWeightGoalSelected = false
            isIdealWeightEntered = false
        }
    }

    func updateNutritionQuality(_ quality: NutritionQuality?) {
        var profile = nutritionProfile
        profile.nutritionQuality = quality
        nutritionProfile = profile
        isNutritionQualitySelected = quality != nil
    }

    /// Persiste les réponses implicites (valeurs par défaut UI) avant navigation.
    func commitPendingStepAnswers() {
        guard let step = OnboardingStep(rawValue: currentStep) else { return }

        switch step {
        case .nutritionQuality:
            if nutritionProfile.nutritionQuality == nil {
                updateNutritionQuality(.average)
            }
        default:
            break
        }
    }

    func syncInferredWeightGoal() {
        guard hasWeightGoal == true, isIdealWeightEntered else { return }

        if idealWeightValue < selectedWeight {
            selectedWeightGoal = .lose
        } else if idealWeightValue > selectedWeight {
            selectedWeightGoal = .gain
        } else {
            selectedWeightGoal = nil
        }
        isWeightGoalSelected = selectedWeightGoal != nil
    }

    private func inferredWeightGoalFromIdealWeight() -> WeightGoal? {
        guard hasWeightGoal == true, isIdealWeightEntered else { return nil }
        if idealWeightValue < selectedWeight { return .lose }
        if idealWeightValue > selectedWeight { return .gain }
        return nil
    }

    func recommendedIdealWeight() -> Double? {
        guard Self.isPlausibleWeight(selectedWeight),
              selectedHeight >= 120,
              selectedHeight <= 230,
              let gender = selectedGender,
              let goal = selectedWeightGoal
                ?? PersonalizedIdealWeightCalculator.inferredWeightGoal(
                    currentWeight: selectedWeight,
                    height: selectedHeight,
                    age: selectedAge,
                    gender: gender
                ) else {
            return nil
        }

        let recommendation = PersonalizedIdealWeightCalculator.calculatePersonalizedIdealWeight(
            currentWeight: selectedWeight,
            height: selectedHeight,
            age: selectedAge,
            gender: gender,
            weightGoal: goal
        )

        guard Self.isPlausibleWeight(recommendation),
              Self.isReasonableIdealWeight(
                recommendation,
                currentWeight: selectedWeight,
                height: selectedHeight,
                gender: gender
              ),
              abs(recommendation - selectedWeight) >= 0.5 else {
            return nil
        }

        return recommendation
    }

    func isWeightGoalIncompatibleWithBMI() -> Bool {
        guard let goal = selectedWeightGoal ?? inferredWeightGoalFromIdealWeight() else { return false }

        let heightInMeters = selectedHeight / 100.0
        guard heightInMeters > 0 else { return false }

        let currentBMI = selectedWeight / (heightInMeters * heightInMeters)
        return (currentBMI >= 25.0 && goal == .gain) || (currentBMI < 18.5 && goal == .lose)
    }
    
    // MARK: - Progress Management
    
    func saveProgress() {
        OnboardingProgressService.shared.saveCurrentStep(persistedResumeStep)
        OnboardingProgressService.shared.saveVisitedSteps(visitedSteps)
        OnboardingProgressService.shared.saveAnswers(makeAnswersSnapshot())
    }

    /// Tant que l’onboarding n’est pas payé, on mémorise le dashboard — pas le paywall.
    private var persistedResumeStep: Int {
        guard !AppSession.shared.hasCompletedOnboarding,
              !SubscriptionService.shared.subscriptionStatus.isActive,
              let step = OnboardingStep(rawValue: currentStep) else {
            return currentStep
        }
        return step.unpaidResumeStep.rawValue
    }

    func saveFlowProgress(_ progress: Double) {
        OnboardingProgressService.shared.saveFlowProgress(progress)
    }
    
    func resetProgress() {
        OnboardingProgressService.shared.resetProgress()
        sleepProfile = SleepProfile()
        currentStep = 0
    }

    func makeAnswersSnapshot() -> OnboardingAnswersSnapshot {
        OnboardingAnswersSnapshot(
            selectedGender: selectedGender,
            selectedAge: selectedAge,
            selectedHeight: selectedHeight,
            selectedWeight: selectedWeight,
            firstName: firstName,
            idealWeightValue: idealWeightValue,
            hasWeightGoal: hasWeightGoal,
            selectedPrimaryGoals: selectedPrimaryGoals.sorted { $0.rawValue < $1.rawValue },
            selectedWeightGoal: selectedWeightGoal,
            goalDeadline: goalDeadline,
            selectedGoalPace: selectedGoalPace,
            hasSportActivity: hasSportActivity,
            isInClub: isInClub,
            selectedExperienceLevel: selectedExperienceLevel,
            selectedYearsOfExperience: selectedYearsOfExperience,
            selectedTrainingFrequency: selectedTrainingFrequency,
            selectedSessionsPerWeek: selectedSessionsPerWeek,
            selectedSessionDuration: selectedSessionDuration,
            selectedTrainingLocation: selectedTrainingLocation,
            selectedEquipment: selectedEquipment.sorted { $0.rawValue < $1.rawValue },
            selectedSports: OnboardingDataModel.shared.selectedSports.sorted(),
            nutritionProfile: nutritionProfile,
            hasDietaryRestrictions: hasDietaryRestrictions,
            otherDietaryRestriction: otherDietaryRestriction,
            sleepProfile: sleepProfile,
            referralCode: referralCode,
            completedProfileChatQuestionIDs: completedProfileChatQuestionIDs.sorted(),
            onboardingPrimaryFocus: onboardingPrimaryFocus,
            onboardingDebloatDrivers: onboardingDebloatDrivers.sorted { $0.rawValue < $1.rawValue },
            onboardingRoutineChallenges: onboardingRoutineChallenges.sorted { $0.rawValue < $1.rawValue },
            isGenderSelected: isGenderSelected,
            isAgeSelected: isAgeSelected,
            isHeightWeightSelected: isHeightWeightSelected,
            isFirstNameEntered: isFirstNameEntered,
            isPrimaryGoalSelected: isPrimaryGoalSelected,
            isWeightGoalSelected: isWeightGoalSelected,
            isIdealWeightEntered: isIdealWeightEntered,
            isSportsSelected: isSportsSelected,
            isExperienceLevelSelected: isExperienceLevelSelected,
            isTrainingFrequencySelected: isTrainingFrequencySelected,
            isDeadlineSelected: isDeadlineSelected,
            isGoalPaceSelected: isGoalPaceSelected,
            isNutritionQualitySelected: isNutritionQualitySelected,
            isHasDietaryRestrictionsSelected: isHasDietaryRestrictionsSelected,
            isWhichRestrictionsSelected: isWhichRestrictionsSelected,
            isNutritionObstaclesSelected: isNutritionObstaclesSelected,
            isWeightManagementExperienceSelected: isWeightManagementExperienceSelected,
            isHasSufficientHydrationSelected: isHasSufficientHydrationSelected,
            isHydrationLevelSelected: isHydrationLevelSelected,
            isSleepQualitySelected: isSleepQualitySelected,
            isFatigueFrequencySelected: isFatigueFrequencySelected,
            isFatiguePeaksSelected: isFatiguePeaksSelected,
            isPersonalizedWelcomeCompleted: isPersonalizedWelcomeCompleted,
            isWeightMotivationCompleted: isWeightMotivationCompleted,
            isWeightEstimationCompleted: isWeightEstimationCompleted,
            isGoalProjectionCompleted: isGoalProjectionCompleted,
            isFaceAnalysisCompleted: isFaceAnalysisCompleted,
            isProgramCreationCompleted: isProgramCreationCompleted,
            hasDoneFirstGoalPace: hasDoneFirstGoalPace
        )
    }

    func applyCachedAnswers(_ snapshot: OnboardingAnswersSnapshot) {
        if let value = snapshot.selectedGender {
            selectedGender = value
        }
        if let value = snapshot.selectedAge {
            selectedAge = value
        }
        if let value = snapshot.selectedHeight, value > 0 {
            selectedHeight = value
        }
        if let value = snapshot.selectedWeight, Self.isPlausibleWeight(value) {
            selectedWeight = value
        }
        if let value = snapshot.firstName, Self.isRealUserFirstName(value) {
            firstName = value
        }
        if let value = snapshot.idealWeightValue, Self.isPlausibleWeight(value) {
            idealWeightValue = value
        }
        if let value = snapshot.hasWeightGoal {
            hasWeightGoal = value
        }
        if let goals = snapshot.selectedPrimaryGoals {
            selectedPrimaryGoals = Set(goals)
        }
        if let value = snapshot.selectedWeightGoal {
            selectedWeightGoal = value
        }
        if let value = snapshot.goalDeadline {
            goalDeadline = value
        }
        if let value = snapshot.selectedGoalPace {
            selectedGoalPace = value
        }
        if let value = snapshot.hasSportActivity {
            hasSportActivity = value
        }
        if let value = snapshot.isInClub {
            isInClub = value
        }
        if let value = snapshot.selectedExperienceLevel {
            selectedExperienceLevel = value
        }
        if let value = snapshot.selectedYearsOfExperience {
            selectedYearsOfExperience = value
        }
        if let value = snapshot.selectedTrainingFrequency {
            selectedTrainingFrequency = value
        }
        if let value = snapshot.selectedSessionsPerWeek {
            selectedSessionsPerWeek = value
        }
        if let value = snapshot.selectedSessionDuration {
            selectedSessionDuration = value
        }
        if let value = snapshot.selectedTrainingLocation {
            selectedTrainingLocation = value
        }
        if let equipment = snapshot.selectedEquipment {
            selectedEquipment = Set(equipment)
        }
        if let sports = snapshot.selectedSports {
            OnboardingDataModel.shared.selectedSports = Set(sports)
        }
        if let value = snapshot.nutritionProfile {
            nutritionProfile = value
        }
        if let value = snapshot.hasDietaryRestrictions {
            hasDietaryRestrictions = value
        }
        if let value = snapshot.otherDietaryRestriction {
            otherDietaryRestriction = value
        }
        if let value = snapshot.sleepProfile {
            sleepProfile = value
        }
        if let value = snapshot.referralCode {
            referralCode = value
        }
        if let ids = snapshot.completedProfileChatQuestionIDs {
            completedProfileChatQuestionIDs = Set(ids)
        }
        if let value = snapshot.onboardingPrimaryFocus {
            onboardingPrimaryFocus = value
        }
        if let values = snapshot.onboardingDebloatDrivers {
            onboardingDebloatDrivers = Set(values)
        } else if let value = snapshot.onboardingDebloatDriver {
            onboardingDebloatDrivers = [value]
        }
        if let values = snapshot.onboardingRoutineChallenges {
            onboardingRoutineChallenges = Set(values)
        }

        if let value = snapshot.isGenderSelected { isGenderSelected = value }
        if let value = snapshot.isAgeSelected { isAgeSelected = value }
        if let value = snapshot.isHeightWeightSelected { isHeightWeightSelected = value }
        if let value = snapshot.isFirstNameEntered { isFirstNameEntered = value }
        if let value = snapshot.isPrimaryGoalSelected { isPrimaryGoalSelected = value }
        if let value = snapshot.isWeightGoalSelected { isWeightGoalSelected = value }
        if let value = snapshot.isIdealWeightEntered { isIdealWeightEntered = value }
        if let value = snapshot.isSportsSelected { isSportsSelected = value }
        if let value = snapshot.isExperienceLevelSelected { isExperienceLevelSelected = value }
        if let value = snapshot.isTrainingFrequencySelected { isTrainingFrequencySelected = value }
        if let value = snapshot.isDeadlineSelected { isDeadlineSelected = value }
        if let value = snapshot.isGoalPaceSelected { isGoalPaceSelected = value }
        isNutritionQualitySelected = nutritionProfile.nutritionQuality != nil
            || (snapshot.isNutritionQualitySelected ?? false)
        if let value = snapshot.isHasDietaryRestrictionsSelected {
            isHasDietaryRestrictionsSelected = value
        }
        if let value = snapshot.isWhichRestrictionsSelected { isWhichRestrictionsSelected = value }
        if let value = snapshot.isNutritionObstaclesSelected { isNutritionObstaclesSelected = value }
        if let value = snapshot.isWeightManagementExperienceSelected {
            isWeightManagementExperienceSelected = value
        }
        if let value = snapshot.isHasSufficientHydrationSelected {
            isHasSufficientHydrationSelected = value
        }
        if let value = snapshot.isHydrationLevelSelected { isHydrationLevelSelected = value }
        if let value = snapshot.isSleepQualitySelected { isSleepQualitySelected = value }
        if let value = snapshot.isFatigueFrequencySelected { isFatigueFrequencySelected = value }
        if let value = snapshot.isFatiguePeaksSelected { isFatiguePeaksSelected = value }
        if let value = snapshot.isPersonalizedWelcomeCompleted {
            isPersonalizedWelcomeCompleted = value
        }
        if let value = snapshot.isWeightMotivationCompleted {
            isWeightMotivationCompleted = value
        }
        if let value = snapshot.isWeightEstimationCompleted {
            isWeightEstimationCompleted = value
        }
        if let value = snapshot.isGoalProjectionCompleted { isGoalProjectionCompleted = value }
        if let value = snapshot.isFaceAnalysisCompleted {
            isFaceAnalysisCompleted = value
        }
        if let value = snapshot.isProgramCreationCompleted { isProgramCreationCompleted = value }
        if let value = snapshot.hasDoneFirstGoalPace { hasDoneFirstGoalPace = value }
    }

    func markProfileChatQuestionCompleted(_ questionID: String) {
        completedProfileChatQuestionIDs.insert(questionID)
        saveProgress()
    }

    /// Remonte le fil de discussion à partir de `questionID` (inclu).
    func rewindProfileChat(from questionID: String, orderedQuestionIDs: [String]) {
        guard let index = orderedQuestionIDs.firstIndex(of: questionID) else { return }
        let toRemove = Set(orderedQuestionIDs[index...])
        completedProfileChatQuestionIDs.subtract(toRemove)
        saveProgress()
    }

    /// Handler retour discussion — `true` si le back a été consommé dans le chat.
    var profileChatBackHandler: (() -> Bool)?

    /// Barre segmentée header (discussion Moss) — alimentée par `OnboardingProfileChatView`.
    @Published var profileChatHeaderProgress: OnboardingProfileChatCoachHeaderProgress.Snapshot?

    /// Variante de l’aperçu dashboard (premier scan vs fin onboarding).
    @Published var dashboardPreviewPresentation: OnboardingDashboardPreviewPresentation = .postTransformation

    /// Après un retour manuel vers le chat : ne pas enchaîner automatiquement vers la création du programme.
    var suppressProfileChatAutoFinish = false

    /// Retour depuis « Création du programme » : rouvrir la page résultats du premier scan.
    var shouldReopenFaceScanResultsAfterBack = false

    /// Scan onboarding plein écran — un seul cover (deux `.fullScreenCover` se ferment tout seuls).
    @Published var presentedOnboardingFaceScan: OnboardingFaceScanPresentation?

    var onOnboardingFaceScanCancel: (() -> Void)?
    var onOnboardingFaceScanResult: ((FaceScanResult) -> Void)?
    var onOnboardingFaceScanContinue: (() -> Void)?
    var onOnboardingFaceScanContinueFromDashboard: (() -> Void)?

    func configureDashboardPreviewPresentation(entering step: OnboardingStep, from previous: OnboardingStep?) {
        guard step == .dashboardPreview else { return }
        switch previous {
        case .transformationPreview:
            dashboardPreviewPresentation = .postTransformation
        case .weightMotivation:
            dashboardPreviewPresentation = .firstScanPending
        default:
            break
        }
    }

    func recordDashboardFaceScanResult(_ result: FaceScanResult) {
        onboardingFaceMesh = OnboardingFaceMarkersStore.loadMesh()
        onboardingFaceMarkers = result.markers
        isFaceAnalysisCompleted = true
        markProfileChatQuestionCompleted("profile_summary")
        markProfileChatQuestionCompleted("face_scan_offer")
        saveProgress()
    }

    func presentOnboardingFaceScan(initialResult: FaceScanResult? = nil, usesChatCallbacks: Bool = true) {
        presentedOnboardingFaceScan = OnboardingFaceScanPresentation(
            initialResult: initialResult,
            usesChatCallbacks: usesChatCallbacks
        )
    }

    func dismissOnboardingFaceScan() {
        presentedOnboardingFaceScan = nil
    }

    /// Données du premier scan disponibles pour réafficher l'analyse.
    func restoredFaceScanResultForNavigation() -> FaceScanResult? {
        if let latest = FaceScanHistoryStore.shared.latestResult {
            return latest
        }

        if let markers = onboardingFaceMarkers ?? OnboardingFaceMarkersStore.load() {
            return FaceScanResult(
                id: "onboarding-restored-scan",
                userId: UserScopedStorage.currentUserId() ?? "local-user",
                markers: markers,
                source: .onboarding
            )
        }

        return nil
    }

    /// Réinitialise les validations bloquantes quand l'utilisateur revient en arrière.
    func prepareForBackNavigation(to targetStep: OnboardingStep) {
        if let current = OnboardingStep(rawValue: currentStep),
           current == .programCreation || current.rawValue > OnboardingStep.programCreation.rawValue,
           targetStep.rawValue <= OnboardingStep.programCreation.rawValue {
            isProgramCreationCompleted = false
        }

        if targetStep == .weightMotivation {
            isWeightMotivationCompleted = false
            suppressProfileChatAutoFinish = true

            if let current = OnboardingStep(rawValue: currentStep),
               current == .programCreation,
               isFaceAnalysisCompleted {
                shouldReopenFaceScanResultsAfterBack = true
                return
            }

            if let current = OnboardingStep(rawValue: currentStep),
               current == .dashboardPreview,
               dashboardPreviewPresentation == .firstScanPending {
                let orderedIDs = OnboardingProfileChatQuestionBank.questions(for: self).map(\.id)
                if completedProfileChatQuestionIDs.contains("profile_summary")
                    || completedProfileChatQuestionIDs.contains("face_scan_offer") {
                    rewindProfileChat(from: "profile_summary", orderedQuestionIDs: orderedIDs)
                }
                return
            }

            let orderedIDs = OnboardingProfileChatQuestionBank.questions(for: self).map(\.id)
            if let lastCompleted = orderedIDs.last(where: { completedProfileChatQuestionIDs.contains($0) }) {
                rewindProfileChat(from: lastCompleted, orderedQuestionIDs: orderedIDs)
            }
        }
    }

    private func hasReachedFaceScanStep(savedStep: Int, visited: [Int]) -> Bool {
        if visited.contains(OnboardingStep.faceAnalysis.rawValue) {
            return true
        }

        guard let step = OnboardingStep(rawValue: savedStep) else {
            return false
        }

        return isAfterQuestionnairePhase(step)
    }

    static func isRealUserFirstName(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let blocked = ["process", "process ai", "utilisateur", "user", "local-user", "anonymous"]
        return !blocked.contains(normalized.lowercased())
    }

    static func isPlausibleWeight(_ value: Double) -> Bool {
        value >= 35 && value <= 250
    }

    static func isReasonableIdealWeight(
        _ value: Double,
        currentWeight: Double,
        height: Double,
        gender: Gender?
    ) -> Bool {
        guard isPlausibleWeight(value), height >= 120, height <= 230 else { return false }

        let heightM = height / 100.0
        let bmi = value / (heightM * heightM)
        let minBMI = gender == .male ? 19.0 : 18.5
        let maxBMI: Double

        switch gender {
        case .male:
            maxBMI = 27.0
        case .female:
            maxBMI = 26.0
        default:
            maxBMI = 26.5
        }

        guard bmi >= minBMI, bmi <= maxBMI else { return false }

        if isPlausibleWeight(currentWeight) {
            let maxDelta = max(25.0, currentWeight * 0.30)
            return abs(value - currentWeight) <= maxDelta
        }

        return true
    }
}

enum OnboardingDashboardPreviewPresentation: Equatable {
    /// Juste après la discussion Moss — CTA « Fais ton premier scan ».
    case firstScanPending
    /// Après les témoignages — CTA « Je veux ça ».
    case postTransformation
}

/// Cover scan onboarding (capture live ou résultats déjà calculés).
struct OnboardingFaceScanPresentation: Identifiable, Equatable {
    let id: String
    let initialResult: FaceScanResult?
    let usesChatCallbacks: Bool

    init(initialResult: FaceScanResult? = nil, usesChatCallbacks: Bool = true) {
        self.initialResult = initialResult
        self.usesChatCallbacks = usesChatCallbacks
        if let initialResult {
            id = "results-\(initialResult.id)"
        } else {
            id = "live-capture"
        }
    }
}
