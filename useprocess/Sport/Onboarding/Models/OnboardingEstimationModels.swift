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
    let age: Int
    let height: Double?
    let gender: Gender?

    var weightMilestoneLabel: String? {
        guard hasWeightGoal, let ideal = idealWeight else { return nil }
        return "\(Int(ideal.rounded())) kg"
    }
}

struct OnboardingGraphMilestone: Equatable {
    let id: String
    let label: String
    let date: Date
    let fraction: Double
}

/// Données figées du graphique — calculées une seule fois pour éviter les sauts pendant l'animation.
struct OnboardingEstimationGraphSnapshot {
    let referenceDate: Date
    /// Date debloat visage (titre + chips).
    let projectedDate: Date
    /// Fin réelle de la courbe (extrémité droite).
    let endDate: Date
    let countdownDays: Int
    /// Valeurs 1 → 0 : gonflement → dégonflement.
    let descentValues: [Double]
    /// Jalons intermédiaires uniquement — pas le point final de la courbe.
    let intermediateMarkers: [OnboardingGraphMilestone]

    var countdownWeeks: Int {
        ProcessDurationFormat.weekCount(fromDays: countdownDays)
    }

    static func make(
        context: OnboardingEstimationContext,
        timeline: OnboardingEstimationTimeline,
        referenceDate: Date = Date()
    ) -> OnboardingEstimationGraphSnapshot {
        let calendar = Calendar.current
        let trajectory = timeline.trajectory
        let debloatDate = timeline.debloatDate
        let endDate = trajectory.endDate

        let countdownDays = max(
            0,
            calendar.dateComponents([.day], from: referenceDate, to: debloatDate).day ?? 0
        )

        let pointCount = 7
        let seed = Int(debloatDate.timeIntervalSince1970) % 997
        let descentValues = makeIrregularDescent(pointCount: pointCount, seed: seed)

        let intermediateMarkers = trajectory.milestones
            .filter { milestone in
                milestone.fraction < 0.94
                    && abs(milestone.date.timeIntervalSince(endDate)) > 86_400
            }
            .map {
                OnboardingGraphMilestone(
                    id: $0.id,
                    label: $0.label,
                    date: $0.date,
                    fraction: $0.fraction
                )
            }

        return OnboardingEstimationGraphSnapshot(
            referenceDate: referenceDate,
            projectedDate: debloatDate,
            endDate: endDate,
            countdownDays: countdownDays,
            descentValues: descentValues,
            intermediateMarkers: intermediateMarkers
        )
    }

    /// Courbe descendante : 7 points max, irrégularité légère (pas de zigzag).
    private static func makeIrregularDescent(pointCount: Int, seed: Int) -> [Double] {
        let count = min(7, max(5, pointCount))
        guard count >= 2 else { return [0.92, 0.08] }

        var values: [Double] = []
        let seedD = Double(seed)

        for index in 0..<count {
            let t = Double(index) / Double(count - 1)
            var level = 1.0 - pow(t, 1.18)

            // Légères variations lentes — pas de haute fréquence.
            level += sin(t * 2.8 + seedD * 0.05) * 0.045 * (1.0 - t * 0.5)
            level += cos(t * 1.6 + seedD * 0.08) * 0.025

            values.append(max(0.06, min(0.98, level)))
        }

        values[0] = 0.94
        values[values.count - 1] = 0.07
        return values
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
            weightGoal: viewModel.selectedWeightGoal
                ?? PersonalizedIdealWeightCalculator.inferredWeightGoal(
                    currentWeight: viewModel.selectedWeight,
                    height: viewModel.selectedHeight,
                    age: viewModel.selectedAge,
                    gender: viewModel.selectedGender
                ),
            goalPace: viewModel.selectedGoalPace,
            experienceLevel: viewModel.selectedExperienceLevel,
            yearsOfExperience: viewModel.selectedYearsOfExperience,
            selectedSports: selectedSports,
            trainingFrequency: viewModel.selectedTrainingFrequency,
            age: viewModel.selectedAge,
            height: viewModel.selectedHeight,
            gender: viewModel.selectedGender
        )
    }
}
