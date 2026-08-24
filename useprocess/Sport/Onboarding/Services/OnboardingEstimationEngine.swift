//
//  OnboardingEstimationEngine.swift
//  useprocess
//
//  Projections onboarding — date debloat visage + trajectoire.
//

import Foundation

struct OnboardingEstimationTimeline: Equatable {
    let trajectory: TrajectoryTimeline

    var endDate: Date { trajectory.endDate }
    var debloatDate: Date { trajectory.debloatMilestone?.date ?? trajectory.endDate }
    var totalDays: Int { trajectory.totalDays }
    var debloatDays: Int { trajectory.debloatDays }
    var weightGoalDays: Int? { trajectory.weightDays }
    var weightGoalDate: Date? { trajectory.weightMilestone?.date }
}

@MainActor
final class OnboardingEstimationEngine {
    static let shared = OnboardingEstimationEngine()

    private init() {}

    func computeTimeline(for context: OnboardingEstimationContext, now: Date = Date()) -> OnboardingEstimationTimeline {
        let signals = PlanDurationPersonalizer.signals(from: context)
        let debloatDays = PlanDurationPersonalizer.debloatDays(signals: signals)
        let weightDays = computeWeightGoalDays(for: context)
        let weightLabel = context.weightMilestoneLabel

        let trajectory = PlanDurationPersonalizer.computeTimeline(
            signals: signals,
            weightDays: weightDays,
            debloatDays: debloatDays,
            hasWeightGoal: context.hasWeightGoal,
            weightLabel: weightLabel,
            now: now
        )

        return OnboardingEstimationTimeline(trajectory: trajectory)
    }

    @MainActor
    func titleMessage(for context: OnboardingEstimationContext) -> String {
        OnboardingCopy.t("Ton visage aura totalement dégonflé le", en: "Your face will look fully debloated by")
    }

    @MainActor
    func summaryLine(for context: OnboardingEstimationContext) -> String {
        let timeline = computeTimeline(for: context)
        let debloatFmt = PlanDurationPersonalizer.formatShortDate(timeline.debloatDate)
        return OnboardingCopy.t(
            "Calibré sur ton profil — visage visiblement moins gonflé d’ici \(debloatFmt).",
            en: "Calibrated to your profile — a visibly less puffy face by \(debloatFmt)."
        )
    }

    // MARK: - Weight goal timeline

    private func computeWeightGoalDays(for context: OnboardingEstimationContext) -> Int? {
        guard context.hasWeightGoal,
              let current = context.currentWeight,
              let ideal = context.idealWeight,
              context.weightGoal != nil else {
            return nil
        }

        let delta = abs(ideal - current)
        guard delta >= 0.5 else { return nil }

        var weeklyRate = context.goalPace?.weightEstimationWeeklyRate ?? 0.7

        if context.age > 0, context.age <= 25 {
            weeklyRate = max(weeklyRate, 0.85)
        }

        if delta <= 3 {
            weeklyRate *= 1.18
        } else if delta <= 6 {
            weeklyRate *= 1.12
        } else if delta <= 10 {
            weeklyRate *= 1.08
        } else if delta >= 15 {
            weeklyRate *= 0.92
        }

        weeklyRate *= experienceRateMultiplier(for: context.experienceLevel)
        weeklyRate *= trainingRateMultiplier(for: context.trainingFrequency)

        if context.age > 0, context.age <= 22 {
            weeklyRate *= 1.12
        } else if context.age > 0, context.age <= 28 {
            weeklyRate *= 1.08
        } else if context.age >= 40 {
            weeklyRate *= 0.94
        }

        let signals = PlanDurationPersonalizer.signals(from: context)
        return PlanDurationPersonalizer.onboardingWeightGoalDays(
            delta: delta,
            weeklyRate: weeklyRate,
            signals: signals
        )
    }

    private func experienceRateMultiplier(for level: ExperienceLevel?) -> Double {
        switch level {
        case .intermediaire: return 1.07
        case .amateur: return 1.14
        case .professionnel: return 1.2
        default: return 1.0
        }
    }

    private func trainingRateMultiplier(for frequency: String?) -> Double {
        switch frequency {
        case "6+": return 1.1
        case "3-5": return 1.05
        default: return 1.0
        }
    }
}
