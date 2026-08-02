import SwiftUI

struct CoachMessageEnrichmentView: View {
    let enrichment: CoachMessageEnrichment
    var showsFollowUps: Bool
    var onFollowUp: (String) -> Void
    var onDeepLink: (CoachDeepLink) -> Void
    var onContextualAction: ((CoachContextualAction) -> Void)? = nil

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsFollowUps, !enrichment.followUps.isEmpty {
                followUpChips
            }

            if let onContextualAction, !enrichment.contextualActions.isEmpty {
                CoachContextualActionButtons(
                    actions: enrichment.contextualActions,
                    onAction: onContextualAction
                )
            }

            if let deepLink = enrichment.deepLink {
                deepLinkButton(deepLink)
            }
        }
        .padding(.top, 6)
    }

    private var followUpChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(enrichment.followUps.enumerated()), id: \.offset) { _, question in
                    let chipShape = Capsule(style: .continuous)
                    Button {
                        HapticManager.shared.impact(.light)
                        onFollowUp(question)
                    } label: {
                        Text(question)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(chipShape)
                    }
                    .processGlassButton(in: chipShape)
                }
            }
        }
    }

    private func deepLinkButton(_ link: CoachDeepLink) -> some View {
        CoachDeepLinkButton(
            link: link,
            theme: theme,
            onTap: { onDeepLink(link) }
        )
    }
}

private struct CoachDeepLinkButton: View {
    let link: CoachDeepLink
    let theme: AppTheme
    let onTap: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: link.action))
                    .font(.system(size: 13, weight: .semibold))
                Text(link.label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(shape)
        }
        .processGlassButton(in: shape)
    }

    private func icon(for action: CoachDeepLinkAction) -> String {
        switch action {
        case .plan: return "calendar"
        case .journal: return "checklist"
        case .scan: return "face.smiling"
        case .streak: return "flame.fill"
        case .integration: return "circle.dashed"
        }
    }
}
