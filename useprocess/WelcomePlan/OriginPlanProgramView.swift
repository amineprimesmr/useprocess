import SwiftUI

struct OriginPlanProgramView: View {
    let plan: FaceOriginPlan
    @Binding var selectedSection: ProcessMainSection

    var body: some View {
        PlanDashboardView(selectedSection: $selectedSection)
    }
}
