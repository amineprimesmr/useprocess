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

        let pointCount = 13
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

    /// Courbe descendante organique — paliers, micro-variations, pas de sinusoïde régulière.
    private static func makeIrregularDescent(pointCount: Int, seed: Int) -> [Double] {
        let count = min(14, max(10, pointCount))
        guard count >= 2 else { return [0.92, 0.08] }

        let seedD = Double(seed)
        var values: [Double] = []

        func jitter(_ t: Double, freq: Double, amp: Double, phase: Double) -> Double {
            sin(t * freq + phase) * amp + cos(t * (freq * 0.67) + phase * 1.3) * amp * 0.55
        }

        for index in 0..<count {
            let t = Double(index) / Double(count - 1)
            var level: Double

            switch t {
            case ..<0.18:
                // Plateau haut — gonflement encore présent
                level = 0.93 - t * 0.35 + jitter(t, freq: 6.2, amp: 0.028, phase: seedD * 0.04)
            case ..<0.38:
                // Première chute lente puis accélération
                level = 0.87 - (t - 0.18) * 1.05 + jitter(t, freq: 4.1, amp: 0.04, phase: seedD * 0.07)
            case ..<0.58:
                // Petit rebond visuel (rétention qui repique) puis reprise
                level = 0.66 - (t - 0.38) * 0.75 + jitter(t, freq: 8.5, amp: 0.05, phase: seedD * 0.05)
            case ..<0.76:
                // Descente plus nette
                level = 0.51 - (t - 0.58) * 1.35 + jitter(t, freq: 3.4, amp: 0.032, phase: seedD * 0.09)
            default:
                // Fin de trajectoire — dégonflement marqué
                level = 0.27 - (t - 0.76) * 0.82 + jitter(t, freq: 5.7, amp: 0.022, phase: seedD * 0.11)
            }

            values.append(max(0.06, min(0.98, level)))
        }

        values[0] = 0.94
        values[values.count - 1] = 0.07

        // Tendance globalement descendante sans zigzag agressif
        for index in 1..<values.count {
            let floor = values[index - 1] - 0.045
            if values[index] > floor {
                values[index] = floor
            }
        }

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
