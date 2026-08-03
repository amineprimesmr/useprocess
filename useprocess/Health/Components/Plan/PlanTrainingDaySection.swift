import SwiftUI

// MARK: - Section Cardio et Circuit (page Plan)

struct PlanTrainingDaySection: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var selectedDate: Date = Date()
    var isEditable: Bool = true

    @Environment(\.appTheme) private var theme

    @Namespace private var trainingZoomNamespace
    @State private var selectedProtocolItem: PlanProtocolCarouselItem?

    private var carouselItems: [PlanProtocolCarouselItem] {
        PlanProtocolCarouselBuilder.cardioAndCircuitItems(
            plan: plan,
            date: selectedDate
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PlanHomeSectionDesign.headerContentSpacing) {
            PlanProtocolSectionHeader(
                title: "Cardio et Circuit",
                trailing: nil
            )

            PlanDayProtocolCarousel(
                items: carouselItems,
                zoomNamespace: trainingZoomNamespace,
                zoomIDForItem: { zoomID(for: $0) },
                onTap: { selectedProtocolItem = $0 }
            )
            .processZoomSource(id: .postureCircuit, namespace: trainingZoomNamespace)
        }
        .sheet(item: $selectedProtocolItem) { item in
            PlanProtocolItemDetailSheet(item: item)
        }
    }

    private func zoomID(for item: PlanProtocolCarouselItem) -> ProcessZoomTransitionID {
        if item.id.hasPrefix("cardio-day") {
            return .protocolItem(item.id)
        }
        if item.id == "walking-steps" || item.id.hasPrefix("posture-") {
            return .postureCircuit
        }
        return .protocolItem(item.id)
    }
}
