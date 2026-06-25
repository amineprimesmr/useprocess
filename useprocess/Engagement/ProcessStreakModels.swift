import Foundation

struct ProcessStreakState: Codable, Equatable {
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
    let week: [ProcessStreakDaySnapshot]
    let month: [ProcessStreakDaySnapshot]
    let nextMilestone: ProcessStreakMilestone?
    let daysUntilNextMilestone: Int?

    var headline: String {
        switch currentStreak {
        case 0 where isTodayComplete:
            return "Streak lancé — reviens demain."
        case 0:
            return "Complète ta checklist pour lancer ta streak."
        case 1:
            return "Bien joué. Enchaîne demain."
        case 2..<7:
            return "Tu construis l’habitude."
        case 7..<30:
            return "Streak solide — ne lâche pas."
        default:
            return "Tu es en mode Process."
        }
    }
}
