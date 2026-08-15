import Foundation

struct CoachMealHandoff: Equatable {
    let meal: MealSuggestionContent
    let slot: MealTimeSlot
    let dayId: String
    let dayTitle: String
    let dayIndex: Int
}

enum CoachMealHandoffBuilder {
    @MainActor
    private static var answerStyle: String {
        AppCopy.t(
            """
             Réponds en français, tutoiement, concret.
            Si tu listes des options ou ingrédients, mets chaque point sur une nouvelle ligne avec un tiret (– ).
            Pas de markdown (** #), pas de fiche repas structurée.
            """,
            en: """
             Reply in American English, concrete and direct.
            If you list options or ingredients, put each point on a new line with a dash (– ).
            No markdown (** #), no structured meal sheet.
            """
        )
    }

    @MainActor
    static func homePrompt(for handoff: CoachMealHandoff, profile: UnifiedUserProfile?) -> CoachHomePrompt {
        let trimmedName = profile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let greeting: String
        let mealName = handoff.meal.localizedDisplayName
        let slotTitle = handoff.slot.displayTitle
        if trimmedName.isEmpty {
            greeting = AppCopy.t(
                "On travaille sur \(mealName) pour \(slotTitle).",
                en: "Let's work on \(mealName) for \(slotTitle)."
            )
        } else {
            greeting = AppCopy.t(
                "\(trimmedName), on travaille sur \(mealName) pour \(slotTitle).",
                en: "\(trimmedName), let's work on \(mealName) for \(slotTitle)."
            )
        }

        return CoachHomePrompt(
            kind: .greeting,
            greetingText: greeting,
            primaryActionTitle: nil,
            replacesChatInput: false,
            suggestions: suggestions(for: handoff)
        )
    }

    @MainActor
    static func suggestions(for handoff: CoachMealHandoff) -> [CoachHomeSuggestion] {
        let hint = mealHint(for: handoff)

        return [
            suggestion(
                id: "variant",
                title: AppCopy.t("Variante", en: "Variant"),
                subtitle: AppCopy.t("Adapter ce repas", en: "Adapt this meal"),
                icon: "🔄",
                question: AppCopy.t(
                    "Propose une variante de ce repas adaptée à mes contraintes du jour.",
                    en: "Suggest a variant of this meal adapted to today's constraints."
                ),
                hint: hint
            ),
            suggestion(
                id: "simpler",
                title: AppCopy.t("Plus simple", en: "Simpler"),
                subtitle: AppCopy.t("Moins d'étapes", en: "Fewer steps"),
                icon: "🌿",
                question: AppCopy.t(
                    "Simplifie ce repas avec moins d'ingrédients et une préparation plus rapide.",
                    en: "Simplify this meal with fewer ingredients and faster prep."
                ),
                hint: hint
            ),
            suggestion(
                id: "substitution",
                title: AppCopy.t("Remplacer", en: "Substitute"),
                subtitle: AppCopy.t("Un ingrédient", en: "One ingredient"),
                icon: "↔️",
                question: AppCopy.t(
                    "Je n'ai pas un des ingrédients — par quoi je peux le remplacer ?",
                    en: "I'm missing one of the ingredients — what can I replace it with?"
                ),
                hint: hint
            )
        ]
    }

    @MainActor
    static func augmentedPrompt(_ base: String, handoff: CoachMealHandoff) -> String {
        let ingredients = handoff.meal.items
            .map { "\($0.name) \($0.quantity)" }
            .joined(separator: ", ")
        return AppCopy.t(
            """
            Repas ciblé : \(handoff.meal.name) (\(handoff.slot.displayTitle), jour \(handoff.dayTitle)).
            Ingrédients : \(ingredients).
            Préparation : \(handoff.meal.prepSummary).

            \(base)
            """,
            en: """
            Target meal: \(handoff.meal.name) (\(handoff.slot.displayTitle), day \(handoff.dayTitle)).
            Ingredients: \(ingredients).
            Prep: \(handoff.meal.prepSummary).

            \(base)
            """
        )
    }

    private static func mealHint(for handoff: CoachMealHandoff) -> String {
        let ingredients = handoff.meal.items
            .map { "\($0.name) (\($0.quantity))" }
            .joined(separator: ", ")
        return "\(handoff.meal.name) — \(ingredients)"
    }

    @MainActor
    private static func suggestion(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        question: String,
        hint: String
    ) -> CoachHomeSuggestion {
        let contextLabel = AppCopy.t("Contexte", en: "Context")
        let prompt = "\(question) \(contextLabel) : \(hint).\(answerStyle)"
        return CoachHomeSuggestion(
            id: id,
            label: title,
            subtitle: subtitle,
            icon: icon,
            prompt: prompt,
            userMessage: question
        )
    }
}
