import SwiftUI

/// Circuit posture quotidien — carousel horizontal des blocs du jour.
struct PlanPostureDaySection: View {
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme
    @State private var selectedProtocolItem: PlanProtocolCarouselItem?

    private var protocolBlocks: [String] {
        var lines = plan.postureProtocol.mobilityBlocks
        if lines.isEmpty {
            lines = PostureIntelligenceGuide.defaultMobilityBlocks
        }
        return lines
    }

    private var breathingLines: [String] {
        plan.postureProtocol.breathingWork
    }

    private var carouselItems: [PlanProtocolCarouselItem] {
        var items = PlanProtocolCarouselBuilder.lineItems(
            from: protocolBlocks,
            idPrefix: "posture",
            fallback: "figure.cooldown"
        )

        items += PlanProtocolCarouselBuilder.lineItems(
            from: breathingLines,
            idPrefix: "breathing",
            fallback: "wind",
            category: "Respiration"
        )

        if !plan.postureProtocol.walkingTargets.isEmpty {
            items += PlanProtocolCarouselBuilder.lineItems(
                from: [plan.postureProtocol.walkingTargets],
                idPrefix: "walking",
                fallback: "figure.walk",
                category: "Marche"
            )
        }

        return items
    }

    var body: some View {
        let items = carouselItems

        VStack(alignment: .leading, spacing: 14) {
            PlanProtocolSectionHeader(
                title: "Posture & circuit quotidien",
                trailing: items.isEmpty ? nil : "\(items.count) ex. · ~10 min"
            )

            if items.isEmpty {
                Text("Circuit posture en cours de configuration.")
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
