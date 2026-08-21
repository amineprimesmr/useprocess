import Foundation

/// Fenêtre de 3 jours après le début du plan : graphes et cardio restent
/// « en calibration » pour coller à l’essai, sans parler d’abonnement.
@MainActor
@Observable
final class ProcessCalibrationMode {
    static let shared = ProcessCalibrationMode()
    static let durationDays = 3

    private static let anchorKey = "process.calibration.anchor_at"
    private static let downloadDateKey = "actualDownloadDate"

    private(set) var remainingDays: Int = 0

    var isActive: Bool { remainingDays > 0 }

    private init() {
        refresh()
    }

    func refresh(now: Date? = nil) {
        let resolvedNow = now ?? ProcessCreatorModeStore.shared.effectiveNow
        remainingDays = Self.computeRemainingDays(now: resolvedNow)
    }

    func isLocked(forcePreview: Bool) -> Bool {
        forcePreview || isActive
    }

    func displayedRemainingDays(forcePreview: Bool) -> Int {
        if forcePreview { return Self.durationDays }
        return remainingDays
    }

    static func computeRemainingDays(now: Date) -> Int {
        let calendar = Calendar.current
        let anchor = resolvedAnchor(now: now)
        let startDay = calendar.startOfDay(for: anchor)
        let nowDay = calendar.startOfDay(for: now)
        let elapsed = calendar.dateComponents([.day], from: startDay, to: nowDay).day ?? 0
        return max(0, durationDays - elapsed)
    }

    /// Ancre = plus ancienne date connue (plan / téléchargement). Les comptes
    /// déjà en place dépassent 3 jours et restent débloqués. Sans ancre, on
    /// reste verrouillé sans écrire `Date()` (évite de lancer le chrono trop tôt).
    private static func resolvedAnchor(now: Date) -> Date {
        if let stored = UserDefaults.standard.object(forKey: anchorKey) as? Date {
            return stored
        }

        var candidates: [Date] = []
        if let download = UserDefaults.standard.object(forKey: downloadDateKey) as? Date {
            candidates.append(download)
        }
        if let plan = WelcomePlanStore.shared.plan {
            if let start = plan.calendar.startedAt {
                candidates.append(start)
            }
            candidates.append(plan.createdAt)
        }

        guard let earliest = candidates.min() else { return now }
        UserDefaults.standard.set(earliest, forKey: anchorKey)
        return earliest
    }
}

enum ProcessCalibrationSurface: Equatable {
    case progressChart
    case streakCharts
    case cardioCircuit
}

enum ProcessCalibrationCopy {
    static func availableIn(days: Int) -> String {
        switch max(days, 1) {
        case 1:
            AppCopy.t("Disponible demain", en: "Available tomorrow")
        default:
            AppCopy.t("Disponible dans \(days) j.", en: "Available in \(days) days")
        }
    }

    static func inDaysCaption(days: Int) -> String {
        switch max(days, 1) {
        case 1:
            AppCopy.t("Demain", en: "Tomorrow")
        default:
            AppCopy.t("Dans \(days) j.", en: "In \(days) days")
        }
    }

    static func title(for surface: ProcessCalibrationSurface) -> String {
        switch surface {
        case .progressChart:
            AppCopy.t("Calibration en cours", en: "Calibration in progress")
        case .streakCharts:
            AppCopy.t("Calibration du plan en cours", en: "Plan calibration in progress")
        case .cardioCircuit:
            AppCopy.t("Circuit en cours de calibration", en: "Circuit being calibrated")
        }
    }

    static func subtitle(for surface: ProcessCalibrationSurface) -> String {
        switch surface {
        case .progressChart:
            AppCopy.t(
                "Le graphique se cale sur tes premiers scans.",
                en: "The chart settles in over your first scans."
            )
        case .streakCharts:
            AppCopy.t(
                "Les courbes se calent sur tes premiers jours du plan.",
                en: "The charts settle in over your first days on the plan."
            )
        case .cardioCircuit:
            AppCopy.t(
                "Ton cardio et tes circuits se calent sur tes premiers jours.",
                en: "Your cardio and circuits settle in over your first days."
            )
        }
    }

    static var progressInsight: String {
        AppCopy.t(
            "Ton évolution se construit pendant la calibration du plan.",
            en: "Your evolution is built while the plan calibrates."
        )
    }
}
