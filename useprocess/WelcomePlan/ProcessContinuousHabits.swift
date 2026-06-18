import Foundation

/// Habitudes 24/7 — affichées à part, jamais dans la checklist quotidienne.
enum ProcessContinuousHabits {

    static let mewingTitle = "Mewing"
    static let mewingDetail = "Langue entière contre le palais, lèvres closes — 24 h/24, pas une tâche à cocher."

    static let deglutitionTitle = "Déglutition"
    static let deglutitionDetail = "Avale en gardant la langue sur le palais, sans pousser les joues — à chaque déglutition."

    static let masticationTitle = "Mastication lente"
    static var masticationDetail: String {
        "\(ProcessDailyTargets.chewsPerBite) mâchées par bouchée — à chaque repas, toute la journée."
    }

    static var all: [(title: String, detail: String)] {
        [
            (mewingTitle, mewingDetail),
            (deglutitionTitle, deglutitionDetail),
            (masticationTitle, masticationDetail)
        ]
    }
}
