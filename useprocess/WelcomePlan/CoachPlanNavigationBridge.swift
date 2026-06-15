import Foundation

@MainActor
@Observable
final class CoachPlanNavigationBridge {
    static let shared = CoachPlanNavigationBridge()

    var pendingPrompt: String?
    var pendingFocus: CoachPlanFocus?
    var shouldOpenCoach = false

    func askCoachAboutPlan(focus: CoachPlanFocus) {
        pendingFocus = focus
        pendingPrompt = promptForFocus(focus)
        shouldOpenCoach = true
    }

    func consumePendingFocus() -> CoachPlanFocus? {
        let focus = pendingFocus
        pendingFocus = nil
        return focus
    }

    func consumePendingPrompt() -> String? {
        let prompt = pendingPrompt
        pendingPrompt = nil
        return prompt
    }

    private func promptForFocus(_ focus: CoachPlanFocus) -> String {
        switch focus.mode {
        case .ask:
            return "J'ai une question sur cette partie de mon plan :\n\n[\(focus.sectionTitle)]\n\(focus.sectionContent)\n\nExplique-moi et dis-moi si c'est pertinent pour moi."
        case .evaluate:
            return """
            Évalue cette partie de mon Protocole Origine (pertinence 0–100, garder/modifier/remplacer, pourquoi) :

            [\(focus.sectionTitle)]
            \(focus.sectionContent)
            """
        case .modify:
            return """
            Je veux modifier cette partie de mon plan. Applique les changements directement dans mon calendrier :

            [\(focus.sectionTitle)]
            \(focus.sectionContent)

            Dis ce que tu changes concrètement (format Petit-déjeuner:/Déjeuner:/Dîner: si nutrition).
            """
        }
    }
}
