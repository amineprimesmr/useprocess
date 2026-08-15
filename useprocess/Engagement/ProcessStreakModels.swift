import Foundation
import SwiftUI

struct ProcessStreakState: nonisolated Codable, Equatable, Sendable {
    var completedDayKeys: Set<String> = []
    var longestStreak: Int = 0
}

/// Téléchargement + premier scan onboarding — la série **affichée** démarre à 1.
enum ProcessStreakLaunchPolicy {
    static func resolvedDisplayCounts(
        currentStreak: Int,
        totalValidatedDays: Int
    ) -> (current: Int, total: Int) {
        guard currentStreak == 0, totalValidatedDays == 0 else {
            return (currentStreak, totalValidatedDays)
        }
        return (1, 1)
    }
}

/// Série calendaire simple — comme Duolingo / Snapchat : 1 check = 1 jour.
enum ProcessStreakMath {
    static func currentStreak(
        submittedKeys: Set<String>,
        isPaused: (String) -> Bool = { _ in false },
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        var day = calendar.startOfDay(for: now)
        var key = ProcessStreakStore.dayKey(for: day, calendar: calendar)

        if !submittedKeys.contains(key) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previous
            key = ProcessStreakStore.dayKey(for: day, calendar: calendar)
            while isPaused(key) {
                guard let skipped = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
                day = skipped
                key = ProcessStreakStore.dayKey(for: day, calendar: calendar)
            }
            if !submittedKeys.contains(key) { return 0 }
        }

        var count = 0
        var safety = 0
        while safety < 400 {
            safety += 1
            if isPaused(key) {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = previous
                key = ProcessStreakStore.dayKey(for: day, calendar: calendar)
                continue
            }
            if !submittedKeys.contains(key) { break }
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
            key = ProcessStreakStore.dayKey(for: day, calendar: calendar)
        }
        return count
    }

    /// Série consécutive se terminant à `dayKey` (inclus), jours pause ignorés.
    static func streakEnding(
        on dayKey: String,
        submittedKeys: Set<String>,
        isPaused: (String) -> Bool = { _ in false },
        calendar: Calendar = .current
    ) -> Int {
        guard let day = ProcessDebloatTrajectoryEngine.date(from: dayKey) else { return 0 }
        var current = calendar.startOfDay(for: day)
        var count = 0
        var safety = 0
        while safety < 400 {
            safety += 1
            let key = ProcessStreakStore.dayKey(for: current, calendar: calendar)
            if isPaused(key) {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
                current = previous
                continue
            }
            if !submittedKeys.contains(key) { break }
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }
        return count
    }
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

    @MainActor var label: String {
        let raw = Self.weekdayLabelFormatter.string(from: date)
        let cleaned = raw
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = cleaned.first else { return raw }
        return String(first).uppercased() + cleaned.dropFirst().lowercased()
    }

    private static var weekdayLabelFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = "EEE"
        return formatter
    }
}

struct ProcessStreakMilestone: Identifiable, Equatable {
    let days: Int
    let title: String
    let subtitle: String

    var id: Int { days }

    @MainActor static var catalog: [ProcessStreakMilestone] {
        [
            .init(days: 3, title: AppCopy.t("3 jours", en: "3 Days"), subtitle: AppCopy.t("Le déclencheur", en: "The trigger")),
            .init(days: 7, title: AppCopy.t("7 jours", en: "7 Days"), subtitle: AppCopy.t("Une semaine solide", en: "A strong week")),
            .init(days: 14, title: AppCopy.t("14 jours", en: "14 Days"), subtitle: AppCopy.t("Habitude ancrée", en: "Habit established")),
            .init(days: 30, title: AppCopy.t("30 jours", en: "30 Days"), subtitle: AppCopy.t("Transformation visible", en: "Visible transformation")),
            .init(days: 60, title: AppCopy.t("60 jours", en: "60 Days"), subtitle: AppCopy.t("Mode Process", en: "Process mode")),
            .init(days: 100, title: AppCopy.t("100 jours", en: "100 Days"), subtitle: AppCopy.t("Elite debloat", en: "Elite debloat"))
        ]
    }
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

