import Foundation

enum OriginMealSuggestionService {

    enum RequestMode: Equatable {
        case fresh
        case another(previous: String)
        case modify(current: String)
    }

    private static let systemPrompt = """
    Tu es le coach nutrition Process (Protocole Origine debloat visage).
    Style Enzo : direct, tutoiement, bienveillant.

    RÈGLES :
    - Propose UN seul repas concret (pas un menu journée).
    - Aliments denses, peu transformés, protéines + tubercules/légumes cuits.
    - 2 à 4 phrases max. Pas de markdown. Pas de diagnostic médical.
    - Commence par le nom du repas, puis ingrédients et préparation rapide.
    """

    @MainActor
    static func suggest(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        mode: RequestMode = .fresh
    ) async throws -> String {
        let context = UserContextBuilder.build(profile: profile)
        let principles = day.nutrition.principles.joined(separator: " · ")
        let foods = day.nutrition.foodsToday.joined(separator: ", ")

        let userPrompt: String
        switch mode {
        case .fresh:
            userPrompt = """
            \(UserContextBuilder.compactPromptBlock(from: context))

            Jour protocole : \(day.title)
            Principes du jour : \(principles)
            Aliments à privilégier : \(foods)
            Hydratation : \(day.nutrition.hydration)

            Propose une idée de repas pour mon prochain repas aujourd'hui.
            """
        case .another(let previous):
            userPrompt = """
            \(UserContextBuilder.compactPromptBlock(from: context))

            Repas déjà proposé (à ne pas répéter) :
            \(previous)

            Propose un AUTRE repas différent, toujours aligné protocole Origine.
            """
        case .modify(let current):
            userPrompt = """
            \(UserContextBuilder.compactPromptBlock(from: context))

            Repas actuel :
            \(current)

            Propose une VARIANTE ajustée (portions, accompagnement ou cuisson) — même esprit, légèrement modifié.
            """
        }

        let text = try await CoachAPITransport.complete(
            task: .chat,
            system: systemPrompt + "\n\nObjectif plan : \(plan.primaryFaceGoal)",
            userText: userPrompt,
            model: ClaudeModel.preferred(for: .chat),
            maxTokens: 320
        )

        return CoachFormattedText.sanitizeField(text)
    }
}
