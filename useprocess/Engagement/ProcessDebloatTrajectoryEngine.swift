import Foundation

/// Identifiants des leviers debloat suivis (ex-checklist bilan du soir) — utilisés pour scorer les records historiques.
enum EveningCheckInQuestionID {
    static let water = "water"
    static let debloatMeal = "debloatMeal"
    static let cardio = "cardio"
    static let morningRoutine = "morningRoutine"
    static let legacyPostureCircuit = "postureCircuit"

    static let debloatLevers: [String] = [water, debloatMeal]
    static let all: [String] = [morningRoutine] + debloatLevers
}

/// Calculs purs — score comportement, scan, verdict, streak, tendance.
enum ProcessDebloatTrajectoryEngine {

    static let behaviorWeights: [String: Double] = [
        EveningCheckInQuestionID.water: 0.45,
        EveningCheckInQuestionID.debloatMeal: 0.55
    ]

    // MARK: - Scores

    static func behaviorScore(from answers: [String: String]) -> Double {
        behaviorWeights.reduce(0) { partial, entry in
            partial + (answers[entry.key] == "yes" ? entry.value : 0)
        }
    }

    static func yesCount(from answers: [String: String]) -> Int {
        EveningCheckInQuestionID.debloatLevers.filter { answers[$0] == "yes" }.count
    }

    static func countsAsValidatedDay(
        record: DebloatDayRecord,
        consecutiveCardioMissesBefore: Int
    ) -> Bool {
        ProcessDebloatValidation.countsAsValidatedDay(
            record: record,
            consecutiveCardioMissesBefore: consecutiveCardioMissesBefore
        )
    }

    static func scanScore(
        relativeFaceScore: Int?,
        puffinessDelta: Int?
    ) -> Double? {
        guard let relativeFaceScore else { return nil }
        let puffiness = Double(puffinessDelta ?? 0)
        let relative = Double(relativeFaceScore) / 100.0
        let puffinessComponent = max(0, min(1, 1.0 - puffiness / 20.0))
        return max(0, min(1, relative * 0.55 + puffinessComponent * 0.45))
    }

    static func rollingScanScore(from records: [DebloatDayRecord], before dayKey: String) -> Double? {
        let sorted = records
            .filter { $0.dayKey < dayKey && $0.scanScore != nil }
            .sorted { $0.dayKey > $1.dayKey }
        let recent = sorted.prefix(7).compactMap(\.scanScore)
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }

    static func compositeScore(
        behaviorScore: Double,
        scanScore: Double?,
        momentumStreak: Int
    ) -> Double {
        let effectiveScan = scanScore ?? 0.5
        let momentumBonus = min(Double(momentumStreak) * 0.5, 10.0)
        return max(0, min(100, behaviorScore * 40 + effectiveScan * 40 + momentumBonus))
    }

    // MARK: - Verdict

    static func verdict(
        record: DebloatDayRecord,
        consecutiveCardioMissesBefore: Int,
        scanScore: Double?,
        isPaused: Bool,
        now: Date = Date()
    ) -> DebloatDayVerdict {
        if isPaused { return .paused }
        if !record.hasScan {
            return unsubmittedVerdict(for: record.dayKey, now: now)
        }

        let effectiveScan = scanScore ?? 0.5
        if effectiveScan >= 0.55 {
            return .excellent
        }
        return .onTrack
    }

    static func unsubmittedVerdict(for dayKey: String, now: Date = Date()) -> DebloatDayVerdict {
        guard let date = date(from: dayKey) else { return .missed }
        let calendar = Calendar.current
        if calendar.startOfDay(for: date) < calendar.startOfDay(for: now) {
            return .missed
        }
        return .pending
    }

    private static func behaviorScore(from record: DebloatDayRecord) -> Double {
        var answers: [String: String] = [:]
        if let water = record.water { answers[EveningCheckInQuestionID.water] = water ? "yes" : "no" }
        if let meal = record.debloatMeal { answers[EveningCheckInQuestionID.debloatMeal] = meal ? "yes" : "no" }
        return behaviorScore(from: answers)
    }

    // MARK: - Streak

    static func graceAvailable(
        graceUsedDayKeys: Set<String>,
        for dayKey: String,
        calendar: Calendar = .current
    ) -> Bool {
        guard let date = date(from: dayKey, calendar: calendar) else { return false }
        guard let windowStart = calendar.date(byAdding: .day, value: -30, to: date) else { return false }
        let windowStartKey = ProcessStreakStore.dayKey(for: windowStart, calendar: calendar)

        let usedInWindow = graceUsedDayKeys.contains { usedKey in
            usedKey >= windowStartKey && usedKey <= dayKey
        }
        return !usedInWindow
    }

