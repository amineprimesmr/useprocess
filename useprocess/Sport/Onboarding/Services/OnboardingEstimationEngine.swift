//
//  OnboardingEstimationEngine.swift
//  Process
//
//  Calcul de la date d'atteinte du plein potentiel.
//

import Foundation

@MainActor
final class OnboardingEstimationEngine {
    static let shared = OnboardingEstimationEngine()

    private init() {}

    func computePotentialDate(for context: OnboardingEstimationContext, now: Date = Date()) -> Date {
        let calendar = Calendar.current
        var months = baselinePotentialMonths(for: context.goalPace)
        if let pace = context.goalPace {
            months = max(1, Int(round(Double(months) * pace.paceMultiplier)))
        }

        let baseline = calendar.date(byAdding: .month, value: months, to: now) ?? now
        let baselineDays = max(1, calendar.dateComponents([.day], from: now, to: baseline).day ?? 90)
        let reduction = profileReductionDays(for: context)
        let optimizedDays = max(28, baselineDays - reduction)

        return calendar.date(byAdding: .day, value: optimizedDays, to: now) ?? baseline
    }

    func summaryLine(for context: OnboardingEstimationContext) -> String {
        if context.hasWeightGoal, let ideal = context.idealWeight {
            return "Ton objectif de \(Int(ideal.rounded())) kg est intégré dans ta trajectoire vers 100 % de ton potentiel."
        }
        return "Basé sur tes réponses, on calibre un plan adapté à ton rythme."
    }

    // MARK: - Private

    private func baselinePotentialMonths(for pace: GoalPace?) -> Int {
        switch pace {
        case .asFastAsPossible, .aggressive: return 2
        case .moderate: return 3
        case .relaxed: return 4
        case .noRush: return 5
        case .none: return 3
        }
    }

    private func profileReductionDays(for context: OnboardingEstimationContext) -> Int {
        var reduction = 14

        if let level = context.experienceLevel {
            switch level {
            case .debutant: break
            case .intermediaire: reduction += 10
            case .amateur: reduction += 18
            case .professionnel: reduction += 28
            }
        }

        if context.yearsOfExperience >= 5 {
            reduction += 10
        } else if context.yearsOfExperience >= 3 {
            reduction += 6
        } else if context.yearsOfExperience >= 1 {
            reduction += 3
        }

        if !context.selectedSports.isEmpty {
            reduction += 10
        }

        if let frequency = context.trainingFrequency {
            switch frequency {
            case "6+": reduction += 14
            case "3-5": reduction += 8
            default: break
            }
        }

        if context.hasWeightGoal, let pace = context.goalPace {
            switch pace {
            case .asFastAsPossible, .aggressive: reduction += 6
            case .moderate: reduction += 4
            default: break
            }
        }

        return reduction
    }
}
