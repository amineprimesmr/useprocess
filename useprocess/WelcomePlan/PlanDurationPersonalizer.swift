import Foundation

// MARK: - Trajectory mode

/// Ordre debloat / poids selon le profil composition corporelle.
enum TrajectoryMode: String, Codable, Equatable {
    case debloatFirst
    case weightFirst

    var label: String {
        switch self {
        case .debloatFirst: return "Debloat puis poids"
        case .weightFirst: return "Poids puis debloat"
        }
    }
}

struct TrajectoryMilestone: Equatable {
    let id: String
    let label: String
    let dayOffset: Int
    let fraction: Double
    let date: Date
}

struct TrajectoryTimeline: Equatable {
    let mode: TrajectoryMode
    let debloatDays: Int
    let weightDays: Int?
    let totalDays: Int
    let endDate: Date
    let milestones: [TrajectoryMilestone]
    let headlineDate: Date
    let headlineCaption: String
    let summaryLine: String

    var debloatMilestone: TrajectoryMilestone? {
        milestones.first { $0.id == "debloat" }
    }

    var weightMilestone: TrajectoryMilestone? {
        milestones.first { $0.id == "weight" }
    }

    var planPhaseOneDays: Int { debloatDays }

    var planTotalDays: Int { totalDays }
}

/// Logique partagée : durée optimiste, debloat visage prioritaire.
enum PlanDurationPersonalizer {

    struct ProfileSignals: Equatable {
        let weightGapKg: Double?
        let bmi: Double?
        let bodyFatGap: Double?
        let isLean: Bool
        let isSporty: Bool
        let isDebloatFocused: Bool
        let inferredBodyFatFeel: String?
        let primaryFocus: OnboardingPrimaryFocus?
        let age: Int?
    }

    /// Plafond dur : 8 semaines pour jeunes actifs avec écart modéré.
    static let youngSportyMaxDays = 56
    static let moderateGapMaxDays = 60
    static let globalMaxDays = 84

    // MARK: - Profil

    static func signals(
        profile: UnifiedUserProfile?,
        answers: [String: WelcomePlanAnswer] = [:],
        bodyFatGap: Double? = nil
    ) -> ProfileSignals {
        let bmi = OriginUserAssessment.computeBMI(height: profile?.height, weight: profile?.weight)
        let weightGap = weightGapKg(profile: profile)
        let feel = answers["body_fat_feel"]?.choiceIds.first
            ?? inferredBodyFatFeel(profile: profile, bmi: bmi)

        return ProfileSignals(
            weightGapKg: weightGap,
            bmi: bmi,
            bodyFatGap: bodyFatGap,
            isLean: (bmi ?? 25) < 24.5,
            isSporty: isSportyProfile(profile: profile),
            isDebloatFocused: isDebloatFocused(profile: profile, answers: answers),
            inferredBodyFatFeel: feel,
            primaryFocus: profile?.onboardingPrimaryFocus,
            age: profile?.age
        )
    }

    static func signals(from context: OnboardingEstimationContext) -> ProfileSignals {
        let bmi = OriginUserAssessment.computeBMI(height: context.height, weight: context.currentWeight)
        let weightGap: Double?
        if context.hasWeightGoal,
           let current = context.currentWeight,
           let ideal = context.idealWeight {
            let gap = abs(current - ideal)
            weightGap = gap >= 0.5 ? gap : nil
        } else {
            weightGap = nil
        }

        var isSporty = !context.selectedSports.isEmpty
        if let level = context.experienceLevel {
            switch level {
            case .amateur, .professionnel, .intermediaire:
                isSporty = true
            default:
                break
            }
        }
        if context.trainingFrequency == "3-5" || context.trainingFrequency == "6+" {
            isSporty = true
        }

        let bodyFatGap = estimatedBodyFatGap(
            height: context.height,
            weight: context.currentWeight,
            age: context.age,
            gender: context.gender ?? .male,
            bmi: bmi,
            isSporty: isSporty
        )

        return ProfileSignals(
            weightGapKg: weightGap,
            bmi: bmi,
            bodyFatGap: bodyFatGap,
            isLean: (bmi ?? 25) < 24.5,
            isSporty: isSporty,
            isDebloatFocused: true,
            inferredBodyFatFeel: inferredBodyFatFeel(
                profile: nil,
                bmi: bmi,
                forceSporty: isSporty
            ),
            primaryFocus: nil,
            age: context.age
        )
    }

    static func trajectoryMode(for signals: ProfileSignals) -> TrajectoryMode {
        let bmi = signals.bmi ?? 25
        let bodyFatGap = signals.bodyFatGap ?? 0
        let weightGap = signals.weightGapKg ?? 0
        let age = signals.age ?? 30

        if bmi >= 30 || bodyFatGap >= 12 || weightGap > 15 {
            return .weightFirst
        }
        if bmi >= 29 && weightGap > 12 && age > 35 {
            return .weightFirst
        }
        return .debloatFirst
    }

