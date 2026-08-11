import Foundation

/// Circuit lymphatique — 6 mouvements (carousel Plan + session live).
enum FaceMorningRoutineCatalog {

    /// Durée totale session.
    static var fullSessionSeconds: Int {
        Step.allCases.reduce(0) { $0 + $1.durationSeconds }
    }

    static var lymphCircuitSeconds: Int { fullSessionSeconds }

    static var lymphCircuitMinutesLabel: String {
        let minutes = max(1, Int(ceil(Double(fullSessionSeconds) / 60.0)))
        return "\(minutes) min"
    }

    enum Step: Int, CaseIterable, Identifiable, Hashable {
        case sautsSurPlace
        case rebondsPointes
        case brasAuCiel
        case brasEnCroix
        case ouvertureThorax
        case monteesGenoux

        var id: String { carouselId }

        /// Caméra + squelette Vision pendant l’exercice.
        var usesLiveCamera: Bool { true }

        var durationSeconds: Int {
            switch self {
            case .sautsSurPlace: return 60
            case .rebondsPointes: return 60
            case .brasAuCiel: return 55
            case .brasEnCroix: return 30
            case .ouvertureThorax: return 30
            case .monteesGenoux: return 45
            }
        }

        @MainActor
        var shortTitle: String {
            switch self {
            case .sautsSurPlace:
                return AppCopy.t("Sauts sur place", en: "Jumping in place")
            case .rebondsPointes:
                return AppCopy.t("Rebonds sur pointes", en: "Toe bounces")
            case .brasAuCiel:
                return AppCopy.t("Bras au ciel", en: "Arms to sky")
            case .brasEnCroix:
                return AppCopy.t("Bras en croix", en: "Arms out wide")
            case .ouvertureThorax:
                return AppCopy.t("Ouverture thorax", en: "Chest opening")
            case .monteesGenoux:
                return AppCopy.t("Montées de genoux", en: "High knees")
            }
        }

        @MainActor
        var coachingCue: String {
            switch self {
            case .sautsSurPlace:
                return AppCopy.t(
                    "Rebonds légers, rythme régulier — pompe la lymphe.",
                    en: "Light bounces, steady rhythm — pump the lymph."
                )
            case .rebondsPointes:
                return AppCopy.t(
                    "Sur la pointe des pieds, petits rebonds, bras écartés.",
                    en: "On your toes, light bounces, arms out."
                )
            case .brasAuCiel:
                return AppCopy.t(
                    "Lève les bras au ciel, monte sur la pointe des pieds.",
                    en: "Reach arms to the sky, rise onto your toes."
                )
            case .brasEnCroix:
                return AppCopy.t(
                    "Bras horizontaux, poitrine ouverte — respire large.",
                    en: "Arms horizontal, open chest — breathe wide."
                )
            case .ouvertureThorax:
                return AppCopy.t(
                    "Mains sur le thorax, ouvre et stimule la zone.",
                    en: "Hands on the chest, open and stimulate the area."
                )
            case .monteesGenoux:
                return AppCopy.t(
                    "Monte un genou puis l’autre, reste stable.",
                    en: "Raise one knee then the other, stay balanced."
                )
            }
        }

        @MainActor
        func canonicalLine(targets: OriginPersonalizedDailyTargets) -> String {
            _ = targets
            switch self {
            case .sautsSurPlace:
                return AppCopy.t(
                    "Sauts sur place — rebonds légers pour pomper la lymphe",
                    en: "Jumping in place — light bounces to pump lymph"
                )
            case .rebondsPointes:
                return AppCopy.t(
                    "Rebonds sur pointes — pompe mollets et lymphe, bras écartés",
                    en: "Toe bounces — pump calves and lymph, arms out"
                )
            case .brasAuCiel:
                return AppCopy.t(
                    "Bras au ciel — lève les bras et monte sur la pointe des pieds",
                    en: "Arms to sky — raise arms and rise onto your toes"
                )
            case .brasEnCroix:
                return AppCopy.t(
                    "Bras en croix — ouvre la poitrine, bras à l’horizontale",
                    en: "Arms out wide — open the chest, arms horizontal"
                )
            case .ouvertureThorax:
                return AppCopy.t(
                    "Ouverture thorax — stimule la zone terminale lymphatique",
                    en: "Chest opening — stimulate the lymphatic terminus"
                )
            case .monteesGenoux:
                return AppCopy.t(
                    "Montées de genoux — alterne les genoux en rythme",
                    en: "High knees — alternate knees in rhythm"
                )
            }
        }

        var carouselId: String {
            switch self {
            case .sautsSurPlace: return "daily-routine-sauts"
            case .rebondsPointes: return "daily-routine-pointes"
            case .brasAuCiel: return "daily-routine-bras"
            case .brasEnCroix: return "daily-routine-brascroix"
            case .ouvertureThorax: return "daily-routine-thorax"
            case .monteesGenoux: return "daily-routine-genoux"
            }
        }

