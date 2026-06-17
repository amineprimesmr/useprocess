//
//  OnboardingEstimationModels.swift
//  Process
//
//  Contexte unique pour l'écran « D'après nos estimations ».
//

import Foundation

struct OnboardingEstimationContext {
    let hasWeightGoal: Bool
    let currentWeight: Double?
    let idealWeight: Double?
    let weightGoal: WeightGoal?
    let goalPace: GoalPace?
    let experienceLevel: ExperienceLevel?
    let yearsOfExperience: Int
    let selectedSports: Set<String>
    let trainingFrequency: String?

    var titleMessage: String {
        "Tu auras atteint ton plein potentiel le"
    }

    var weightMilestoneLabel: String? {
        guard hasWeightGoal, let ideal = idealWeight else { return nil }
        return "\(Int(ideal.rounded())) kg"
    }

    /// Position horizontale du jalon poids sur le graphique (0…1).
    static let weightMilestoneFraction: Double = 2.0 / 3.0
}

/// Données figées du graphique — calculées une seule fois pour éviter les sauts pendant l'animation.
struct OnboardingEstimationGraphSnapshot {
    let projectedDate: Date
    let countdownDays: Int
    let normalizedValues: [Double]
    let weightMilestoneLabel: String?

    static func make(
        context: OnboardingEstimationContext,
        projectedDate: Date,
        referenceDate: Date = Date()
    ) -> OnboardingEstimationGraphSnapshot {
        let calendar = Calendar.current
        let countdownDays = max(
            0,
            calendar.dateComponents([.day], from: referenceDate, to: projectedDate).day ?? 0
        )

        let curveData = GoalProjectionService.shared.generateProgressCurveData(
            startDate: referenceDate,
            endDate: projectedDate,
            currentValue: 0,
            targetValue: 100,
            isWeightGoal: false,
            weightGoal: nil
        )

        let normalizedValues: [Double]
        if curveData.count <= 6 {
            normalizedValues = curveData.map { $0.value / 100.0 }
        } else {
            let step = max(1, curveData.count / 6)
            normalizedValues = Array(stride(from: 0, to: curveData.count, by: step).prefix(6)).map { index in
                curveData[index].value / 100.0
            }
        }

        return OnboardingEstimationGraphSnapshot(
            projectedDate: projectedDate,
            countdownDays: countdownDays,
            normalizedValues: normalizedValues,
            weightMilestoneLabel: context.weightMilestoneLabel
        )
    }
}

extension OnboardingEstimationContext {
    static func make(
        viewModel: OnboardingViewModel,
        selectedSports: Set<String>
    ) -> OnboardingEstimationContext {
        let hasWeightGoal = viewModel.hasWeightObjective && viewModel.isIdealWeightEntered

        return OnboardingEstimationContext(
            hasWeightGoal: hasWeightGoal,
            currentWeight: OnboardingViewModel.isPlausibleWeight(viewModel.selectedWeight) ? viewModel.selectedWeight : nil,
            idealWeight: hasWeightGoal ? viewModel.idealWeightValue : nil,
            weightGoal: viewModel.selectedWeightGoal,
            goalPace: viewModel.selectedGoalPace,
            experienceLevel: viewModel.selectedExperienceLevel,
            yearsOfExperience: viewModel.selectedYearsOfExperience,
            selectedSports: selectedSports,
            trainingFrequency: viewModel.selectedTrainingFrequency
        )
    }
}
