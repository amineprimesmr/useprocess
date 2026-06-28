import Foundation

/// Routine matinale visage — 3 actions ordonnées, affichées dans le carousel Plan.
enum FaceMorningRoutineCatalog {

    enum Step: Int, CaseIterable {
        case soleilAuReveil
        case eauFroide
        case massageSousOrbital

        func canonicalLine(targets: OriginPersonalizedDailyTargets) -> String {
            switch self {
            case .soleilAuReveil:
                return "Soleil au réveil — \(targets.morningLightMinutes) min de lumière naturelle"
            case .eauFroide:
                return "Eau froide sur le visage \(targets.coldFaceRinseSeconds) sec au réveil"
            case .massageSousOrbital:
                return "Massage doux sous-orbital — \(targets.lymphFaceMassageMinutes) min"
            }
        }
    }

    static func buildSteps(targets: OriginPersonalizedDailyTargets) -> [String] {
        Step.allCases.map { $0.canonicalLine(targets: targets) }
    }

    /// Lignes pour le carousel — priorité fixe, texte canonique (ignore pollution stockée).
    static func displaySteps(
        storedLines: [String],
        targets: OriginPersonalizedDailyTargets
    ) -> [String] {
        _ = storedLines
        return buildSteps(targets: targets)
    }

    static func estimatedMinutes(targets: OriginPersonalizedDailyTargets) -> Int {
        targets.morningLightMinutes + targets.lymphFaceMassageMinutes + 1
    }
}
