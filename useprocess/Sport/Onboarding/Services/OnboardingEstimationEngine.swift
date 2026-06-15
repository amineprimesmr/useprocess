//
//  OnboardingEstimationEngine.swift
//  Process
//
//  Calcul unifié des dates d'estimation (poids ou 100 % potentiel).
//

import Foundation

@MainActor
final class OnboardingEstimationEngine {
    static let shared = OnboardingEstimationEngine()

    private let userDefaults = UserDefaults.standard
    private var baselineDateKey: String {
        (Bundle.main.bundleIdentifier ?? "useprocess") + ".onboarding.estimation.baseline_date"
    }

    private init() {}

    func storeBaselineDate(_ date: Date) {
        userDefaults.set(date.timeIntervalSince1970, forKey: baselineDateKey)
    }

    func loadBaselineDate() -> Date? {
        let interval = userDefaults.double(forKey: baselineDateKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    func resetBaselineDate() {
        userDefaults.removeObject(forKey: baselineDateKey)
    }

    func computeProjectedDate(for context: OnboardingEstimationContext, now: Date = Date()) -> Date {
        let calendar = Calendar.current

        switch context.phase {
        case .baseline:
            let date = computeBaselineDate(for: context, now: now, calendar: calendar)
            storeBaselineDate(date)
            return date

        case .optimized:
            let baseline = loadBaselineDate() ?? computeBaselineDate(for: context, now: now, calendar: calendar)
            let optimized = computeOptimizedDate(for: context, baseline: baseline, now: now, calendar: calendar)
            return min(baseline, optimized)
        }
    }

    // MARK: - Baseline

    private func computeBaselineDate(
        for context: OnboardingEstimationContext,
        now: Date,
        calendar: Calendar
    ) -> Date {
        if context.hasWeightGoal,
           let current = context.currentWeight,
           let ideal = context.idealWeight {
            let difference = abs(ideal - current)
            guard difference > 0 else {
                return calendar.date(byAdding: .month, value: 1, to: now) ?? now
            }

            let rate = max(context.weeklyRate, 0.1)
            let weeks = max(1, Int(ceil(difference / rate)))
            return calendar.date(byAdding: .day, value: weeks * 7, to: now) ?? now
        }

        var months = baselinePotentialMonths(for: context.goalPace)
        if let pace = context.goalPace {
            months = max(1, Int(round(Double(months) * pace.paceMultiplier)))
        }
        return calendar.date(byAdding: .month, value: months, to: now) ?? now
    }

    private func baselinePotentialMonths(for pace: GoalPace?) -> Int {
        switch pace {
        case .asFastAsPossible: return 2
        case .aggressive: return 2
        case .moderate: return 3
        case .relaxed: return 4
        case .noRush: return 5
        case .none: return 3
        }
    }

    // MARK: - Optimized (toujours plus tôt que la baseline)

    private func computeOptimizedDate(
        for context: OnboardingEstimationContext,
        baseline: Date,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let baselineDays = max(1, calendar.dateComponents([.day], from: now, to: baseline).day ?? 30)
        let reduction = optimizedReductionDays(for: context)
        let targetDays = max(7, baselineDays - reduction)
        let ratio = Double(targetDays) / Double(baselineDays)
        let optimizedDays = max(7, Int(round(Double(baselineDays) * min(ratio, 0.82))))

        return calendar.date(byAdding: .day, value: optimizedDays, to: now) ?? baseline
    }

    private func optimizedReductionDays(for context: OnboardingEstimationContext) -> Int {
        var reduction = 14

        if let level = context.experienceLevel {
            switch level {
            case .debutant: reduction += 0
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
            reduction += 8
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

    func monthlySecondLine(for context: OnboardingEstimationContext, projectedDate: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        guard let oneMonthLater = calendar.date(byAdding: .month, value: 1, to: now) else {
            return "tu progresseras à ton rythme"
        }

        let totalDays = max(1, calendar.dateComponents([.day], from: now, to: projectedDate).day ?? 30)
        let daysInMonth = max(1, calendar.dateComponents([.day], from: now, to: oneMonthLater).day ?? 30)

        if context.hasWeightGoal,
           let current = context.currentWeight,
           let ideal = context.idealWeight,
           let goal = context.weightGoal {
            let totalDifference = abs(ideal - current)
            let monthlyProgress = (totalDifference * Double(daysInMonth)) / Double(totalDays)
            let monthlyWeight = String(format: "%.1f", monthlyProgress)

            if goal == .lose {
                return "tu vas perdre \(monthlyWeight) kg en un mois"
            }
            if goal == .gain {
                return "tu vas prendre \(monthlyWeight) kg en un mois"
            }
            return "tu vas progresser de \(monthlyWeight) kg en un mois"
        }

        let progressPercentage = min(100, (Double(daysInMonth) / Double(totalDays)) * 100)
        return "tu progresseras de \(String(format: "%.0f", progressPercentage))% en un mois"
    }
}
