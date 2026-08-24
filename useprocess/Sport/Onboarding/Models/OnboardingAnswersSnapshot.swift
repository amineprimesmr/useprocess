//
//  OnboardingAnswersSnapshot.swift
//  Process
//
//  Cache local des réponses onboarding (reprise après retour arrière ou crash).
//  Les anciennes clés Codable inconnues sont ignorées à la lecture.
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
    var selectedGoalPace: GoalPace?

    var hasSportActivity: Bool?
    var selectedTrainingFrequency: String?
    var selectedSports: [String]?

    var nutritionProfile: NutritionProfile?
    var sleepProfile: SleepProfile?
    var referralCode: String?
    var completedProfileChatQuestionIDs: [String]?
    var onboardingDebloatDrivers: [OnboardingDebloatDriver]?
    /// Ancien format single-choice — migration lecture seule.
    var onboardingDebloatDriver: OnboardingDebloatDriver?

    var isGenderSelected: Bool?
    var isAgeSelected: Bool?
    var isHeightWeightSelected: Bool?
    var isFirstNameEntered: Bool?
    var isPrimaryGoalSelected: Bool?
    var isWeightGoalSelected: Bool?
    var isIdealWeightEntered: Bool?
    var isTrainingFrequencySelected: Bool?
    var isGoalPaceSelected: Bool?
    var isNutritionQualitySelected: Bool?
    var isWeightManagementExperienceSelected: Bool?
    var isWeightMotivationCompleted: Bool?
    var isWeightEstimationCompleted: Bool?
    var isGoalProjectionCompleted: Bool?
    var isFaceAnalysisCompleted: Bool?
    var isProgramCreationCompleted: Bool?
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
