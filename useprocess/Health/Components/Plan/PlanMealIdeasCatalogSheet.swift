import SwiftUI

/// Point d’entrée catalogue — hub aliments Debloat (visage dégonflé).
struct PlanMealIdeasCatalogSheet: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool
    let mealZoomNamespace: Namespace.ID

    var body: some View {
        DebloatFoodHubView(
            plan: plan,
            day: day,
            isEditable: isEditable
        )
    }
}
