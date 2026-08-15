import SwiftUI

// MARK: - Section Cardio et Circuit (page Routine)

struct PlanTrainingDaySection: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var selectedDate: Date = Date()
    var isEditable: Bool = true

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
                title: PlanHomeSectionKind.training.title,
                trailing: nil
            )

            trainingCarousel(highlightsItemStrip: false)
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

    private func trainingCarousel(highlightsItemStrip: Bool) -> some View {
        PlanDayProtocolCarousel(
            items: carouselItems,
            zoomNamespace: trainingZoomNamespace,
            zoomIDForItem: { zoomID(for: $0) },
            onTap: { selectedProtocolItem = $0 },
            highlightsItemStrip: highlightsItemStrip
        )
        .processZoomSource(id: .postureCircuit, namespace: trainingZoomNamespace)
    }
}
