import Foundation

/// Actions contextuelles quand le modèle n'a pas fourni des labels ACTION_*.
@MainActor
enum CoachContextualActionResolver {

    static func resolve(
        userText: String,
        assistantText: String,
        parsedActions: [CoachContextualAction],
        meal: MealSuggestionContent?,
        hasPendingPlanPatch: Bool
    ) -> [CoachContextualAction] {
        if !parsedActions.isEmpty {
            let filtered = filterPlanActions(
                parsedActions,
                userText: userText,
                assistantText: assistantText,
                hasPendingPlanPatch: hasPendingPlanPatch
            )
            let lowerUser = userText.lowercased()
            let lowerAssistant = assistantText.lowercased()
            if isMealDiscussion(lowerUser, lowerAssistant) {
                let mealFocused = filtered.filter { $0.kind != .swapWorkout }
                if !mealFocused.isEmpty {
                    return dedupe(mealFocused)
                }
            }
            return dedupe(filtered)
        }

        var actions: [CoachContextualAction] = []

        if let meal, meal.isValid {
            let slot = meal.timeSlot.rawValue
            actions.append(CoachContextualAction(kind: .validateMeal, payload: slot))
            actions.append(CoachContextualAction(kind: .modifyMeal, payload: slot))
            actions.append(CoachContextualAction(kind: .anotherMeal, payload: slot))
            actions.append(CoachContextualAction(kind: .addToShoppingList, payload: slot))
            return dedupe(actions)
        }

        if hasPendingPlanPatch,
           CoachPlanModificationService.shouldOfferPlanApplyActions(
               userText: userText,
               assistantText: assistantText,
               hasPendingPlanPatch: true
           ) {
            actions.append(CoachContextualAction(kind: .applyPlanChanges))
            if CoachPlanModificationService.shouldOfferOpenPlanAction(
                userText: userText,
                assistantText: assistantText,
                hasPendingPlanPatch: true
            ) {
                actions.append(CoachContextualAction(kind: .openPlan))
            }
            return dedupe(actions)
        }

        let lowerUser = userText.lowercased()
        let lowerAssistant = assistantText.lowercased()

        if isMealDiscussion(lowerUser, lowerAssistant) {
            if let meal, meal.isValid {
                let slot = meal.timeSlot.rawValue
                actions.append(CoachContextualAction(kind: .validateMeal, payload: slot))
                actions.append(CoachContextualAction(kind: .modifyMeal, payload: slot))
                actions.append(CoachContextualAction(kind: .anotherMeal, payload: slot))
            } else {
                actions.append(CoachContextualAction(
                    kind: .followUp,
                    label: "Enregistrer ce repas",
                    payload: "Je prends ce repas :"
                ))
                actions.append(CoachContextualAction(kind: .anotherMeal))
            }
            actions.append(CoachContextualAction(kind: .openJournal))
            return dedupe(actions)
        }

        if isTrainingContext(lowerUser, lowerAssistant) {
            actions.append(CoachContextualAction(kind: .swapWorkout))
            if CoachPlanModificationService.shouldOfferOpenPlanAction(
                userText: userText,
                assistantText: assistantText,
                hasPendingPlanPatch: hasPendingPlanPatch
            ) {
                actions.append(CoachContextualAction(kind: .openPlan))
            }
            return dedupe(actions)
        }

        if isPantryPhotoContext(lowerUser, lowerAssistant) {
            actions.append(CoachContextualAction(
                kind: .takePhoto,
                label: "Photographier mes ingrédients"
            ))
            actions.append(CoachContextualAction(
                kind: .followUp,
                label: "Décrire ce que j'ai",
                payload: "Voici ce que j'ai dans mon frigo et mes placards :"
            ))
            return dedupe(actions)
        }

        return []
    }

    private static func filterPlanActions(
        _ actions: [CoachContextualAction],
        userText: String,
        assistantText: String,
        hasPendingPlanPatch: Bool
    ) -> [CoachContextualAction] {
        let showApply = CoachPlanModificationService.shouldOfferPlanApplyActions(
            userText: userText,
            assistantText: assistantText,
            hasPendingPlanPatch: hasPendingPlanPatch
        )
        let showOpenPlan = CoachPlanModificationService.shouldOfferOpenPlanAction(
            userText: userText,
            assistantText: assistantText,
            hasPendingPlanPatch: hasPendingPlanPatch
        )
        return actions.filter { action in
            switch action.kind {
            case .applyPlanChanges: return showApply
            case .openPlan: return showOpenPlan
            default: return true
            }
        }
    }

    private static func dedupe(_ actions: [CoachContextualAction]) -> [CoachContextualAction] {
        var seen: Set<String> = []
        var result: [CoachContextualAction] = []
        for action in actions {
            let key = "\(action.kind.rawValue)|\(action.payload ?? "")"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(action)
        }
        return Array(result.prefix(4))
    }

    private static func isTrainingContext(_ user: String, _ assistant: String) -> Bool {
        let keywords = ["séance", "seance", "entraînement", "entrainement", "workout", "muscu", "exercice"]
        let userMentionsTraining = keywords.contains { user.contains($0) }
        let assistantFocusesTraining = keywords.contains { assistant.contains($0) }
            && !assistant.contains("dîner") && !assistant.contains("diner")
            && !assistant.contains("repas") && !assistant.contains("manger")
        return userMentionsTraining || assistantFocusesTraining
    }

    private static func isPantryPhotoContext(_ user: String, _ assistant: String) -> Bool {
        let asksInventory = ["frigo", "placard", "ingrédient", "ingredient", "stock", "courses"]
            .contains { assistant.contains($0) }
        let userHasPhotoIntent = user.contains("photo") || user.contains("image")
        return asksInventory && !userHasPhotoIntent
    }

    private static func isMealDiscussion(_ user: String, _ assistant: String) -> Bool {
        CoachMealMessageDetector.isMealRelated(userText: user)
            || CoachMealMessageDetector.isMealRelated(userText: assistant)
    }
}