    @MainActor var streakTitle: String {
        switch totalCompletedDays {
        case 0: return AppCopy.t("Jours validés", en: "Validated Days")
        case 1: return AppCopy.t("1 jour validé", en: "1 Validated Day")
        default: return AppCopy.t("\(totalCompletedDays) jours validés", en: "\(totalCompletedDays) Validated Days")
        }
    }

    @MainActor func encouragement(firstName: String?) -> String {
        let trimmed = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nameSuffix = trimmed.isEmpty ? "" : ", \(trimmed)"

        if let verdict = todayVerdict, isTodayComplete {
            switch verdict {
            case .excellent:
                return AppCopy.t("Journée excellente\(nameSuffix) — score \(Int(todayCompositeScore))/100.", en: "Excellent day\(nameSuffix) — score \(Int(todayCompositeScore))/100.")
            case .onTrack:
                return AppCopy.t("Sur la bonne voie\(nameSuffix) — \(velocityLabel.lowercased()).", en: "On track\(nameSuffix) — \(velocityLabel.lowercased()).")
            case .partial:
                return AppCopy.t("Journée partielle\(nameSuffix) — serre le protocole demain.", en: "Partial day\(nameSuffix) — tighten up the protocol tomorrow.")
            case .regression:
                return AppCopy.t("Régression\(nameSuffix) — on recale ta trajectoire.", en: "Regression\(nameSuffix) — let's get your trajectory back on track.")
            case .pending, .paused, .missed:
                break
            }
        }

        if trimmed.isEmpty { return headline }
        if totalCompletedDays >= 7 { return AppCopy.t("Tu gères vraiment bien, \(trimmed) !", en: "You're doing great, \(trimmed)!") }
        if totalCompletedDays > 0 { return AppCopy.t("Continue comme ça, \(trimmed) !", en: "Keep it up, \(trimmed)!") }
        if isTodayComplete { return AppCopy.t("Bien joué \(trimmed), reviens demain.", en: "Nice work, \(trimmed). Come back tomorrow.") }
        return AppCopy.t("Complète ton check pour lancer ta trajectoire, \(trimmed).", en: "Complete your check-in to start your trajectory, \(trimmed).")
    }

    @MainActor var headline: String {
        if let verdict = todayVerdict {
            switch verdict {
            case .excellent: return AppCopy.t("Journée excellente — trajectoire en hausse.", en: "Excellent day — your trajectory is improving.")
            case .onTrack: return AppCopy.t("Tu restes sur la bonne voie.", en: "You're staying on track.")
            case .partial: return AppCopy.t("Journée partielle — serre le protocole demain.", en: "Partial day — tighten up the protocol tomorrow.")
            case .regression: return AppCopy.t("Régression détectée — on recale ensemble.", en: "Regression detected — let's get back on track together.")
            case .pending: return AppCopy.t("Check du jour en attente — valide-le.", en: "Today's check-in is pending — validate it.")
            case .missed: return AppCopy.t("Check manqué — rattrape-toi.", en: "Missed check-in — catch up.")
            case .paused: return AppCopy.t("Jour en pause — compteur gelé.", en: "Day paused — streak frozen.")
            }
        }
        switch currentStreak {
        case 0 where isTodayComplete:
            return AppCopy.t("Premier jour validé — continue demain.", en: "First day validated — keep going tomorrow.")
        case 0:
            return AppCopy.t("Complète ton check pour valider ta journée.", en: "Complete your check-in to validate your day.")
        case 1:
            return AppCopy.t("Bien joué. Enchaîne demain.", en: "Nice work. Keep it going tomorrow.")
        case 2..<7:
            return AppCopy.t("Tu construis l’habitude.", en: "You're building the habit.")
        case 7..<30:
            return AppCopy.t("Régularité solide — ne lâche pas.", en: "Strong consistency — keep it up.")
        default:
            return AppCopy.t("Tu es en mode Process.", en: "You're in Process mode.")
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
