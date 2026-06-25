import SwiftUI

struct CoachMessageEnrichmentView: View {
    let enrichment: CoachMessageEnrichment
    var showsReasoning: Bool
    var showsFollowUps: Bool
    var onFollowUp: (String) -> Void
    var onDeepLink: (CoachDeepLink) -> Void

    @Environment(\.appTheme) private var theme
    @State private var isReasoningExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsReasoning, let reasoning = enrichment.reasoning {
                reasoningBlock(reasoning)
            }

            if showsFollowUps, !enrichment.followUps.isEmpty {
                followUpChips
            }

            if let deepLink = enrichment.deepLink {
                deepLinkButton(deepLink)
            }
        }
        .padding(.top, 6)
    }

    private func reasoningBlock(_ reasoning: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isReasoningExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12, weight: .semibold))
                    Text(isReasoningExpanded ? "Masquer le raisonnement" : "Voir le raisonnement")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: isReasoningExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(theme.secondaryText)
            }
            .buttonStyle(.plain)

            if isReasoningExpanded {
                Text(reasoning)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.72))
        )
    }

    private var followUpChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(enrichment.followUps.enumerated()), id: \.offset) { _, question in
                    Button {
                        onFollowUp(question)
                    } label: {
                        Text(question)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.88 : 0.95))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(theme.secondaryText.opacity(0.16), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func deepLinkButton(_ link: CoachDeepLink) -> some View {
        Button {
            onDeepLink(link)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: deepLinkIcon(for: link.action))
                    .font(.system(size: 13, weight: .semibold))
                Text(link.label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.88 : 0.95))
            )
        }
        .buttonStyle(.plain)
    }

    private func deepLinkIcon(for action: CoachDeepLinkAction) -> String {
        switch action {
        case .plan: return "calendar"
        case .journal: return "checklist"
        case .scan: return "face.smiling"
        case .streak: return "flame.fill"
        case .integration: return "circle.dashed"
        }
    }
}
