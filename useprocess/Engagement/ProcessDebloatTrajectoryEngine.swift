import Foundation

/// Calculs purs — score comportement, scan, verdict, streak, tendance.
enum ProcessDebloatTrajectoryEngine {

    static let behaviorWeights: [String: Double] = [
        EveningCheckInQuestionID.water: 0.35,
        EveningCheckInQuestionID.debloatMeal: 0.40,
        EveningCheckInQuestionID.cardio: 0.25
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
        if !record.checkInSubmitted {
            return unsubmittedVerdict(for: record.dayKey, now: now)
        }

        let effectiveScan = scanScore ?? 0.5
        let validated = countsAsValidatedDay(
            record: record,
            consecutiveCardioMissesBefore: consecutiveCardioMissesBefore
        )

        if !validated {
            if record.water != true || record.debloatMeal != true {
                return .regression
            }
            if record.cardio != true,
               consecutiveCardioMissesBefore + 1 >= ProcessDebloatValidation.consecutiveCardioMissLimit {
                return .regression
            }
            return .partial
        }

        if record.water == true, record.debloatMeal == true, record.cardio == true,
           behaviorScore(from: record) >= 0.9, effectiveScan >= 0.55 {
            return .excellent
        }

        return .onTrack
    }

    static func unsubmittedVerdict(for dayKey: String, now: Date = Date()) -> DebloatDayVerdict {
        guard let date = date(from: dayKey) else { return .missed }
        if ProcessEveningCheckInSchedule.isOverdue(for: date, now: now) {
            return .missed
        }
        return .pending
    }

    private static func behaviorScore(from record: DebloatDayRecord) -> Double {
        var answers: [String: String] = [:]
        if let water = record.water { answers[EveningCheckInQuestionID.water] = water ? "yes" : "no" }
        if let meal = record.debloatMeal { answers[EveningCheckInQuestionID.debloatMeal] = meal ? "yes" : "no" }
        if let cardio = record.cardio { answers[EveningCheckInQuestionID.cardio] = cardio ? "yes" : "no" }
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

    static func currentStreak(
        from records: [DebloatDayRecord],
        today: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Int {
        let todayKey = ProcessStreakStore.dayKey(for: today, calendar: calendar)
        let recordsByKey = Dictionary(uniqueKeysWithValues: records.map { ($0.dayKey, $0) })

        if let todayRecord = recordsByKey[todayKey],
           todayRecord.countsAsValidatedDay(
            consecutiveCardioMissesBefore: ProcessDebloatValidation.consecutiveCardioMisses(
                before: todayKey,
                in: recordsByKey
            )
           ) {
            return todayRecord.streakAfterDay
        }

        // Most recent prior day only — never walk the calendar unbounded (empty /
        // unvalidated-today histories used to spin forever on MainActor).
        guard let latestPriorKey = recordsByKey.keys.filter({ $0 < todayKey }).max(),
              let record = recordsByKey[latestPriorKey] else {
            return 0
        }
        return record.streakAfterDay
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
                return "Protocole debloat complet — visage moins gonflé, électrolytes et cardio OK."
            }
            return "Protocole debloat complet — hydratation, repas Na/K/Mg et cardio validés (\(Int(compositeScore))%)."
        case .onTrack:
            if record.cardio == true {
                return "Journée validée — eau, alimentation debloat et cardio OK."
            }
            return "Journée validée — eau et repas debloat OK. Pense au cardio (min. 3/sem)."
        case .partial:
            return "Journée partielle — hydratation et repas debloat requis pour valider."
        case .regression:
            return "Régression — protocole debloat incomplet (eau + repas + cardio)."
        case .pending:
            return "Bilan du soir en attente — valide ce soir pour compter la journée."
        case .missed:
            return "Bilan non validé — ta trajectoire est en pause ce jour-là."
        case .paused:
            return "Jour en pause — compteur gelé."
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
