import Foundation
import SwiftUI

struct ProcessStreakState: nonisolated Codable, Equatable, Sendable {
    var completedDayKeys: Set<String> = []
    var longestStreak: Int = 0
}

struct ProcessStreakDaySnapshot: Identifiable, Equatable {
    let id: String
    let date: Date
    let weekdaySymbol: String
    let isComplete: Bool
    let isToday: Bool
    let isFuture: Bool
    var verdict: DebloatDayVerdict?
    var compositeScore: Double?

    var dayOfMonth: Int {
        Calendar.current.component(.day, from: date)
    }
}

/// Jour du programme debloat — affiché dans le streak profil.
struct ProfileProgramStreakDay: Identifiable, Equatable {
    let id: Int
    let programDayNumber: Int
    let date: Date
    let isComplete: Bool
    let isToday: Bool
    let isFuture: Bool
    let isMissed: Bool

    var label: String {
        let raw = Self.weekdayLabelFormatter.string(from: date)
        let cleaned = raw
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = cleaned.first else { return raw }
        return String(first).uppercased() + cleaned.dropFirst().lowercased()
    }

    private static let weekdayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

struct ProcessStreakMilestone: Identifiable, Equatable {
    let days: Int
    let title: String
    let subtitle: String

    var id: Int { days }

    static let catalog: [ProcessStreakMilestone] = [
        .init(days: 3, title: "3 jours", subtitle: "Le déclencheur"),
        .init(days: 7, title: "7 jours", subtitle: "Une semaine solide"),
        .init(days: 14, title: "14 jours", subtitle: "Habitude ancrée"),
        .init(days: 30, title: "30 jours", subtitle: "Transformation visible"),
        .init(days: 60, title: "60 jours", subtitle: "Mode Process"),
        .init(days: 100, title: "100 jours", subtitle: "Elite debloat")
    ]
}

struct ProcessStreakSnapshot: Equatable {
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletedDays: Int
    let isTodayComplete: Bool
    let todayProgress: Double
    let calendarWeek: [ProcessStreakDaySnapshot]
    let month: [ProcessStreakDaySnapshot]
    let nextMilestone: ProcessStreakMilestone?
    let daysUntilNextMilestone: Int?
    let todayVerdict: DebloatDayVerdict?
    let todayCompositeScore: Double
    let trajectoryTrend: TrajectoryTrend
    let velocityLabel: String

    var streakTitle: String {
        switch totalCompletedDays {
        case 0: return "Jours validés"
        case 1: return "1 jour validé"
        default: return "\(totalCompletedDays) jours validés"
        }
    }

    func encouragement(firstName: String?) -> String {
        let trimmed = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nameSuffix = trimmed.isEmpty ? "" : ", \(trimmed)"

        if let verdict = todayVerdict, isTodayComplete {
            switch verdict {
            case .excellent:
                return "Journée excellente\(nameSuffix) — score \(Int(todayCompositeScore))/100."
            case .onTrack:
                return "Sur la bonne voie\(nameSuffix) — \(velocityLabel.lowercased())."
            case .partial:
                return "Journée partielle\(nameSuffix) — serre le protocole demain."
            case .regression:
                return "Régression\(nameSuffix) — on recale ta trajectoire."
            case .pending, .paused, .missed:
                break
            }
        }

        if trimmed.isEmpty { return headline }
        if totalCompletedDays >= 7 { return "Tu gères vraiment bien, \(trimmed) !" }
        if totalCompletedDays > 0 { return "Continue comme ça, \(trimmed) !" }
        if isTodayComplete { return "Bien joué \(trimmed), reviens demain." }
        return "Complète ton bilan du soir pour lancer ta trajectoire, \(trimmed)."
    }

    var headline: String {
        if let verdict = todayVerdict {
            switch verdict {
            case .excellent: return "Journée excellente — trajectoire en hausse."
            case .onTrack: return "Tu restes sur la bonne voie."
            case .partial: return "Journée partielle — serre le protocole demain."
            case .regression: return "Régression détectée — on recale ensemble."
            case .pending: return "Bilan du soir en attente — valide ce soir."
            case .missed: return "Bilan manqué — reviens ce soir."
            case .paused: return "Jour en pause — compteur gelé."
            }
        }
        switch currentStreak {
        case 0 where isTodayComplete:
            return "Premier jour validé — continue demain."
        case 0:
            return "Complète ton bilan du soir pour valider ta journée."
        case 1:
            return "Bien joué. Enchaîne demain."
        case 2..<7:
            return "Tu construis l’habitude."
        case 7..<30:
            return "Régularité solide — ne lâche pas."
        default:
            return "Tu es en mode Process."
        }
    }
}

enum ProcessStreakPalette {
    /// Bleu Pro paywall — cohérence graphique app-wide.
    static let flameGlow = Color(red: 0.52, green: 0.88, blue: 1.0)
    static let flame = Color(red: 0.34, green: 0.72, blue: 1.0)
    static let flameDeep = Color(red: 0.20, green: 0.56, blue: 0.98)

    static var flameGradient: LinearGradient {
        LinearGradient(
            colors: [flameGlow, flame, flameDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var progressGradient: LinearGradient {
        LinearGradient(
            colors: [flameGlow.opacity(0.95), flame, flameDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
