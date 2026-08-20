import SwiftUI

// MARK: - Section éditable (conteneur délimité)

struct PlanHomeLayoutEditableSection<Content: View>: View {
    let section: PlanHomeSectionKind
    let isVisible: Bool
    let isDragging: Bool
    var onToggleVisibility: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionControlBar

            content()
                .opacity(isVisible ? 1 : 0.32)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.22), value: isVisible)
        }
        .padding(14)
        .background(sectionSurface)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .scaleEffect(isDragging ? 0.985 : 1)
        .shadow(
            color: isDragging ? theme.onboardingAccent.opacity(0.22) : Color.black.opacity(theme.isDark ? 0.18 : 0.06),
            radius: isDragging ? 16 : 10,
            y: isDragging ? 8 : 4
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isDragging)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isVisible)
    }

    private var sectionControlBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.secondaryText.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(theme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                )
                .accessibilityHidden(true)

            Image(systemName: section.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.onboardingAccent)
                .frame(width: 24)

            Text(section.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isVisible ? theme.primaryText : theme.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button(action: onToggleVisibility) {
                Image(systemName: isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isVisible ? theme.onboardingAccent : theme.secondaryText.opacity(0.65))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(theme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
            }
            .buttonStyle(.processPlain)
            .accessibilityLabel(
                isVisible
                    ? AppCopy.t("Masquer la section", en: "Hide section")
                    : AppCopy.t("Afficher la section", en: "Show section")
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
        )
    }

    private var sectionSurface: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(theme.isDark ? theme.cardBackgroundStrong.opacity(0.72) : theme.coachUserBubble)
    }

    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(
                isDragging ? theme.onboardingAccent.opacity(0.85) : theme.cardStroke.opacity(theme.isDark ? 0.45 : 0.65),
                lineWidth: isDragging ? 2 : 1
            )
    }
}

struct PlanHomeSectionDropDelegate: DropDelegate {
    let section: PlanHomeSectionKind
    let layoutStore: PlanHomeLayoutStore
    @Binding var draggingSection: PlanHomeSectionKind?

    func validateDrop(info: DropInfo) -> Bool {
        draggingSection != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingSection,
              dragging != section else { return }

        let ordered = layoutStore.orderedSections
        guard let from = ordered.firstIndex(of: dragging),
              let to = ordered.firstIndex(of: section),
              from != to else { return }

        HapticManager.shared.selection()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            layoutStore.moveSection(dragging, before: section)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingSection = nil
        HapticManager.shared.impact(.light)
        return true
    }
}
