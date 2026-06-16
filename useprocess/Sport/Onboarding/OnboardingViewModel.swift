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
    @Published var selectedHeight: Double = 175 // cm
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
    @Published var isWeightMotivationCompleted: Bool = false
    @Published var isFaceAnalysisCompleted: Bool = false
    @Published var onboardingFaceMarkers: FaceWellnessMarkers?
    @Published var onboardingFaceMesh: FaceMesh3DData?
    @Published var isProgramCreationCompleted: Bool = false
    
    // MARK: - Sleep Profile (migré complètement vers ViewModel)
    @Published var sleepProfile = SleepProfile()
    
    // MARK: - Referral
    @Published var referralCode: String? = nil // Code de parrainage utilisé à l'inscription
    
    // MARK: - Initialization
    
    init() {
        // Charger la progression sauvegardée
        let savedStep = OnboardingProgressService.shared.loadCurrentStep()
        
        // ✅ CORRECTION: Charger l'historique complet des étapes visitées depuis UserDefaults
        let savedVisitedSteps = OnboardingProgressService.shared.loadVisitedSteps()

        if let cached = OnboardingProgressService.shared.loadAnswers() {
            applyCachedAnswers(cached)
        }
        
        if savedStep > 0, OnboardingStep(rawValue: savedStep) != nil {
            currentStep = savedStep

            if !savedVisitedSteps.isEmpty {
                visitedSteps = normalizeOnboardingVisitedStack(
                    visitedSteps: savedVisitedSteps,
                    currentStep: savedStep
                )
            } else {
                visitedSteps = [savedStep]
            }
        } else {
            if !savedVisitedSteps.isEmpty {
                visitedSteps = savedVisitedSteps.filter {
                    guard let step = OnboardingStep(rawValue: $0) else { return false }
                    return !step.isTransientSkippedStep
                }
            } else {
                visitedSteps = [OnboardingStep.videoIntroduction.rawValue]
            }
        }

        if let payload = OnboardingFaceMarkersStore.loadPayload(),
           hasReachedFaceScanStep(savedStep: OnboardingProgressService.shared.loadCurrentStep(),
                                 visited: OnboardingProgressService.shared.loadVisitedSteps()) {
            onboardingFaceMarkers = payload.markers
            onboardingFaceMesh = payload.mesh.isValid ? payload.mesh : nil
            isFaceAnalysisCompleted = true
        } else if let markers = OnboardingFaceMarkersStore.load(),
                  hasReachedFaceScanStep(savedStep: OnboardingProgressService.shared.loadCurrentStep(),
                                       visited: OnboardingProgressService.shared.loadVisitedSteps()) {
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
        case .personalizedWelcome:
            return isPersonalizedWelcomeCompleted
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
            return isIdealWeightEntered && idealWeightValue > 0
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
            return isGoalProjectionCompleted
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

    func isWeightGoalIncompatibleWithBMI() -> Bool {
        guard let goal = selectedWeightGoal ?? inferredWeightGoalFromIdealWeight() else { return false }

        let heightInMeters = selectedHeight / 100.0
        guard heightInMeters > 0 else { return false }

        let currentBMI = selectedWeight / (heightInMeters * heightInMeters)
        return (currentBMI >= 25.0 && goal == .gain) || (currentBMI < 18.5 && goal == .lose)
    }
    
    // MARK: - Progress Management
    
    func saveProgress() {
        OnboardingProgressService.shared.saveCurrentStep(currentStep)
        OnboardingProgressService.shared.saveVisitedSteps(visitedSteps)
        OnboardingProgressService.shared.saveAnswers(makeAnswersSnapshot())
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
            nutritionProfile: nutritionProfile,
            hasDietaryRestrictions: hasDietaryRestrictions,
            otherDietaryRestriction: otherDietaryRestriction,
            sleepProfile: sleepProfile,
            isGenderSelected: isGenderSelected,
            isAgeSelected: isAgeSelected,
            isHeightWeightSelected: isHeightWeightSelected,
            isFirstNameEntered: isFirstNameEntered,
            isPrimaryGoalSelected: isPrimaryGoalSelected,
            isWeightGoalSelected: isWeightGoalSelected,
            isIdealWeightEntered: isIdealWeightEntered,
            isSportsSelected: isSportsSelected,
            isGoalPaceSelected: isGoalPaceSelected,
            isNutritionQualitySelected: isNutritionQualitySelected,
            isWeightManagementExperienceSelected: isWeightManagementExperienceSelected,
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

        if let value = snapshot.isGenderSelected { isGenderSelected = value }
        if let value = snapshot.isAgeSelected { isAgeSelected = value }
        if let value = snapshot.isHeightWeightSelected { isHeightWeightSelected = value }
        if let value = snapshot.isFirstNameEntered { isFirstNameEntered = value }
        if let value = snapshot.isPrimaryGoalSelected { isPrimaryGoalSelected = value }
        if let value = snapshot.isWeightGoalSelected { isWeightGoalSelected = value }
        if let value = snapshot.isIdealWeightEntered { isIdealWeightEntered = value }
        if let value = snapshot.isSportsSelected { isSportsSelected = value }
        if let value = snapshot.isGoalPaceSelected { isGoalPaceSelected = value }
        isNutritionQualitySelected = nutritionProfile.nutritionQuality != nil
            || (snapshot.isNutritionQualitySelected ?? false)
        if let value = snapshot.isWeightManagementExperienceSelected {
            isWeightManagementExperienceSelected = value
        }
        if let value = snapshot.hasDoneFirstGoalPace { hasDoneFirstGoalPace = value }
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
}
