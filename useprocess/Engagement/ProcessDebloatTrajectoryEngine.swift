import Foundation

/// Calculs purs — score comportement, scan, verdict, streak, tendance.
enum ProcessDebloatTrajectoryEngine {

    static let behaviorWeights: [String: Double] = [
        EveningCheckInQuestionID.water: 0.35,
        EveningCheckInQuestionID.debloatMeal: 0.40,
        EveningCheckInQuestionID.postureCircuit: 0.25
    ]

    // MARK: - Scores

    static func behaviorScore(from answers: [String: String]) -> Double {
        behaviorWeights.reduce(0) { partial, entry in
            partial + (answers[entry.key] == "yes" ? entry.value : 0)
        }
    }

    static func yesCount(from answers: [String: String]) -> Int {
        EveningCheckInQuestionID.all.filter { answers[$0] == "yes" }.count
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
        behaviorScore: Double,
        yesCount: Int,
        scanScore: Double?,
        isPaused: Bool,
        checkInSubmitted: Bool
    ) -> DebloatDayVerdict {
        if isPaused { return .paused }
        if !checkInSubmitted { return .missed }

        let effectiveScan = scanScore ?? 0.5

        if yesCount == 0 {
            return .regression
        }
        if behaviorScore >= 0.9 && effectiveScan >= 0.55 {
            return .excellent
        }
        if behaviorScore >= 0.55 {
            return .onTrack
        }
        if yesCount >= 1 {
            return .partial
        }
        return .regression
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
        case .paused:
            return (previousStreak, 0, false)

        case .excellent, .onTrack, .partial:
            return (previousStreak + 1, 0, false)

        case .regression:
            return (max(0, previousStreak - 3), 0, false)

        case .missed:
            if graceAvailable {
                return (previousStreak + 1, 0, true)
            }
            let misses = consecutiveMisses + 1
            if misses >= 2 {
                return (0, misses, false)
            }
            return (max(0, previousStreak - 5), misses, false)
        }
    }

    static func currentStreak(from records: [DebloatDayRecord], today: Date, calendar: Calendar = .current) -> Int {
        let todayKey = ProcessStreakStore.dayKey(for: today, calendar: calendar)
        if let todayRecord = records.first(where: { $0.dayKey == todayKey }) {
            return todayRecord.streakAfterDay
        }

        var cursor = today
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = calendar.startOfDay(for: yesterday)
        }
        let key = ProcessStreakStore.dayKey(for: cursor, calendar: calendar)
        return records.first(where: { $0.dayKey == key })?.streakAfterDay ?? 0
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
        verdict: DebloatDayVerdict,
        yesCount: Int,
        compositeScore: Double,
        puffinessDelta: Int?
    ) -> String {
        switch verdict {
        case .excellent:
            if let delta = puffinessDelta, delta <= -4 {
                return "Journée excellente — visage moins gonflé, protocole bien exécuté."
            }
            return "Journée excellente — protocole debloat respecté à \(Int(compositeScore))%."
        case .onTrack:
            return "Sur la bonne voie — \(yesCount)/3 leviers validés."
        case .partial:
            return "Journée partielle — \(yesCount)/3. Serre l'hydratation ou le repas debloat demain."
        case .regression:
            return "Régression — 0 ou 1 levier sur 3. Le visage peut stagner 2–4 jours avant la balance."
        case .missed:
            return "Bilan non validé — ta trajectoire est en pause ce jour-là."
        case .paused:
            return "Jour en pause — streak gelée."
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
        guard let raw = answers[key] else { return nil }
        return raw == "yes"
    }
}