    // MARK: - Timeline (parallèle & optimiste)

    static func computeTimeline(
        signals: ProfileSignals,
        weightDays: Int?,
        debloatDays: Int,
        hasWeightGoal: Bool,
        weightLabel: String?,
        now: Date = Date()
    ) -> TrajectoryTimeline {
        let calendar = Calendar.current
        let mode = trajectoryMode(for: signals)
        let cap = optimisticTimelineCap(signals: signals)

        let debloatOffset = min(debloatDays, cap)
        let weightOffset = weightDays.map { min($0, cap) }

        let totalDays: Int
        if hasWeightGoal, let weightOffset {
            totalDays = min(cap, max(debloatOffset, weightOffset))
        } else {
            totalDays = debloatOffset
        }

        var items: [TrajectoryMilestone] = [
            milestone(
                id: "debloat",
                label: "Debloat",
                dayOffset: debloatOffset,
                totalDays: totalDays,
                now: now,
                calendar: calendar
            )
        ]

        if hasWeightGoal, let label = weightLabel, let weightOffset {
            items.append(
                milestone(
                    id: "weight",
                    label: label,
                    dayOffset: weightOffset,
                    totalDays: totalDays,
                    now: now,
                    calendar: calendar
                )
            )
        }

        let milestones = items.sorted { $0.fraction < $1.fraction }
        let endDate = calendar.date(byAdding: .day, value: totalDays, to: now) ?? now
        let debloatDate = milestones.first { $0.id == "debloat" }?.date ?? endDate

        let summary: String
        let debloatFmt = formatShortDate(debloatDate)
        if hasWeightGoal, let weight = weightLabel {
            summary = "Profil jeune et actif — visage dégonflé d'ici \(debloatFmt), \(weight) sur la trajectoire."
        } else {
            summary = "Visage visiblement moins gonflé d'ici \(debloatFmt) — trajectoire optimiste calibrée sur ton profil."
        }

        return TrajectoryTimeline(
            mode: mode,
            debloatDays: debloatOffset,
            weightDays: weightOffset,
            totalDays: totalDays,
            endDate: endDate,
            milestones: milestones,
            headlineDate: debloatDate,
            headlineCaption: "Debloat",
            summaryLine: summary
        )
    }

    static func debloatDays(
        signals: ProfileSignals,
        habitSeverity: Int = 30
    ) -> Int {
        let age = signals.age ?? 28
        let gap = signals.weightGapKg ?? 99
        var days: Int

        if signals.isLean && signals.isSporty {
            days = 10
        } else if signals.isSporty && gap <= 10 {
            days = 14
        } else if signals.isLean {
            days = 14
        } else if (signals.bmi ?? 25) >= 29 {
            days = 24
        } else {
            days = 18
        }

        if age <= 22 { days = max(10, days - 3) }
        else if age <= 28 { days = max(10, days - 2) }

        if signals.isSporty { days = max(10, days - 2) }

        if habitSeverity >= 50 { days += 3 }
        else if habitSeverity >= 35 { days += 2 }

        return max(10, min(days, 28))
    }

    static func optimisticTimelineCap(signals: ProfileSignals) -> Int {
        let age = signals.age ?? 30
        let gap = signals.weightGapKg ?? 99
        let bmi = signals.bmi ?? 25

        if age <= 28 && signals.isSporty && gap <= 10 && bmi < 29 {
            return youngSportyMaxDays
        }
        if age <= 32 && gap <= 8 {
            return moderateGapMaxDays
        }
        if gap <= 6 {
            return 49
        }
        if gap <= 10 {
            return 63
        }
        return globalMaxDays
    }

    static func weightGapWeekCap(weightGap: Double?, signals: ProfileSignals) -> Int? {
        guard let gap = weightGap else { return nil }

        let baseCap: Int
        switch gap {
        case ...3:
            baseCap = 3
        case ...5:
            baseCap = signals.isSporty ? 4 : 5
        case ...8:
            baseCap = signals.isSporty ? 5 : 6
        case ...12:
            baseCap = 7
        default:
            baseCap = 10
        }

        if signals.isSporty, (signals.age ?? 30) <= 28 {
            return max(3, baseCap - 1)
        }
        return baseCap
    }

    static func pickTotalWeeks(minW: Int, maxW: Int, signals: ProfileSignals, phaseOneDays: Int) -> Int {
        let fromPhase = max(1, Int(ceil(Double(phaseOneDays) / 7.0)))
        let gap = signals.weightGapKg ?? 99
        let age = signals.age ?? 30
        let aggressive = signals.isSporty && gap <= 10 && age <= 32

        if aggressive {
            return min(fromPhase, minW, Int(ceil(Double(optimisticTimelineCap(signals: signals)) / 7.0)))
        }
        return min(maxW, max(minW, min(fromPhase, (minW + maxW + 1) / 2)))
    }

