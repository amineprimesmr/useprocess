import SwiftUI

// MARK: - Section Cardio et Circuit (page Plan)

struct PlanTrainingDaySection: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var selectedDate: Date = Date()
    var isEditable: Bool = true

    @Environment(\.appTheme) private var theme
    @Bindable private var tutorialStore = PlanHomeTutorialStore.shared

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

            trainingCarouselBody
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

    @ViewBuilder
    private var trainingCarouselBody: some View {
        if tutorialStore.isFocused(.training) {
            VStack(alignment: .leading, spacing: 22) {
                trainingCarousel(highlightsItemStrip: true)

                PlanHomeTutorialCaption(step: tutorialStore.currentStep)
                PlanHomeTutorialInlineFooter(
                    onAdvance: { tutorialStore.advance() },
                    stepIndex: tutorialStore.currentStepIndex,
                    stepCount: tutorialStore.steps.count
                )
            }
            .id(PlanHomeTutorialFocus.training.scrollAnchorID)
        } else {
            trainingCarousel(highlightsItemStrip: false)
                .opacity(tutorialStore.isRevealed(.training) ? 0.88 : 1)
        }
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