    static func applyStreakTransition(
        previousStreak: Int,
        consecutiveMisses: Int,
        verdict: DebloatDayVerdict,
        graceAvailable: Bool
    ) -> (streak: Int, consecutiveMisses: Int, graceUsed: Bool) {
        switch verdict {
        case .paused, .pending:
            return (previousStreak, consecutiveMisses, false)

        case .excellent, .onTrack:
            return (previousStreak + 1, 0, false)

        case .partial:
            return (previousStreak, 0, false)

        case .regression:
            return (max(0, previousStreak - 1), 0, false)

        case .missed:
            let misses = consecutiveMisses + 1
            if misses >= 2 {
                return (0, misses, false)
            }
            return (max(0, previousStreak - 1), misses, false)
        }
    }

    static func applyCardioMissTransition(
        previousMisses: Int,
        record: DebloatDayRecord
    ) -> Int {
        guard record.checkInSubmitted else { return previousMisses }
        if record.cardio == true { return 0 }
        return previousMisses + 1
    }

    // MARK: - Tendance

    static func trajectoryTrend(for points: [DebloatTrajectoryPoint]) -> TrajectoryTrend {
        guard points.count >= 3 else { return .unknown }
        let slope = velocitySlope(for: points)
        if slope > 2.5 { return .accelerating }
        if slope < -2.5 { return .regressing }
        return .stable
    }

    static func velocitySlope(for points: [DebloatTrajectoryPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        let recent = Array(points.suffix(min(7, points.count)))
        guard let first = recent.first, let last = recent.last else { return 0 }
        let daySpan = max(
            Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1,
            1
        )
        return (last.compositeScore - first.compositeScore) / Double(daySpan)
    }

    static func aiSummary(
        record: DebloatDayRecord,
        consecutiveCardioMissesBefore: Int,
        compositeScore: Double,
        puffinessDelta: Int?
    ) -> String {
        if let failure = ProcessDebloatValidation.failure(
            for: record,
            consecutiveCardioMissesBefore: consecutiveCardioMissesBefore
        ) {
            switch failure {
            case .notSubmitted:
                break
            default:
                return ProcessDebloatValidation.failureMessage(failure)
            }
        }

        switch record.verdict {
        case .excellent:
            if let delta = puffinessDelta, delta <= -4 {
                return AppCopy.tSync(
                    "Protocole debloat complet — visage moins gonflé, électrolytes et cardio OK.",
                    en: "Full debloat protocol — less puffy face, electrolytes and cardio OK."
                )
            }
            return AppCopy.tSync(
                "Protocole debloat complet — hydratation, repas Na/K/Mg et cardio validés (\(Int(compositeScore))%).",
                en: "Full debloat protocol — hydration, Na/K/Mg meals and cardio validated (\(Int(compositeScore))%)."
            )
        case .onTrack:
            if record.cardio == true {
                return AppCopy.tSync(
                    "Journée validée — eau, alimentation debloat et cardio OK.",
                    en: "Day validated — water, debloat nutrition and cardio OK."
                )
            }
            return AppCopy.tSync(
                "Journée validée — eau et repas debloat OK. Pense au cardio (min. 3/sem).",
                en: "Day validated — water and debloat meals OK. Don't forget cardio (min. 3/week)."
            )
        case .partial:
            return AppCopy.tSync(
                "Journée partielle — hydratation et repas debloat requis pour valider.",
                en: "Partial day — hydration and debloat meals required to validate."
            )
        case .regression:
            return AppCopy.tSync(
                "Régression — protocole debloat incomplet (eau + repas + cardio).",
                en: "Regression — incomplete debloat protocol (water + meals + cardio)."
            )
        case .pending:
            return AppCopy.tSync(
                "Check du jour en attente — valide-le pour compter la journée.",
                en: "Today's check-in pending — validate it to count the day."
            )
        case .missed:
            return AppCopy.tSync(
                "Check non validé — ta trajectoire est en pause ce jour-là.",
                en: "Check-in not validated — your trajectory is paused for that day."
            )
        case .paused:
            return AppCopy.tSync(
                "Jour en pause — compteur gelé.",
                en: "Day paused — streak frozen."
            )
        }
    }

    // MARK: - Helpers

    static func date(from dayKey: String, calendar: Calendar = .current) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
            .map { calendar.startOfDay(for: $0) }
    }

    static func boolAnswer(_ answers: [String: String], key: String) -> Bool? {
        if let raw = answers[key] { return raw == "yes" }
        if key == EveningCheckInQuestionID.cardio,
           let legacy = answers["postureCircuit"] {
            return legacy == "yes"
        }
        return nil
    }
}
