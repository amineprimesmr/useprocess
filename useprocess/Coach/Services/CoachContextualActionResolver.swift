import Foundation

/// Actions contextuelles — uniquement quand une modification de plan est réellement à appliquer.
@MainActor
enum CoachContextualActionResolver {

    static func resolve(
        userText: String,
        assistantText: String,
        parsedActions: [CoachContextualAction],
        meal: MealSuggestionContent?,
        hasPendingPlanPatch: Bool
    ) -> [CoachContextualAction] {
        _ = userText
        _ = assistantText
        _ = meal

        let applyOnly = parsedActions.filter { $0.kind == .applyPlanChanges }
        let showApply = CoachPlanModificationService.shouldOfferPlanApplyActions(
            userText: userText,
            assistantText: assistantText,
            hasPendingPlanPatch: hasPendingPlanPatch
        )

        if showApply {
            if !applyOnly.isEmpty {
                return Array(applyOnly.prefix(1))
            }
            if hasPendingPlanPatch {
                return [CoachContextualAction(kind: .applyPlanChanges)]
            }
        }

        return []
    }
}
