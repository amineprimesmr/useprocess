import Foundation

struct CoachMealHandoff: Equatable {
    let meal: MealSuggestionContent
    let slot: MealTimeSlot
    let dayId: String
    let dayTitle: String
    let dayIndex: Int
}

enum CoachMealHandoffBuilder {
    private static let answerStyle = " Réponds en 2-3 phrases, tutoiement, concret, sans markdown."

    static func homePrompt(for handoff: CoachMealHandoff, profile: UnifiedUserProfile?) -> CoachHomePrompt {
        let trimmedName = profile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let greeting: String
        if trimmedName.isEmpty {
            greeting = "On travaille sur \(handoff.meal.name) pour \(handoff.slot.rawValue)."
        } else {
            greeting = "\(trimmedName), on travaille sur \(handoff.meal.name) pour \(handoff.slot.rawValue)."
        }

        return CoachHomePrompt(
            kind: .greeting,
            greetingText: greeting,
            primaryActionTitle: nil,
            replacesChatInput: false,
            suggestions: suggestions(for: handoff)
        )
    }

    static func suggestions(for handoff: CoachMealHandoff) -> [CoachHomeSuggestion] {
        let hint = mealHint(for: handoff)

        return [
            suggestion(
                id: "variant",
                title: "Variante",
                subtitle: "Adapter ce repas",
                icon: "🔄",
                question: "Propose une variante de ce repas adaptée à mes contraintes du jour.",
                hint: hint
            ),
            suggestion(
                id: "simpler",
                title: "Plus simple",
                subtitle: "Moins d'étapes",
                icon: "🌿",
                question: "Simplifie ce repas avec moins d'ingrédients et une préparation plus rapide.",
                hint: hint
            ),
            suggestion(
                id: "another",
                title: "Autre repas",
                subtitle: "Pour \(handoff.slot.rawValue)",
                icon: "🍽️",
                question: "Propose un autre repas différent pour \(handoff.slot.rawValue).",
                hint: hint
            ),
            suggestion(
                id: "substitution",
                title: "Substitution",
                subtitle: "Changer un ingrédient",
                icon: "↔️",
                question: "Je veux remplacer un ingrédient de ce repas — propose des alternatives compatibles.",
                hint: hint
            )
        ]
    }

    static func augmentedPrompt(_ base: String, handoff: CoachMealHandoff) -> String {
        let ingredients = handoff.meal.items
            .map { "\($0.name) \($0.quantity)" }
            .joined(separator: ", ")
        return """
        Repas ciblé : \(handoff.meal.name) (\(handoff.slot.rawValue), jour \(handoff.dayTitle)).
        Ingrédients : \(ingredients).
        Préparation : \(handoff.meal.prepSummary).

        \(base)
        """
    }

    private static func mealHint(for handoff: CoachMealHandoff) -> String {
        let ingredients = handoff.meal.items
            .map { "\($0.name) (\($0.quantity))" }
            .joined(separator: ", ")
        return "\(handoff.meal.name) — \(ingredients)"
    }

    private static func suggestion(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        question: String,
        hint: String
    ) -> CoachHomeSuggestion {
        let prompt = "\(question) Contexte : \(hint).\(answerStyle)"
        return CoachHomeSuggestion(
            id: id,
            label: title,
            subtitle: subtitle,
            icon: icon,
            prompt: prompt
        )
    }
}
