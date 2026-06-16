//
//  OnboardingEstimationModels.swift
//  Process
//
//  Modèle unifié pour les deux écrans « D'après nos estimations ».
//

import Foundation

/// Première estimation (peu d'infos) ou seconde (après sport / profil enrichi).
enum OnboardingEstimationPhase {
    case baseline
    case optimized
}

/// Contexte partagé entre les deux écrans d'estimation.
struct OnboardingEstimationContext {
    let phase: OnboardingEstimationPhase
    let hasWeightGoal: Bool
    let currentWeight: Double?
    let idealWeight: Double?
    let weightGoal: WeightGoal?
    let weeklyRate: Double
    let goalPace: GoalPace?
    let experienceLevel: ExperienceLevel?
    let yearsOfExperience: Int
    let selectedSports: Set<String>
    let trainingFrequency: String?

    var titleMessage: String {
        if hasWeightGoal, let ideal = idealWeight {
            return "Tu feras \(String(format: "%.0f", ideal)) kg le"
        }
        return "Tu auras atteint 100% de ton potentiel le"
    }

    var graphCurrentValue: Double {
        if hasWeightGoal, let current = currentWeight { return current }
        return 0
    }

    var graphTargetValue: Double {
        if hasWeightGoal, let ideal = idealWeight { return ideal }
        return 100
    }

    var graphIsAscending: Bool {
        if hasWeightGoal, let goal = weightGoal {
            return goal == .gain
        }
        return true
    }
}

extension OnboardingEstimationContext {
    static func make(
        phase: OnboardingEstimationPhase,
        viewModel: OnboardingViewModel,
        selectedSports: Set<String>
    ) -> OnboardingEstimationContext {
        let hasWeightGoal = viewModel.hasWeightObjective && viewModel.isIdealWeightEntered

        return OnboardingEstimationContext(
            phase: phase,
            hasWeightGoal: hasWeightGoal,
            currentWeight: OnboardingViewModel.isPlausibleWeight(viewModel.selectedWeight) ? viewModel.selectedWeight : nil,
            idealWeight: hasWeightGoal ? viewModel.idealWeightValue : nil,
            weightGoal: viewModel.selectedWeightGoal,
            weeklyRate: viewModel.selectedGoalPace?.weightEstimationWeeklyRate ?? 0.5,
            goalPace: viewModel.selectedGoalPace,
            experienceLevel: viewModel.selectedExperienceLevel,
            yearsOfExperience: viewModel.selectedYearsOfExperience,
            selectedSports: selectedSports,
            trainingFrequency: viewModel.selectedTrainingFrequency
        )
    }
}