    static func sportWeekReduction(signals: ProfileSignals) -> Int {
        guard signals.isSporty else { return 0 }
        let age = signals.age ?? 30
        if age <= 28 && (signals.weightGapKg ?? 99) <= 10 { return 2 }
        if (signals.weightGapKg ?? 99) <= 6 { return 1 }
        return 0
    }

    // MARK: - Onboarding weight days (optimiste)

    static func onboardingWeightGoalDays(
        delta: Double,
        weeklyRate: Double,
        signals: ProfileSignals
    ) -> Int {
        let age = signals.age ?? 28
        var rate = weeklyRate

        if age <= 22 { rate *= 1.22 }
        else if age <= 28 { rate *= 1.14 }
        else if age <= 32 { rate *= 1.08 }

        if signals.isSporty { rate *= 1.12 }
        if delta <= 6 { rate *= 1.1 }
        else if delta <= 10 { rate *= 1.06 }

        let optimisticCeiling = age <= 28 && signals.isSporty ? 1.1 : (delta <= 8 ? 1.0 : 0.9)
        rate = min(max(rate, 0.5), optimisticCeiling)

        var days = Int(ceil(delta / rate)) * 7

        if delta <= 4 {
            days = max(days, age <= 28 && signals.isSporty ? 14 : 21)
        } else if delta <= 8 {
            days = max(days, age <= 28 && signals.isSporty ? 28 : 35)
        } else if delta <= 12 {
            days = max(days, 42)
        }

        days = min(days, optimisticTimelineCap(signals: signals))
        return max(10, days)
    }

    // MARK: - Helpers

    static func weightGapKg(profile: UnifiedUserProfile?) -> Double? {
        guard let current = profile?.weight, current > 0,
              let ideal = profile?.idealWeight, ideal > 0 else { return nil }
        let gap = abs(current - ideal)
        guard gap >= 0.5 else { return nil }
        return gap
    }

    static func isSportyProfile(profile: UnifiedUserProfile?) -> Bool {
        guard let profile else { return false }
        if (profile.sessionsPerWeek ?? 0) >= 3 { return true }
        if !profile.sports.isEmpty { return true }
        if let level = profile.experienceLevel {
            switch level {
            case .amateur, .professionnel, .intermediaire:
                return true
            default:
                break
            }
        }
        return false
    }

    static func isDebloatFocused(
        profile: UnifiedUserProfile?,
        answers: [String: WelcomePlanAnswer]
    ) -> Bool {
        if profile?.onboardingPrimaryFocus == .face { return true }
        if profile?.weightGoal == .lose,
           let gap = weightGapKg(profile: profile),
           gap <= 12 {
            return true
        }
        let concerns = answers["face_concerns"]?.choiceIds ?? []
        return concerns.contains("puffiness") || concerns.contains("double_chin")
    }

    static func inferredBodyFatFeel(
        profile: UnifiedUserProfile?,
        bmi: Double?,
        forceSporty: Bool = false
    ) -> String? {
        guard let bmi else { return nil }
        let sporty = forceSporty || isSportyProfile(profile: profile)
        if sporty {
            if bmi < 22 { return "very_lean" }
            if bmi < 24.5 { return "athletic" }
        }
        if bmi < 21 { return "very_lean" }
        if bmi < 23.5 { return "athletic" }
        if bmi < 26 { return "normal" }
        if bmi < 29 { return "soft" }
        return "high"
    }

    static func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private static func estimatedBodyFatGap(
        height: Double?,
        weight: Double?,
        age: Int,
        gender: Gender,
        bmi: Double?,
        isSporty: Bool
    ) -> Double {
        let estimated = OriginUserAssessment.estimateBodyFat(
            height: height,
            weight: weight,
            age: age,
            gender: gender,
            subjectiveFeel: isSporty && (bmi ?? 25) < 27 ? "athletic" : nil
        )
        let target = gender == .female ? 20.0 : 14.0
        return max(0, estimated - target)
    }

    private static func milestone(
        id: String,
        label: String,
        dayOffset: Int,
        totalDays: Int,
        now: Date,
        calendar: Calendar
    ) -> TrajectoryMilestone {
        let fraction = totalDays > 0
            ? min(0.98, max(0.05, Double(dayOffset) / Double(totalDays)))
            : 1
        let date = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        return TrajectoryMilestone(
            id: id,
            label: label,
            dayOffset: dayOffset,
            fraction: fraction,
            date: date
        )
    }
}
