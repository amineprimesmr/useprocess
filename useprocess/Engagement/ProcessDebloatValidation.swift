import Foundation

/// Règles debloat — hydratation + alimentation (Na/K/Mg) + cardio.
/// Cardio : minimum 3 séances / semaine · 3 jours d'affilée sans cardio = blocage + pénalité.
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
        guard record.checkInSubmitted else { return false }
        guard record.water == true, record.debloatMeal == true else { return false }

        if record.cardio == true { return true }

        let projectedMisses = consecutiveCardioMissesBefore + 1
        return projectedMisses < consecutiveCardioMissLimit
    }

    static func failure(for record: DebloatDayRecord, consecutiveCardioMissesBefore: Int) -> Failure? {
        guard record.checkInSubmitted else { return .notSubmitted }
        if record.water != true { return .missingHydration }
        if record.debloatMeal != true { return .missingNutrition }

        if record.cardio != true {
            let projected = consecutiveCardioMissesBefore + 1
            if projected >= consecutiveCardioMissLimit {
                return .cardioSlump(consecutiveDays: projected)
            }
        }
        return nil
    }

    static func failureMessage(_ failure: Failure) -> String {
        switch failure {
        case .notSubmitted:
            return "Check non validé — ta trajectoire est en pause ce jour-là."
        case .missingHydration:
            return "Hydratation manquante — objectif eau non atteint, jour non validé."
        case .missingNutrition:
            return "Alimentation debloat manquante — équilibre Na/K/Mg requis pour valider."
        case .cardioSlump(let days):
            return "Marche inclinée absente \(days) jours d'affilée — minimum 3/semaine. Relance une séance."
        case .weeklyCardioDeficit(let sessions):
            return "Marche inclinée insuffisante cette semaine (\(sessions)/\(weeklyCardioMinimum))."
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
