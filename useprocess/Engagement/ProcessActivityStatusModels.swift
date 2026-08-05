import SwiftUI

enum ProcessActivityStatus: String, nonisolated Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case active
    case sick
    case injured
    case paused

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .active: return AppCopy.t("Activité", en: "Active")
        case .sick: return AppCopy.t("Malade", en: "Sick")
        case .injured: return AppCopy.t("Blessé(e)", en: "Injured")
        case .paused: return AppCopy.t("En pause", en: "On Pause")
        }
    }

    @MainActor var subtitle: String {
        switch self {
        case .active: return AppCopy.t("Rester actif(ve) et en bonne santé", en: "Stay active and healthy")
        case .sick: return AppCopy.t("Prendre du repos après une maladie", en: "Rest and recover from illness")
        case .injured: return AppCopy.t("Récupérer après une blessure", en: "Recover from an injury")
        case .paused: return AppCopy.t("Faire une pause d'entraînement", en: "Take a break from training")
        }
    }

    var systemImage: String {
        switch self {
        case .active: return "figure.run"
        case .sick: return "bed.double.fill"
        case .injured: return "bandage.fill"
        case .paused: return "beach.umbrella.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .active: return Color(red: 0.20, green: 0.84, blue: 0.42)
        case .sick: return Color(red: 1.0, green: 0.82, blue: 0.18)
        case .injured: return Color(red: 1.0, green: 0.42, blue: 0.36)
        case .paused: return Color(red: 0.36, green: 0.72, blue: 1.0)
        }
    }

    var glowColor: Color {
        accentColor.opacity(0.55)
    }

    /// Recommandations coach / plan selon le statut.
    @MainActor var trainingGuidance: String {
        switch self {
        case .active:
            return AppCopy.t("Séances et effort habituels.", en: "Usual sessions and effort.")
        case .sick:
            return AppCopy.t("Repos prioritaire — pas de séance intense.", en: "Prioritize rest — no intense sessions.")
        case .injured:
            return AppCopy.t("Charge réduite — évite la zone douloureuse.", en: "Reduce training load — avoid the painful area.")
        case .paused:
            return AppCopy.t("Pause volontaire — récupération et mobilité légère.", en: "Intentional pause — recovery and light mobility.")
        }
    }
}

struct ProcessActivityStatusState: nonisolated Codable, Equatable, Sendable {
    var hasSeenIntro: Bool = false
    var statusByDayKey: [String: String] = [:]
}

enum ProcessActivityStatusPalette {
    static let rowBackgroundDark = Color.white.opacity(0.08)
    static let rowBackgroundLight = Color.black.opacity(0.05)
    static let rowStrokeDark = Color.white.opacity(0.10)
    static let rowStrokeLight = Color.black.opacity(0.08)
}
