import Foundation

/// Durée personnalisée du Protocole Origine (fourchette + calendrier réel).
struct OriginPlanDuration: Equatable {
    let minWeeks: Int
    let maxWeeks: Int
    let totalWeeks: Int

    var rangeLabel: String { "\(minWeeks) à \(maxWeeks) semaines" }

    var headlineLabel: String { "Protocole Origine — \(totalWeeks) semaines" }

    /// Bornes de phase pour le calendrier (fin inclusive de chaque phase).
    var phaseEnds: (p1: Int, p2: Int, p3: Int) {
        let p1 = max(2, Int((Double(totalWeeks) * 0.25).rounded()))
        let p2 = min(totalWeeks, p1 + max(2, Int((Double(totalWeeks) * 0.25).rounded())))
        let p3 = min(totalWeeks, p2 + max(3, Int((Double(totalWeeks) * 0.35).rounded())))
        return (p1, p2, max(p3, p2 + 1))
    }

    static func compute(from answers: [String: WelcomePlanAnswer]) -> OriginPlanDuration {
        var minW = 8
        var maxW = 12

        let consistency = answers["consistency_history"]?.choiceIds.first
        let bodyFat = answers["body_fat_feel"]?.choiceIds.first
        let concernCount = answers["face_concerns"]?.choiceIds.count ?? 0
        let sleepQuality = answers["sleep_quality"]?.choiceIds.first ?? ""
        let processed = answers["processed_food"]?.choiceIds.first

        switch consistency {
        case "weeks":
            minW += 2
            maxW += 4
        case "first_time":
            minW += 2
            maxW += 3
        case "long":
            if bodyFat == "athletic" || bodyFat == "very_lean" {
                minW = max(6, minW - 1)
                maxW = max(minW + 3, maxW - 2)
            }
        default:
            break
        }

        if bodyFat == "soft" || bodyFat == "high" {
            minW += 1
            maxW += 2
        }
        if concernCount >= 3 {
            maxW += 2
        }
        if sleepQuality.contains("Mauvais") || sleepQuality.contains("mauvais") {
            minW += 1
            maxW += 2
        }
        if processed == "daily" || processed == "most_meals" {
            minW += 1
            maxW += 2
        }

        minW = min(max(6, minW), 16)
        maxW = min(max(minW + 2, maxW), 20)

        let totalWeeks = min(maxW, max(minW, (minW + maxW + 1) / 2))

        return OriginPlanDuration(minWeeks: minW, maxWeeks: maxW, totalWeeks: totalWeeks)
    }

    static func weeksRangeLabel(from start: Int, through end: Int) -> String {
        if start >= end { return "Semaine \(start)" }
        return "Semaines \(start)–\(end)"
    }
}
