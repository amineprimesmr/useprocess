import Foundation

/// Habitudes 24/7 — intégrées au carousel Routine quotidienne + guide debloat.
enum ProcessContinuousHabits {

    static let mewingTitle = "Mewing 24/24"
    static let mewingDetail = """
    Langue en vide sur le palais : « T », sourire + yeux ouverts, déglutitions jusqu'à salive épuisée. \
    Bouche fermée au repos, air par le nez jour et nuit. Semaine 1 : rappel toutes les heures.
    """

    static let masticationTitle = "Mastication lente"
    static var masticationDetail: String {
        "\(ProcessDailyTargets.chewsPerBite) mâchées par bouchée — mastication lente à chaque repas."
    }

    static let postureTitle = "Posture droite"
    static let postureDetail = PostureIntelligenceGuide.neckAlignmentDetail

    static let sideSleepTitle = "Respiration nasale"
    static let sideSleepDetail = "Dormir sur le côté — coussin entre les genoux ; éviter le dos (langue et visage reculent)."

    static var all: [(title: String, detail: String)] {
        [
            (mewingTitle, mewingDetail),
            (postureTitle, postureDetail),
            (sideSleepTitle, sideSleepDetail)
        ]
    }
}