        var fallbackIcon: String {
            switch self {
            case .sautsSurPlace: return "figure.jumprope"
            case .rebondsPointes: return "figure.mind.and.body"
            case .brasAuCiel: return "figure.arms.open"
            case .brasEnCroix: return "arrow.left.and.right"
            case .ouvertureThorax: return "heart.fill"
            case .monteesGenoux: return "figure.run"
            }
        }

        var assetName: String? {
            switch self {
            case .sautsSurPlace: return RoutineAssetCatalog.sauts
            case .rebondsPointes: return RoutineAssetCatalog.pointes
            case .brasAuCiel: return RoutineAssetCatalog.brasCiel
            case .brasEnCroix: return RoutineAssetCatalog.brasCroix
            case .ouvertureThorax: return RoutineAssetCatalog.thorax
            case .monteesGenoux: return RoutineAssetCatalog.genoux
            }
        }

        /// Nom de ressource vidéo (sans extension) — `Resources/LymphCircuit/lymph_XX.mp4`.
        var demoVideoResourceName: String {
            switch self {
            case .sautsSurPlace: return "lymph_01"
            case .rebondsPointes: return "lymph_02"
            case .brasAuCiel: return "lymph_03"
            case .brasEnCroix: return "lymph_05"
            case .ouvertureThorax: return "lymph_06"
            case .monteesGenoux: return "lymph_07"
            }
        }

        var repBadge: String? {
            let minutes = durationSeconds / 60
            let seconds = durationSeconds % 60
            if minutes > 0, seconds == 0 { return "\(minutes) min" }
            if minutes > 0 { return "\(minutes):\(String(format: "%02d", seconds))" }
            return "\(seconds) s"
        }

        var stepNumber: Int {
            (Self.allCases.firstIndex(of: self) ?? 0) + 1
        }

        static var totalStepCount: Int { allCases.count }

        /// Étapes du geste — fiche exercice.
        @MainActor
        var howToSteps: [String] {
            switch self {
            case .sautsSurPlace:
                return [
                    AppCopy.t("Pieds largeur hanches, genoux souples.", en: "Feet hip-width apart, soft knees."),
                    AppCopy.t("Rebonds légers sans quitter le sol de plus de quelques cm.", en: "Light bounces, barely leaving the floor."),
                    AppCopy.t("Garde un rythme régulier et respire par le nez.", en: "Keep a steady rhythm and breathe through your nose.")
                ]
            case .rebondsPointes:
                return [
                    AppCopy.t("Monte sur la pointe des pieds, bras écartés.", en: "Rise onto your toes, arms out wide."),
                    AppCopy.t("Enchaîne de petits rebonds contrôlés.", en: "Chain small, controlled bounces."),
                    AppCopy.t("Sens les mollets pomper sans verrouiller les chevilles.", en: "Feel your calves pump without locking your ankles.")
                ]
            case .brasAuCiel:
                return [
                    AppCopy.t("Lève les bras au-dessus de la tête, paumes face à face.", en: "Reach arms overhead, palms facing each other."),
                    AppCopy.t("Monte sur la pointe des pieds en même temps.", en: "Rise onto your toes at the same time."),
                    AppCopy.t("Étire la ligne latérale, relâche les épaules.", en: "Lengthen your side body, relax your shoulders.")
                ]
            case .brasEnCroix:
                return [
                    AppCopy.t("Bras à l’horizontale, paumes vers le sol.", en: "Arms horizontal, palms facing down."),
                    AppCopy.t("Ouvre la poitrine sans cambrer le bas du dos.", en: "Open your chest without arching your lower back."),
                    AppCopy.t("Respire large — inspire en ouvrant, expire en stabilisant.", en: "Breathe wide — inhale as you open, exhale as you stabilize.")
                ]
            case .ouvertureThorax:
                return [
                    AppCopy.t("Mains sur le sternum ou le thorax.", en: "Hands on your sternum or chest."),
                    AppCopy.t("Ouvre la cage en inspirant, paumes qui s’écartent légèrement.", en: "Open the rib cage as you inhale, palms drifting apart slightly."),
                    AppCopy.t("Mouvement lent et contrôlé, sans forcer.", en: "Slow, controlled movement — no forcing.")
                ]
            case .monteesGenoux:
                return [
                    AppCopy.t("Debout, core engagé, regard devant.", en: "Stand tall, core engaged, eyes forward."),
                    AppCopy.t("Alterne genou droit et genou gauche en rythme.", en: "Alternate right and left knee in rhythm."),
                    AppCopy.t("Monte le genou sans te pencher en arrière.", en: "Lift each knee without leaning back.")
                ]
            }
        }

