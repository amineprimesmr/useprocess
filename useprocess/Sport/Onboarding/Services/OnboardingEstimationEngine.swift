//
//  OnboardingEstimationEngine.swift
//  useprocess
//
//  Projections onboarding : date poids idéal + date plein potentiel.
//

import Foundation

struct OnboardingEstimationTimeline: Equatable {
    let potentialDate: Date
    let weightGoalDate: Date?
    let potentialDays: Int
    let weightGoalDays: Int?
    let weightMilestoneFraction: Double
}

@MainActor
final class OnboardingEstimationEngine {
    static let shared = OnboardingEstimationEngine()

    private init() {}

    func computeTimeline(for context: OnboardingEstimationContext, now: Date = Date()) -> OnboardingEstimationTimeline {
        let calendar = Calendar.current
        let weightGoalDays = computeWeightGoalDays(for: context)
        let potentialDays = computePotentialDays(for: context, weightGoalDays: weightGoalDays)
        let potentialDate = calendar.date(byAdding: .day, value: potentialDays, to: now) ?? now
        let weightGoalDate = weightGoalDays.flatMap { calendar.date(byAdding: .day, value: $0, to: now) }

        let milestoneFraction: Double
        if let weightGoalDays, potentialDays > 0 {
            milestoneFraction = min(0.9, max(0.15, Double(weightGoalDays) / Double(potentialDays)))
        } else {
            milestoneFraction = 0
        }

        return OnboardingEstimationTimeline(
            potentialDate: potentialDate,
            weightGoalDate: weightGoalDate,
            potentialDays: potentialDays,
            weightGoalDays: weightGoalDays,
            weightMilestoneFraction: milestoneFraction
        )
    }

    func computePotentialDate(for context: OnboardingEstimationContext, now: Date = Date()) -> Date {
        computeTimeline(for: context, now: now).potentialDate
    }

    func summaryLine(for context: OnboardingEstimationContext) -> String {
        if context.hasWeightGoal, let ideal = context.idealWeight {
            return "Ton objectif de \(Int(ideal.rounded())) kg est intégré dans ta trajectoire vers 100 % de ton potentiel."
        }
        return "Basé sur tes réponses, on calibre un plan adapté à ton rythme."
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

        var weeklyRate = context.goalPace?.weightEstimationWeeklyRate ?? 0.5

        if delta <= 3 {
            weeklyRate *= 1.18
        } else if delta <= 6 {
            weeklyRate *= 1.08
        } else if delta >= 15 {
            weeklyRate *= 0.92
        }

        weeklyRate *= experienceRateMultiplier(for: context.experienceLevel)
        weeklyRate *= trainingRateMultiplier(for: context.trainingFrequency)

        if context.age > 0, context.age <= 28 {
            weeklyRate *= 1.06
        } else if context.age >= 40 {
            weeklyRate *= 0.94
        }

        weeklyRate = min(weeklyRate, delta <= 4 ? 1.05 : 0.9)
        weeklyRate = max(weeklyRate, 0.22)

        var days = Int(ceil(delta / weeklyRate)) * 7

        if delta <= 2 {
            days = max(days, 12)
        } else if delta <= 5 {
            days = max(days, 16)
        } else {
            days = max(days, 21)
        }

        if let pace = context.goalPace {
            days = Int(round(Double(days) * pace.paceMultiplier))
        }

        return max(10, days)
    }

    // MARK: - Full potential timeline

    private func computePotentialDays(
        for context: OnboardingEstimationContext,
        weightGoalDays: Int?
    ) -> Int {
        let weightDays = weightGoalDays ?? 0
        let delta = weightDelta(for: context)

        let optimizationDays = optimizationPhaseDays(deltaKg: delta, hasWeightGoal: context.hasWeightGoal)

        var totalDays: Int
        if let delta, delta > 0, weightDays > 0 {
            if delta <= 5 {
                totalDays = weightDays + optimizationDays
                totalDays -= min(profileReductionDays(for: context), 10)
            } else if delta <= 12 {
                totalDays = max(weightDays + optimizationDays, weightDays + 24)
                totalDays -= min(profileReductionDays(for: context), 18)
            } else {
                totalDays = max(weightDays + optimizationDays, baselineTransformationDays(for: context.goalPace))
                totalDays -= profileReductionDays(for: context)
            }
        } else {
            totalDays = baselineTransformationDays(for: context.goalPace)
            totalDays -= profileReductionDays(for: context)
        }

        if let pace = context.goalPace {
            totalDays = Int(round(Double(totalDays) * pace.paceMultiplier))
        }

        if weightDays > 0 {
            totalDays = max(weightDays + 8, totalDays)
        } else {
            totalDays = max(28, totalDays)
        }

        return min(totalDays, 365)
    }

    private func optimizationPhaseDays(deltaKg: Double?, hasWeightGoal: Bool) -> Int {
        guard hasWeightGoal, let delta = deltaKg, delta > 0 else {
            return 42
        }

        switch delta {
        case ...3:
            return 14
        case ...8:
            return 18 + Int(delta * 2)
        case ...15:
            return 24 + Int(delta * 2.5)
        default:
            return 32 + Int(min(delta, 28) * 2.8)
        }
    }

    private func baselineTransformationDays(for pace: GoalPace?) -> Int {
        switch pace {
        case .asFastAsPossible, .aggressive: return 56
        case .moderate: return 72
        case .relaxed: return 88
        case .noRush: return 98
        case .none: return 72
        }
    }

    private func weightDelta(for context: OnboardingEstimationContext) -> Double? {
        guard let current = context.currentWeight, let ideal = context.idealWeight else { return nil }
        return abs(ideal - current)
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

    private func profileReductionDays(for context: OnboardingEstimationContext) -> Int {
        var reduction = 10

        if let level = context.experienceLevel {
            switch level {
            case .debutant: break
            case .intermediaire: reduction += 6
            case .amateur: reduction += 12
            case .professionnel: reduction += 18
            }
        }

        if context.yearsOfExperience >= 5 {
            reduction += 8
        } else if context.yearsOfExperience >= 3 {
            reduction += 5
        } else if context.yearsOfExperience >= 1 {
            reduction += 2
        }

        if !context.selectedSports.isEmpty {
            reduction += 6
        }

        if let frequency = context.trainingFrequency {
            switch frequency {
            case "6+": reduction += 8
            case "3-5": reduction += 4
            default: break
            }
        }

        return reduction
    }
}
