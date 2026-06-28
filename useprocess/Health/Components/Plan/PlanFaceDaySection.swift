import SwiftUI

/// Routine matinale visage — carousel des 3 actions prioritaires.
struct PlanFaceDaySection: View {
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme
    @State private var selectedProtocolItem: PlanProtocolCarouselItem?

    private var faceProtocol: OriginFaceProtocol { plan.faceProtocol }

    private var targets: OriginPersonalizedDailyTargets {
        plan.personalizedTargets ?? .default
    }

    private var morningRoutineLines: [String] {
        FaceMorningRoutineCatalog.displaySteps(
            storedLines: faceProtocol.lymphAndFascia,
            targets: targets
        )
    }

    private var carouselItems: [PlanProtocolCarouselItem] {
        PlanProtocolCarouselBuilder.lineItems(
            from: morningRoutineLines,
            idPrefix: "morning",
            fallback: "sun.max.fill",
            category: "Routine matinale"
        )
    }

    var body: some View {
        let items = carouselItems
        let estimatedMinutes = FaceMorningRoutineCatalog.estimatedMinutes(targets: targets)

        VStack(alignment: .leading, spacing: PlanHomeSectionDesign.headerContentSpacing) {
            PlanProtocolSectionHeader(
                title: "Routine matinale",
                trailing: items.isEmpty ? nil : "\(items.count) étapes · ~\(estimatedMinutes) min"
            )

            if !faceProtocol.focusAreas.isEmpty {
                Text(faceProtocol.focusAreas.joined(separator: " · "))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if items.isEmpty {
                Text("Aucune étape matinale planifiée.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            } else {
                PlanDayProtocolCarousel(items: items) { item in
                    selectedProtocolItem = item
                }
            }
        }
        .sheet(item: $selectedProtocolItem) { item in
            PlanProtocolItemDetailSheet(item: item)
        }
    }
}
