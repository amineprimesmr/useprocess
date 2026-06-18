import SwiftUI

/// Redirige vers le hub unifié (compatibilité anciens appels).
struct OriginPlanProgramView: View {
    let plan: FaceOriginPlan

    var body: some View {
        OriginPlanHubView(plan: plan)
    }
}
