import Foundation

/// Règles debloat — hydratation + alimentation (Na/K/Mg).
enum ProcessDebloatValidation {

    static let weeklyCardioMinimum = 3
    static let consecutiveCardioMissLimit = 3

    enum Failure: Equatable {
        case notSubmitted
        case missingHydration
        case missingNutrition
        case cardioSlump(consecutiveDays: Int)
        case weeklyCardioDeficit(sessions: Int)
    }

    // MARK: - Validation jour

    static func countsAsValidatedDay(
        record: DebloatDayRecord,
        consecutiveCardioMissesBefore: Int
    ) -> Bool {
        _ = consecutiveCardioMissesBefore
        guard record.checkInSubmitted else { return false }
        return record.water == true && record.debloatMeal == true
    }

    static func failure(for record: DebloatDayRecord, consecutiveCardioMissesBefore: Int) -> Failure? {
        _ = consecutiveCardioMissesBefore
        guard record.checkInSubmitted else { return .notSubmitted }
        if record.water != true { return .missingHydration }
        if record.debloatMeal != true { return .missingNutrition }
        return nil
    }

    static func failureMessage(_ failure: Failure) -> String {
        switch failure {
        case .notSubmitted:
            return AppCopy.tSync(
                "Check non validé — ta trajectoire est en pause ce jour-là.",
                en: "Check-in not validated — your trajectory is paused for that day."
            )
        case .missingHydration:
            return AppCopy.tSync(
                "Hydratation manquante — objectif eau non atteint, jour non validé.",
                en: "Hydration missing — water goal not met, day not validated."
            )
        case .missingNutrition:
            return AppCopy.tSync(
                "Alimentation debloat manquante — équilibre Na/K/Mg requis pour valider.",
                en: "Debloat nutrition missing — Na/K/Mg balance required to validate."
            )
        case .cardioSlump(let days):
            return AppCopy.tSync(
                "Marche inclinée absente \(days) jours d'affilée — minimum 3/semaine. Relance une séance.",
                en: "No incline walk for \(days) days in a row — minimum 3/week. Start a session."
            )
        case .weeklyCardioDeficit(let sessions):
            return AppCopy.tSync(
                "Marche inclinée insuffisante cette semaine (\(sessions)/\(weeklyCardioMinimum)).",
                en: "Not enough incline walks this week (\(sessions)/\(weeklyCardioMinimum))."
            )
        }
    }

    // MARK: - Cardio tracking

    /// Jours consécutifs sans cardio validé avant `dayKey` (bilan soumis, cardio ≠ oui).
    static func consecutiveCardioMisses(before dayKey: String, in records: [String: DebloatDayRecord]) -> Int {
        let sorted = records.keys.sorted()
        guard let index = sorted.firstIndex(of: dayKey) else { return 0 }

        var count = 0
        var cursor = index - 1
        while cursor >= 0 {
            let key = sorted[cursor]
            guard let record = records[key], record.checkInSubmitted else { break }
            if record.cardio == true { break }
            count += 1
            cursor -= 1
        }
        return count
    }

    /// Cardio validé sur les `dayCount` derniers jours avec bilan soumis (inclus `dayKey`).
    static func cardioSessionsInRollingWindow(
        endingAt dayKey: String,
        in records: [String: DebloatDayRecord],
        dayCount: Int = 7
    ) -> Int {
        records.values
            .filter { $0.dayKey <= dayKey && $0.checkInSubmitted }
            .sorted { $0.dayKey > $1.dayKey }
            .prefix(dayCount)
            .filter { $0.cardio == true }
            .count
    }

    static func isWeeklyCardioDeficit(
        endingAt dayKey: String,
        in records: [String: DebloatDayRecord]
    ) -> Bool {
        let submittedInWindow = records.values
            .filter { $0.dayKey <= dayKey && $0.checkInSubmitted }
            .sorted { $0.dayKey > $1.dayKey }
            .prefix(7)
            .count
        guard submittedInWindow >= 4 else { return false }
        return cardioSessionsInRollingWindow(endingAt: dayKey, in: records) < weeklyCardioMinimum
    }
}
