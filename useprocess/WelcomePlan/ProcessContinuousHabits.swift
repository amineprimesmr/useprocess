import Foundation

/// Habitudes 24/7 — affichées à part, jamais dans la checklist quotidienne.
enum ProcessContinuousHabits {

    static let mewingTitle = "Suction mew"
    static let mewingDetail = MewingIntelligenceGuide.suctionMewDetail

    static let deglutitionTitle = "Déglutition"
    static let deglutitionDetail = "« T » spot → sourire large + yeux ouverts → déglutition langue seule, sans joues."

    static let masticationTitle = "Mastication lente"
    static var masticationDetail: String {
        "\(ProcessDailyTargets.chewsPerBite) mâchées par bouchée — à chaque repas, toute la journée."
    }

    static let neckTitle = "Nuque droite"
    static let neckDetail = PostureIntelligenceGuide.neckAlignmentDetail

    static let sideSleepDetail = "Dormir sur le côté — coussin genoux + main sous tête ; dos = langue tombe, visage recule."

    static var all: [(title: String, detail: String)] {
        [
            (mewingTitle, mewingDetail),
            (deglutitionTitle, deglutitionDetail),
            (masticationTitle, masticationDetail),
            (neckTitle, neckDetail),
            ("Sommeil côté", sideSleepDetail)
        ]
    }
}
