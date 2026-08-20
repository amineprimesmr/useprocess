import Foundation

/// Catalogue visuel entraînement Process — cardio, posture, routines (cartes carousel 9:16).
enum TrainingAssetCatalog {

    /// Noms d’assets (pas d’UIKit) — isolés pour usage depuis contextes non-MainActor.
    private enum Names {
        static let trainingSeeAll = "training_see_all"

        static let cardioMarche = "cardio_marche"
        static let cardioVelo = "cardio_velo"
        static let cardioTapisIncline = "cardio_tapis_incline"
        static let cardioTapisCourse = "cardio_tapis_course"
        static let cardioCoursePied = "cardio_course_pied"
        static let cardioRameur = "cardio_rameur"
        static let cardioElliptique = "cardio_elliptique"
        static let cardioEscalier = "cardio_escalier"
        static let cardioNatation = "cardio_natation"
        static let cardioCorde = "cardio_corde"
        static let cardioHiit = "cardio_hiit"
        static let mobiliteEpaulesHanches = "mobilite_epaules_hanches"
        static let postureChinTuck = "posture_chin_tuck"
        static let postureNeckCurls = "posture_neck_curls"
        static let postureNeckExtensionProne = "posture_neck_extension_prone"
        static let postureWallRetraction = "posture_wall_retraction"
        static let postureWallAngels = "posture_wall_angels"
        static let postureGluteBridge = "posture_glute_bridge"
        static let postureClamshell = "posture_clamshell"
        static let postureThoracicOpener = "posture_thoracic_opener"
        static let postureCatCow = "posture_cat_cow"
        static let postureHipFlexorStretch = "posture_hip_flexor_stretch"
        static let postureFootRelease = "posture_foot_release"
        static let postureBreathing = "posture_breathing"
        static let postureJawBreath = "posture_jaw_breath"
    }

    static let seeAllTrainingAssetName = Names.trainingSeeAll

    static let cardioAssetNames: [String] = [
        Names.cardioMarche, Names.cardioVelo, Names.cardioTapisIncline, Names.cardioTapisCourse,
        Names.cardioCoursePied, Names.cardioRameur, Names.cardioElliptique, Names.cardioEscalier,
        Names.cardioNatation, Names.cardioCorde, Names.cardioHiit
    ]

    static let postureHomeAssetNames: [String] = [
        Names.postureChinTuck, Names.postureNeckCurls, Names.postureNeckExtensionProne,
        Names.postureWallRetraction, Names.postureWallAngels, Names.postureGluteBridge,
        Names.postureClamshell, Names.postureThoracicOpener, Names.postureCatCow,
        Names.postureHipFlexorStretch, Names.postureFootRelease, Names.postureBreathing,
        Names.postureJawBreath
    ]

    static let allAssetNames: [String] = [Names.mobiliteEpaulesHanches]
        + cardioAssetNames + postureHomeAssetNames

    // MARK: - Coach / aperçu séance

    static func resolvedHeroAsset(forSessionTitle title: String) -> String? {
        blockAsset(for: title) ?? assetIfAvailable("session_cardio")
    }

    static func exerciseAsset(for name: String) -> String? {
        blockAsset(for: name)
    }

    // MARK: - Échauffement / cooldown / bloc posture / cardio

