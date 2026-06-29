import SwiftUI

/// Routine quotidienne — carousel matin + habitudes 24/7.
struct PlanFaceDaySection: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay

    @Bindable private var planStore = WelcomePlanStore.shared
    @Environment(\.appTheme) private var theme
    @Namespace private var protocolZoomNamespace
    @State private var selectedProtocolItem: PlanProtocolCarouselItem?

    private var livePlan: FaceOriginPlan {
        planStore.plan ?? plan
    }

    private var targets: OriginPersonalizedDailyTargets {
        livePlan.personalizedTargets ?? .default
    }

    private var carouselItems: [PlanProtocolCarouselItem] {
        FaceMorningRoutineCatalog.carouselItems(targets: targets)
    }

    private var isEditableToday: Bool {
        OriginPlanPresenter.isEditableJournalDay(dayId: day.id, in: livePlan)
    }

    var body: some View {
        let items = carouselItems
        let morningMinutes = FaceMorningRoutineCatalog.estimatedMinutes(targets: targets)

        VStack(alignment: .leading, spacing: PlanHomeSectionDesign.headerContentSpacing) {
            PlanProtocolSectionHeader(
                title: "Routine quotidienne",
                trailing: items.isEmpty
                    ? nil
                    : "\(items.count) actions · ~\(morningMinutes) min au réveil"
            )

            if items.isEmpty {
                Text("Aucune action quotidienne planifiée.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            } else {
                PlanDayProtocolCarousel(
                    items: items,
                    zoomNamespace: protocolZoomNamespace,
                    zoomIDForItem: { .protocolItem($0.id) },
                    onTap: { selectedProtocolItem = $0 },
                    routineDayId: isEditableToday ? day.id : nil,
                    isRoutineItemCompleted: { item in
                        planStore.isDailyRoutineItemCompleted(
                            carouselItemId: item.id,
                            dayId: day.id
                        )
                    },
                    onRoutineValidate: { item in
                        planStore.completeDailyRoutineItem(
                            carouselItemId: item.id,
                            dayId: day.id
                        )
                    }
                )
            }
        }
        .fullScreenCover(item: $selectedProtocolItem) { item in
            PlanProtocolItemDetailSheet(item: item)
                .processZoomTransition(id: .protocolItem(item.id), namespace: protocolZoomNamespace)
        }
    }
}
