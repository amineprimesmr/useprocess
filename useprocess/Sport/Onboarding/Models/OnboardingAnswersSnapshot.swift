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

    var nutritionProfile: NutritionProfile?
    var hasDietaryRestrictions: Bool?
    var otherDietaryRestriction: String?
    var sleepProfile: SleepProfile?

    var isGenderSelected: Bool?
    var isAgeSelected: Bool?
    var isHeightWeightSelected: Bool?
    var isFirstNameEntered: Bool?
    var isPrimaryGoalSelected: Bool?
    var isWeightGoalSelected: Bool?
    var isIdealWeightEntered: Bool?
    var isSportsSelected: Bool?
    var isGoalPaceSelected: Bool?
    var isNutritionQualitySelected: Bool?
    var isWeightManagementExperienceSelected: Bool?
    var hasDoneFirstGoalPace: Bool?
}
