import Foundation

/// Visuels corps 3D par type de séance (`body3D`).
enum TrainingBodySessionVisuals {

    enum Asset {
        static let pull = "body_session_pull"
        static let push = "body_session_push"
        static let legsFace = "body_session_legsface"
        static let legsBack = "body_session_legsdos"
        static let restFace = "body_session_restface"
        static let restBack = "body_session_restdos"
        static let upperFace = "body_session_upperface"
        static let upperBack = "body_session_upperdos"
    }

    /// Vue de face pour la section journal (un seul hero).
    static func frontHeroAsset(for training: OriginDayTraining) -> String {
        frontHeroAsset(forSessionID: TrainingSessionCatalog.entry(for: training).id)
    }

    static func frontHeroAsset(forSessionName name: String) -> String {
        if let entry = TrainingSessionCatalog.entry(matchingSessionName: name) {
            return frontHeroAsset(forSessionID: entry.id)
        }
        return frontHeroAsset(forSessionTitle: name)
    }

    /// Vue de dos — détail séance ou fiche complète.
    static func backHeroAsset(for training: OriginDayTraining) -> String? {
        backHeroAsset(forSessionID: TrainingSessionCatalog.entry(for: training).id)
    }

    static func frontHeroAsset(forSessionID id: TrainingSessionID) -> String {
        switch id {
        case .pullGym, .pullHome:
            return Asset.pull
        case .pushGym, .pushHome:
            return Asset.push
        case .legsGym, .legsHome, .femaleGlutes:
            return Asset.legsFace
        case .femaleUpper:
            return Asset.upperFace
        case .restDay:
            return Asset.restFace
        }
    }

    static func backHeroAsset(forSessionID id: TrainingSessionID) -> String? {
        switch id {
        case .pullGym, .pullHome, .pushGym, .pushHome:
            return nil
        case .legsGym, .legsHome, .femaleGlutes:
            return Asset.legsBack
        case .femaleUpper:
            return Asset.upperBack
        case .restDay:
            return Asset.restBack
        }
    }

    private static func frontHeroAsset(forSessionTitle title: String) -> String {
        let normalized = normalize(title)
        if normalized.contains("pull") || normalized.contains("dos") && normalized.contains("rear") {
            return Asset.pull
        }
        if normalized.contains("push") || normalized.contains("pec") {
            return Asset.push
        }
        if normalized.contains("jamb") || normalized.contains("leg") || normalized.contains("fessier") {
            return Asset.legsFace
        }
        if normalized.contains("haut") && normalized.contains("posture") {
            return Asset.upperFace
        }
        if normalized.contains("posture") {
            return Asset.upperFace
        }
        if normalized.contains("recup") || normalized.contains("repos") || normalized.contains("marche") {
            return Asset.restFace
        }
        return Asset.push
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "—", with: " ")
            .replacingOccurrences(of: "–", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }
}
