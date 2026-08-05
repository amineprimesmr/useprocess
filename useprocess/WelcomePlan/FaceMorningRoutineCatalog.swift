import Foundation

/// Routine matinale — eau tiède, circuit lymphatique, glaçons (carousel Plan).
enum FaceMorningRoutineCatalog {

    static let warmWaterML = ProcessDailyTargets.warmWaterOnWakeML
    static let lymphJumpSeconds = ProcessDailyTargets.lymphJumpSeconds
    static let lymphKneeRaiseSeconds = ProcessDailyTargets.lymphKneeRaiseSeconds
    static let lymphArmRaiseSeconds = ProcessDailyTargets.lymphArmRaiseSeconds

    /// Durée totale estimée du circuit lymphatique (sauts + genoux + bras).
    static var lymphCircuitSeconds: Int {
        lymphJumpSeconds + lymphKneeRaiseSeconds + lymphArmRaiseSeconds
    }

    static var lymphCircuitMinutesLabel: String {
        let minutes = max(1, lymphCircuitSeconds / 60)
        return "\(minutes) min"
    }

    enum Step: Int, CaseIterable {
        case eauTiede
        case sautsSurPlace
        case monteesGenoux
        case brasAlternes
        case glaconsVisage

        @MainActor
        func canonicalLine(targets: OriginPersonalizedDailyTargets) -> String {
            _ = targets
            switch self {
            case .eauTiede:
                return AppCopy.t(
                    "Eau tiède au réveil — \(FaceMorningRoutineCatalog.warmWaterML) ml pour relancer digestion et hydratation",
                    en: "Warm water on waking — \(FaceMorningRoutineCatalog.warmWaterML) ml to restart digestion and hydration"
                )
            case .sautsSurPlace:
                return AppCopy.t(
                    "Sauts sur place — 1 min, bras levés, rebonds légers pour pomper la lymphe",
                    en: "Jumping in place — 1 min, arms up, light bounces to pump lymph"
                )
            case .monteesGenoux:
                return AppCopy.t(
                    "Montées de genoux — tapote chaque genou avec les mains, 1 min en rythme",
                    en: "High knees — tap each knee with your hands, 1 min in rhythm"
                )
            case .brasAlternes:
                return AppCopy.t(
                    "Bras alternés — lève bras gauche puis droit au-dessus de la tête, 1 min",
                    en: "Alternating arms — raise left then right above your head, 1 min"
                )
            case .glaconsVisage:
                return AppCopy.t(
                    "Glaçons sur le visage — \(ProcessDailyTargets.coldFaceRinseSeconds) s pour vasoconstriction et dégonflement",
                    en: "Ice on the face — \(ProcessDailyTargets.coldFaceRinseSeconds) s for vasoconstriction and debloat"
                )
            }
        }

        var carouselId: String {
            switch self {
            case .eauTiede: return "daily-routine-eau-tiede"
            case .sautsSurPlace: return "daily-routine-sauts"
            case .monteesGenoux: return "daily-routine-genoux"
            case .brasAlternes: return "daily-routine-bras"
            case .glaconsVisage: return "daily-routine-glacons"
            }
        }

        var fallbackIcon: String {
            switch self {
            case .eauTiede: return "mug.fill"
            case .sautsSurPlace: return "figure.jumprope"
            case .monteesGenoux: return "figure.run"
            case .brasAlternes: return "figure.arms.open"
            case .glaconsVisage: return "snowflake"
            }
        }

        var assetName: String? {
            switch self {
            case .eauTiede: return RoutineAssetCatalog.eauTiede
            case .sautsSurPlace: return RoutineAssetCatalog.sauts
            case .monteesGenoux: return RoutineAssetCatalog.genoux
            case .brasAlternes: return RoutineAssetCatalog.bras
            case .glaconsVisage: return RoutineAssetCatalog.glacons
            }
        }

        var repBadge: String? {
            switch self {
            case .eauTiede: return "\(warmWaterML) ml"
            case .sautsSurPlace, .monteesGenoux, .brasAlternes: return "1 min"
            case .glaconsVisage: return "\(ProcessDailyTargets.coldFaceRinseSeconds) s"
            }
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
        let drinkMinutes = 2
        let circuitMinutes = max(1, lymphCircuitSeconds / 60)
        let iceMinutes = 1
        return drinkMinutes + circuitMinutes + iceMinutes
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
    @MainActor
    static var journalSummary: String {
        AppCopy.t(
            "\(warmWaterML) ml eau tiède · circuit lymphatique \(lymphCircuitMinutesLabel) · glaçons",
            en: "\(warmWaterML) ml warm water · lymph circuit \(lymphCircuitMinutesLabel) · ice"
        )
    }
}
