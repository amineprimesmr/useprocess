import UIKit

/// Catalogue visuel entraînement Process — 20 assets (heroes, exercices, cardio, posture).
enum TrainingAssetCatalog {

    /// Noms d’assets (pas d’UIKit) — isolés pour usage depuis contextes non-MainActor.
    private enum Names {
        static let heroPull = "dossport"
        static let heroPush = "session_push"
        static let heroLegs = "session_legs"
        static let heroRest = "session_rest"
        static let heroPosture = "session_posture"
        static let heroCardio = "session_cardio"

        static let exerciseDeveloppeHalteres = "exercise_developpe_halteres"
        static let exerciseElevationsLaterales = "exercise_elevations_laterales"
        static let exerciseFacePulls = "exercise_face_pulls"
        static let exerciseShrugs = "exercise_shrugs"
        static let exerciseTractionsTirage = "exercise_tractions_tirage"
        static let exerciseRowing = "exercise_rowing"
        static let exerciseCurlMarteau = "exercise_curl_marteau"
        static let exerciseSquat = "exercise_squat"
        static let exerciseRomanianDeadlift = "exercise_romanian_deadlift"
        static let exerciseHipThrust = "exercise_hip_thrust"
        static let exerciseMollets = "exercise_mollets"

        static let cardioMarche = "cardio_marche"
        static let cardioVelo = "cardio_velo"
        static let cardioTapisIncline = "cardio_tapis_incline"
        static let mobiliteEpaulesHanches = "mobilite_epaules_hanches"
        static let postureChinTuck = "posture_chin_tuck"
    }

    static let allAssetNames: [String] = [
        Names.heroPull, Names.heroPush, Names.heroLegs, Names.heroRest, Names.heroPosture, Names.heroCardio,
        Names.exerciseDeveloppeHalteres, Names.exerciseElevationsLaterales, Names.exerciseFacePulls, Names.exerciseShrugs,
        Names.exerciseTractionsTirage, Names.exerciseRowing, Names.exerciseCurlMarteau, Names.exerciseSquat,
        Names.exerciseRomanianDeadlift, Names.exerciseHipThrust, Names.exerciseMollets,
        Names.cardioMarche, Names.cardioVelo, Names.cardioTapisIncline, Names.mobiliteEpaulesHanches, Names.postureChinTuck
    ]

    // MARK: - Résolution hero

    static func heroAsset(for entry: TrainingSessionCatalogEntry) -> String {
        heroAsset(forSessionID: entry.id)
    }

    static func heroAsset(forSessionID id: TrainingSessionID) -> String {
        switch id {
        case .pullGym, .pullHome:
            return Names.heroPull
        case .pushGym, .pushHome:
            return Names.heroPush
        case .legsGym, .legsHome, .femaleGlutes:
            return Names.heroLegs
        case .femaleUpper:
            return Names.heroPosture
        case .restDay:
            return Names.heroRest
        }
    }

    static func heroAsset(forSessionTitle title: String) -> String {
        let normalized = normalize(title)
        if normalized.contains("pull") || normalized.contains("dos") && normalized.contains("rear") {
            return Names.heroPull
        }
        if normalized.contains("push") || normalized.contains("pec") {
            return Names.heroPush
        }
        if normalized.contains("jamb") || normalized.contains("leg") || normalized.contains("fessier") {
            return Names.heroLegs
        }
        if normalized.contains("posture") || normalized.contains("face pull") {
            return Names.heroPosture
        }
        if normalized.contains("recup") || normalized.contains("repos") || normalized.contains("marche") {
            return Names.heroRest
        }
        if normalized.contains("cardio") || normalized.contains("velo") || normalized.contains("vélo") {
            return Names.heroCardio
        }
        return Names.heroPush
    }

    @MainActor
    static func resolvedHeroAsset(for entry: TrainingSessionCatalogEntry) -> String {
        let preferred = heroAsset(for: entry)
        if assetExists(preferred) { return preferred }
        if assetExists(Names.heroPull) { return Names.heroPull }
        return preferred
    }

    @MainActor
    static func resolvedHeroAsset(forSessionTitle title: String) -> String? {
        let name = heroAsset(forSessionTitle: title)
        return assetExists(name) ? name : nil
    }

    // MARK: - Résolution exercice

    @MainActor
    static func exerciseAsset(for name: String) -> String? {
        let key = normalize(name)
        guard let asset = exerciseAssetMap.first(where: { key.contains($0.key) })?.value else {
            return nil
        }
        return assetExists(asset) ? asset : nil
    }

    private static let exerciseAssetMap: [(key: String, value: String)] = [
        ("developpe", Names.exerciseDeveloppeHalteres),
        ("développé", Names.exerciseDeveloppeHalteres),
        ("elevation", Names.exerciseElevationsLaterales),
        ("élévation", Names.exerciseElevationsLaterales),
        ("face pull", Names.exerciseFacePulls),
        ("shrug", Names.exerciseShrugs),
        ("traction", Names.exerciseTractionsTirage),
        ("tirage", Names.exerciseTractionsTirage),
        ("rowing", Names.exerciseRowing),
        ("row elastique", Names.exerciseRowing),
        ("curl", Names.exerciseCurlMarteau),
        ("squat", Names.exerciseSquat),
        ("goblet", Names.exerciseSquat),
        ("romanian", Names.exerciseRomanianDeadlift),
        ("deadlift", Names.exerciseRomanianDeadlift),
        ("hip thrust", Names.exerciseHipThrust),
        ("hip hinge", Names.exerciseHipThrust),
        ("mollet", Names.exerciseMollets),
        ("fente", Names.exerciseSquat),
        ("pompes", Names.exerciseDeveloppeHalteres),
        ("push-up", Names.exerciseDeveloppeHalteres),
        ("pike push", Names.exerciseElevationsLaterales),
        ("planche", Names.exerciseHipThrust),
        ("dead bug", Names.exerciseHipThrust),
        ("superman", Names.exerciseRowing),
        ("reverse fly", Names.exerciseFacePulls),
        ("abduction", Names.exerciseHipThrust),
        ("chin tuck", Names.postureChinTuck),
        ("retraction cervicale", Names.postureChinTuck)
    ]

    // MARK: - Échauffement / cooldown / bloc posture

    @MainActor
    static func blockAsset(for line: String) -> String? {
        let key = normalize(line)
        if key.contains("velo") || key.contains("vélo") || key.contains("bike") {
            return assetIfAvailable(Names.cardioVelo)
        }
        if key.contains("tapis") || key.contains("incline") || key.contains("inclin") {
            return assetIfAvailable(Names.cardioTapisIncline)
        }
        if key.contains("marche") {
            return assetIfAvailable(Names.cardioMarche)
        }
        if key.contains("mobilite") || key.contains("mobilité") || key.contains("epaule") || key.contains("épaule") || key.contains("hanche") {
            return assetIfAvailable(Names.mobiliteEpaulesHanches)
        }
        if key.contains("chin tuck") || key.contains("retraction") || key.contains("rétraction") || key.contains("cervical") {
            return assetIfAvailable(Names.postureChinTuck)
        }
        if key.contains("face pull") {
            return assetIfAvailable(Names.exerciseFacePulls)
        }
        if key.contains("respiration") || key.contains("nasale") {
            return nil
        }
        return nil
    }

    @MainActor
    private static func assetIfAvailable(_ name: String) -> String? {
        assetExists(name) ? name : nil
    }

    @MainActor
    private static func assetExists(_ name: String) -> Bool {
        UIImage(named: name) != nil
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