    static func blockAsset(for line: String) -> String? {
        let key = normalize(line)
        if key.contains("hiit") || key.contains("interval") || key.contains("assault") {
            return assetIfAvailable(Names.cardioHiit) ?? assetIfAvailable(Names.cardioVelo)
        }
        if key.contains("corde") || key.contains("jump rope") || key.contains("saut") && key.contains("corde") {
            return assetIfAvailable(Names.cardioCorde) ?? assetIfAvailable(Names.cardioMarche)
        }
        if key.contains("natation") || key.contains("nage") || key.contains("swim") || key.contains("piscine") {
            return assetIfAvailable(Names.cardioNatation) ?? assetIfAvailable(Names.cardioMarche)
        }
        if key.contains("rameur") || key.contains("rowing") && key.contains("cardio") || key.contains("aviron") {
            return assetIfAvailable(Names.cardioRameur) ?? assetIfAvailable(Names.cardioVelo)
        }
        if key.contains("ellipt") || key.contains("cross trainer") {
            return assetIfAvailable(Names.cardioElliptique) ?? assetIfAvailable(Names.cardioVelo)
        }
        if key.contains("escalier") || key.contains("stair") || key.contains("stepper") {
            return assetIfAvailable(Names.cardioEscalier) ?? assetIfAvailable(Names.cardioTapisIncline)
        }
        if key.contains("randonnee") || key.contains("randonnée") || key.contains("rando") || key.contains("trail") && key.contains("marche") {
            return assetIfAvailable(Names.cardioMarche)
        }
        if key.contains("course") || key.contains("running") || key.contains("jog") || key.contains("footing") {
            if key.contains("tapis") {
                return assetIfAvailable(Names.cardioTapisCourse) ?? assetIfAvailable(Names.cardioTapisIncline)
            }
            return assetIfAvailable(Names.cardioCoursePied) ?? assetIfAvailable(Names.cardioMarche)
        }
        if key.contains("velo") || key.contains("vélo") || key.contains("bike") || key.contains("cycl") {
            return assetIfAvailable(Names.cardioVelo)
        }
        if key.contains("tapis") && (key.contains("course") || key.contains("run")) {
            return assetIfAvailable(Names.cardioTapisCourse) ?? assetIfAvailable(Names.cardioTapisIncline)
        }
        if key.contains("tapis") || key.contains("incline") || key.contains("inclin") {
            return assetIfAvailable(Names.cardioTapisIncline)
        }
        if key.contains("marche") || key.contains("pas") {
            return assetIfAvailable(Names.cardioMarche)
        }
        if key.contains("mobilite") || key.contains("mobilité") || key.contains("epaule") || key.contains("épaule") || key.contains("hanche") {
            return assetIfAvailable(Names.mobiliteEpaulesHanches)
        }
        if key.contains("chin tuck") || key.contains("retraction cervicale") {
            return assetIfAvailable(Names.postureChinTuck)
        }
        if key.contains("neck curl") {
            return assetIfAvailable(Names.postureNeckCurls) ?? assetIfAvailable(Names.postureChinTuck)
        }
        if key.contains("extension nuque") {
            return assetIfAvailable(Names.postureNeckExtensionProne) ?? assetIfAvailable(Names.postureChinTuck)
        }
        if key.contains("wall angel") {
            return assetIfAvailable(Names.postureWallAngels) ?? assetIfAvailable(Names.mobiliteEpaulesHanches)
        }
        if key.contains("scapulaire") || key.contains("omoplate") || key.contains("retraction") || key.contains("rétraction") {
            return assetIfAvailable(Names.postureWallRetraction) ?? assetIfAvailable(Names.mobiliteEpaulesHanches)
        }
        if key.contains("clamshell") {
            return assetIfAvailable(Names.postureClamshell) ?? assetIfAvailable(Names.mobiliteEpaulesHanches)
        }
        if key.contains("pont fessier") || key.contains("glute bridge") {
            return assetIfAvailable(Names.postureGluteBridge) ?? assetIfAvailable(Names.mobiliteEpaulesHanches)
        }
        if key.contains("chat-vache") || key.contains("chat vache") {
            return assetIfAvailable(Names.postureCatCow) ?? assetIfAvailable(Names.mobiliteEpaulesHanches)
        }
        if key.contains("thoracique") || key.contains("serviette") {
            return assetIfAvailable(Names.postureThoracicOpener) ?? assetIfAvailable(Names.mobiliteEpaulesHanches)
        }
        if key.contains("flechisseur") || key.contains("fléchisseur") || key.contains("fente basse") {
            return assetIfAvailable(Names.postureHipFlexorStretch) ?? assetIfAvailable(Names.mobiliteEpaulesHanches)
        }
        if key.contains("fascia") || key.contains("tennis") || key.contains("pied") {
            return assetIfAvailable(Names.postureFootRelease)
        }
        if key.contains("buteyko") || key.contains("respiration nasale") {
            return assetIfAvailable(Names.postureBreathing) ?? assetIfAvailable(Names.postureChinTuck)
        }
        if key.contains("digastrique") || key.contains("souffle") {
            return assetIfAvailable(Names.postureJawBreath)
                ?? assetIfAvailable(Names.postureBreathing)
                ?? assetIfAvailable(Names.postureChinTuck)
        }
        if key.contains("cervical") {
            return assetIfAvailable(Names.postureChinTuck)
        }
        if key.contains("face pull") {
            return assetIfAvailable(Names.postureWallRetraction) ?? assetIfAvailable(Names.mobiliteEpaulesHanches)
        }
        if let routine = RoutineAssetCatalog.asset(forRoutineLine: line) {
            return routine
        }
        if key.contains("respiration") || key.contains("nasale") {
            return nil
        }
        return nil
    }

    private static func assetIfAvailable(_ name: String) -> String? {
        assetExists(name) ? name : nil
    }

    private static func assetExists(_ name: String) -> Bool {
        ProcessAssetCatalog.contains(name)
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