        /// Bénéfices debloat / lymphe — fiche exercice.
        @MainActor
        var benefits: [String] {
            switch self {
            case .sautsSurPlace:
                return [
                    AppCopy.t("Active la pompe lymphatique du bas du corps.", en: "Activates lower-body lymph pumping."),
                    AppCopy.t("Stimule la circulation veineuse.", en: "Stimulates venous circulation."),
                    AppCopy.t("Réveille le métabolisme sans impact violent.", en: "Wakes up metabolism without harsh impact."),
                    AppCopy.t("Favorise la réduction du gonflement matinal.", en: "Helps reduce morning puffiness.")
                ]
            case .rebondsPointes:
                return [
                    AppCopy.t("Travaille la pompe musculaire des mollets.", en: "Works the calf muscle pump."),
                    AppCopy.t("Améliore le retour veineux vers le cœur.", en: "Improves venous return to the heart."),
                    AppCopy.t("Ouvre le thorax grâce aux bras écartés.", en: "Opens the chest with arms out wide."),
                    AppCopy.t("Tonifie chevilles et stabilité.", en: "Tones ankles and stability.")
                ]
            case .brasAuCiel:
                return [
                    AppCopy.t("Ouvre les terminaisons lymphatiques axillaires.", en: "Opens axillary lymph terminations."),
                    AppCopy.t("Étire la ligne latérale et relâche le cou.", en: "Lengthens side body and releases the neck."),
                    AppCopy.t("Améliore la posture verticale.", en: "Improves upright posture."),
                    AppCopy.t("Favorise une meilleure respiration.", en: "Supports better breathing.")
                ]
            case .brasEnCroix:
                return [
                    AppCopy.t("Débloque épaules et poitrine.", en: "Unlocks shoulders and chest."),
                    AppCopy.t("Stimule le drainage thoracique.", en: "Stimulates thoracic drainage."),
                    AppCopy.t("Réduit la tension posturale du haut du corps.", en: "Reduces upper-body postural tension."),
                    AppCopy.t("Prépare la zone terminale lymphatique.", en: "Primes the lymphatic terminus zone.")
                ]
            case .ouvertureThorax:
                return [
                    AppCopy.t("Stimule directement la zone terminale lymphatique.", en: "Directly stimulates the lymphatic terminus."),
                    AppCopy.t("Ouvre le sternum et le plexus thoracique.", en: "Opens the sternum and thoracic plexus."),
                    AppCopy.t("Favorise la respiration diaphragmatique.", en: "Encourages diaphragmatic breathing."),
                    AppCopy.t("Allège la sensation de poitrine serrée.", en: "Eases chest tightness.")
                ]
            case .monteesGenoux:
                return [
                    AppCopy.t("Augmente le rythme cardiaque en douceur.", en: "Gently raises heart rate."),
                    AppCopy.t("Active le centre du corps et l’équilibre.", en: "Activates core and balance."),
                    AppCopy.t("Booste la circulation globale.", en: "Boosts overall circulation."),
                    AppCopy.t("Enchaîne naturellement le circuit.", en: "Flows naturally into the circuit finish.")
                ]
            }
        }

        static func from(carouselId: String) -> Step? {
            allCases.first { $0.carouselId == carouselId }
        }
    }

    @MainActor
    static func buildSteps(targets: OriginPersonalizedDailyTargets) -> [String] {
        Step.allCases.map { $0.canonicalLine(targets: targets) }
    }

    @MainActor
    static func displaySteps(
        storedLines: [String],
        targets: OriginPersonalizedDailyTargets
    ) -> [String] {
        _ = storedLines
        return buildSteps(targets: targets)
    }

    static func estimatedMinutes(targets: OriginPersonalizedDailyTargets) -> Int {
        _ = targets
        return max(1, Int(ceil(Double(fullSessionSeconds) / 60.0)))
    }

    @MainActor
    static func dailyRoutineActionCount(targets: OriginPersonalizedDailyTargets) -> Int {
        carouselItems(targets: targets).count
    }

    @MainActor
    static func carouselItems(targets: OriginPersonalizedDailyTargets) -> [PlanProtocolCarouselItem] {
        let category = PlanHomeSectionKind.faceRoutine.title
        return Step.allCases.map { step in
            PlanProtocolCarouselBuilder.lineItem(
                step.canonicalLine(targets: targets),
                id: step.carouselId,
                fallback: step.fallbackIcon,
                category: category,
                assetName: step.assetName,
                repBadge: step.repBadge
            )
        }
    }

    /// Texte court pour journal / checklist.
    static var journalSummary: String {
        AppCopy.tSync(
            "Circuit lymphatique — 6 mouvements · \(lymphCircuitMinutesLabel)",
            en: "Lymphatic circuit — 6 moves · \(lymphCircuitMinutesLabel)"
        )
    }
}
