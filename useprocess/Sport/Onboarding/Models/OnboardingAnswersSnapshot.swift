//
//  OnboardingAnswersSnapshot.swift
//  Process
//
//  Cache local des réponses onboarding (reprise après retour arrière ou crash).
//

import Foundation

struct OnboardingAnswersSnapshot: Codable, Equatable {
    var selectedGender: Gender?
    var selectedAge: Int?
    var selectedHeight: Double?
    var selectedWeight: Double?
    var firstName: String?
    var idealWeightValue: Double?

    var hasWeightGoal: Bool?
    var selectedPrimaryGoals: [PrimaryGoal]?
    var selectedWeightGoal: WeightGoal?
    var goalDeadline: GoalDeadline?
    var selectedGoalPace: GoalPace?

    var hasSportActivity: Bool?
    var isInClub: Bool?
    var selectedExperienceLevel: ExperienceLevel?
    var selectedYearsOfExperience: Int?
    var selectedTrainingFrequency: String?
    var selectedSessionsPerWeek: Int?
    var selectedSessionDuration: Int?
    var selectedTrainingLocation: TrainingLocation?
    var selectedEquipment: [PlanEquipment]?
    var selectedSports: [String]?

    var nutritionProfile: NutritionProfile?
    var hasDietaryRestrictions: Bool?
    var otherDietaryRestriction: String?
    var sleepProfile: SleepProfile?
    var referralCode: String?
    var completedProfileChatQuestionIDs: [String]?
    var onboardingPrimaryFocus: OnboardingPrimaryFocus?
    var onboardingDebloatDrivers: [OnboardingDebloatDriver]?
    /// Ancien format single-choice — migration lecture seule.
    var onboardingDebloatDriver: OnboardingDebloatDriver?
    var onboardingRoutineChallenges: [OnboardingRoutineChallenge]?

    var isGenderSelected: Bool?
    var isAgeSelected: Bool?
    var isHeightWeightSelected: Bool?
    var isFirstNameEntered: Bool?
    var isPrimaryGoalSelected: Bool?
    var isWeightGoalSelected: Bool?
    var isIdealWeightEntered: Bool?
    var isSportsSelected: Bool?
    var isExperienceLevelSelected: Bool?
    var isTrainingFrequencySelected: Bool?
    var isDeadlineSelected: Bool?
    var isGoalPaceSelected: Bool?
    var isNutritionQualitySelected: Bool?
    var isHasDietaryRestrictionsSelected: Bool?
    var isWhichRestrictionsSelected: Bool?
    var isNutritionObstaclesSelected: Bool?
    var isWeightManagementExperienceSelected: Bool?
    var isHasSufficientHydrationSelected: Bool?
    var isHydrationLevelSelected: Bool?
    var isSleepQualitySelected: Bool?
    var isFatigueFrequencySelected: Bool?
    var isFatiguePeaksSelected: Bool?
    var isPersonalizedWelcomeCompleted: Bool?
    var isWeightMotivationCompleted: Bool?
    var isWeightEstimationCompleted: Bool?
    var isGoalProjectionCompleted: Bool?
    var isFaceAnalysisCompleted: Bool?
    var isProgramCreationCompleted: Bool?
    var hasDoneFirstGoalPace: Bool?
    /// Variante dashboard preview (legacy : `postTransformation` → 1er scan).
    var dashboardPreviewPresentation: String?
    /// Premier tour dashboard (scan) terminé — ne pas rouvrir ce tour à la reprise.
    var hasCompletedFirstDashboardPreview: Bool?
    /// Session scan du 1er dashboard en cours (reprise après kill ou retour Réglages).
    var dashboardScanPersistedState: OnboardingDashboardScanPersistedState?
}

/// État UI du 1er dashboard quand le scan est ouvert — persisté pour reprise.
struct OnboardingDashboardScanPersistedState: Codable, Equatable {
    var carouselStep: Int
    var scanExpandProgress: Double
    var isScanPageInteractive: Bool
    var showsSideCards: Bool
    var showsTourChrome: Bool
}
