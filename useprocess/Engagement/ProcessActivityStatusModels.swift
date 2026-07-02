import SwiftUI

enum ProcessActivityStatus: String, Codable, CaseIterable, Identifiable, Equatable {
    case active
    case sick
    case injured
    case paused

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: return "Activité"
        case .sick: return "Malade"
        case .injured: return "Blessé(e)"
        case .paused: return "En pause"
        }
    }

    var subtitle: String {
        switch self {
        case .active: return "Rester actif(ve) et en bonne santé"
        case .sick: return "Prendre du repos après une maladie"
        case .injured: return "Récupérer après une blessure"
        case .paused: return "Faire une pause d'entraînement"
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
    var trainingGuidance: String {
        switch self {
        case .active:
            return "Séances et effort habituels."
        case .sick:
            return "Repos prioritaire — pas de séance intense."
        case .injured:
            return "Charge réduite — évite la zone douloureuse."
        case .paused:
            return "Pause volontaire — récupération et mobilité légère."
        }
    }
}

struct ProcessActivityStatusState: Codable, Equatable {
    var hasSeenIntro: Bool = false
    var statusByDayKey: [String: String] = [:]
}

enum ProcessActivityStatusPalette {
    static let rowBackgroundDark = Color.white.opacity(0.08)
    static let rowBackgroundLight = Color.black.opacity(0.05)
    static let rowStrokeDark = Color.white.opacity(0.10)
    static let rowStrokeLight = Color.black.opacity(0.08)
}
