import SwiftUI

/// Redirige vers l'onglet Plan (contenu unifié — remplace l'ancien hub plein écran).
struct OriginPlanHubView: View {
    let plan: FaceOriginPlan
    @Binding var selectedSection: ProcessMainSection

    var body: some View {
        PlanDashboardView(selectedSection: $selectedSection)
            .onAppear {
                selectedSection = .plan
            }
    }
}
