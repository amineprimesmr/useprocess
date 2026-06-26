import SwiftUI

/// Protocole visage — routines du jour + habitudes orofaciales 24/7.
struct PlanFaceDaySection: View {
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme
    @State private var selectedProtocolItem: PlanProtocolCarouselItem?

    private var faceProtocol: OriginFaceProtocol { plan.faceProtocol }

    private var lymphLines: [String] {
        faceProtocol.lymphAndFascia
    }

    private var carouselItems: [PlanProtocolCarouselItem] {
        var items = PlanProtocolCarouselBuilder.lineItems(
            from: lymphLines,
            idPrefix: "lymph",
            fallback: "drop",
            category: "Lymphe & fascias"
        )

        if !faceProtocol.scanCadence.isEmpty {
            items += PlanProtocolCarouselBuilder.lineItems(
                from: [faceProtocol.scanCadence],
                idPrefix: "scan",
                fallback: "camera.viewfinder",
                category: "Scan visage"
            )
        }

        return items
    }

    var body: some View {
        let items = carouselItems

        VStack(alignment: .leading, spacing: 14) {
            PlanProtocolSectionHeader(
                title: "Protocole visage",
                trailing: items.isEmpty ? nil : "\(items.count) routines · ~15 min"
            )

            if !faceProtocol.focusAreas.isEmpty {
                Text(faceProtocol.focusAreas.joined(separator: " · "))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PlanContinuousHabitsInlineSection()

            if items.isEmpty {
                Text("Aucune routine visage planifiée pour ce jour.")
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
