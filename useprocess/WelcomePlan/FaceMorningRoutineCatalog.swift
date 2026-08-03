import Foundation

/// Routine matinale — 5 actions fixes (carousel Plan, section Routine matinale).
enum FaceMorningRoutineCatalog {

    enum Step: Int, CaseIterable {
        case eauTiede
        case sauts
        case monteesGenoux
        case brasAlternesSwings
        case glacons

        var carouselItemId: String {
            switch self {
            case .eauTiede: return "daily-routine-eautiede"
            case .sauts: return "daily-routine-sauts"
            case .monteesGenoux: return "daily-routine-genoux"
            case .brasAlternesSwings: return "daily-routine-bras"
            case .glacons: return "daily-routine-glacons"
            }
        }

        func canonicalLine() -> String {
            switch self {
            case .eauTiede:
                return "Eau tiède au réveil — \(ProcessDailyTargets.warmWaterOnWakeML) ml pour activer le système digestif"
            case .sauts:
                return "Sauts sur place — \(ProcessDailyTargets.lymphJumpSeconds) s pour activer le drainage lymphatique"
            case .monteesGenoux:
                return "Montées genoux — \(ProcessDailyTargets.lymphKneeRaisesSeconds) s pour activer le drainage lymphatique"
            case .brasAlternesSwings:
                return "Bras alternés — \(ProcessDailyTargets.lymphArmSwingsSeconds) s pour activer la circulation"
            case .glacons:
                return "Glaçons sur le visage"
            }
        }

        var assetName: String {
            switch self {
            case .eauTiede: return RoutineAssetCatalog.eauTiede
            case .sauts: return RoutineAssetCatalog.sauts
            case .monteesGenoux: return RoutineAssetCatalog.genoux
            case .brasAlternesSwings: return RoutineAssetCatalog.bras
            case .glacons: return RoutineAssetCatalog.glacons
            }
        }

        var fallbackIcon: String {
            switch self {
            case .eauTiede: return "drop.fill"
            case .sauts: return "figure.jumprope"
            case .monteesGenoux: return "figure.step.training"
            case .brasAlternesSwings: return "figure.arms.open"
            case .glacons: return "snowflake"
            }
        }
    }

    static func buildSteps() -> [String] {
        Step.allCases.map { $0.canonicalLine() }
    }

    static func estimatedMinutes() -> Int {
        let lymphSeconds = ProcessDailyTargets.lymphJumpSeconds
            + ProcessDailyTargets.lymphKneeRaisesSeconds
            + ProcessDailyTargets.lymphArmSwingsSeconds
        return Int(ceil(Double(lymphSeconds) / 60.0)) + 2
    }

    static func dailyRoutineActionCount() -> Int {
        Step.allCases.count
    }

    /// Cartes carousel avec visuels routine.
    static func carouselItems(targets: OriginPersonalizedDailyTargets) -> [PlanProtocolCarouselItem] {
        _ = targets
        let category = "Routine matinale"
        return Step.allCases.map { step in
            PlanProtocolCarouselBuilder.lineItem(
                step.canonicalLine(),
                id: step.carouselItemId,
                fallback: step.fallbackIcon,
                category: category,
                assetName: step.assetName
            )
        }
    }

    static func displaySteps(
        storedLines: [String],
        targets: OriginPersonalizedDailyTargets
    ) -> [String] {
        _ = storedLines
        return buildSteps()
    }
}
