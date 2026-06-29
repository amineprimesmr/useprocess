import SwiftUI
import UniformTypeIdentifiers

/// Éditeur d’accueil — page identique à l’accueil, avec sections délimitées et réordonnables.
struct PlanHomeLayoutEditorSheet: View {
    let plan: FaceOriginPlan
    @Binding var selectedDate: Date
    @Binding var selectedSection: ProcessMainSection

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Bindable private var layoutStore = PlanHomeLayoutStore.shared
    @State private var draggingSection: PlanHomeSectionKind?

    var body: some View {
        ZStack {
            ProcessScreenBackground()

            processMainScrollableChrome(
                selectedSection: $selectedSection,
                pageSection: .plan
            ) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    PlanHomeTopChrome(
                        selectedSection: $selectedSection,
                        selectedDate: $selectedDate
                    )

                    DailyJournalChecklistView(
                        plan: plan,
                        selectedDate: $selectedDate,
                        showHeader: false,
                        showWeekStrip: false,
                        showChecklist: false,
                        homeLayoutEditMode: true,
                        draggingSection: $draggingSection
                    )
                    .environmentObject(HealthManager.shared)

                    editorHintCard
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                }
                .padding()
            }
            .onDrop(
                of: [.text],
                delegate: PlanHomeSectionDragCancelDelegate(draggingSection: $draggingSection)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            editorTopBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .processClearUIKitHostingBackground()
        .processAppPageBackground()
        .processAppPresentationBackground()
        .onAppear {
            layoutStore.reload()
        }
    }

    private var editorTopBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                    layoutStore.resetToDefault()
                }
                HapticManager.shared.notification(.success)
            } label: {
                Text("Réinitialiser")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            VStack(spacing: 2) {
                Text("Réorganiser l’accueil")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                Text("Glisse · masque · réordonne")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer(minLength: 8)

            Button {
                HapticManager.shared.impact(.light)
                dismiss()
            } label: {
                Text("OK")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.onboardingAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(theme.onboardingAccent.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.cardStroke.opacity(theme.isDark ? 0.35 : 0.5))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)
        }
    }

    private var editorHintCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(theme.onboardingAccent.opacity(0.12))
                )

            Text("Maintiens et glisse une section pour changer l’ordre. L’œil masque ou réaffiche un bloc sur l’accueil.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.isDark ? theme.cardBackgroundStrong.opacity(0.65) : theme.coachUserBubble)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(theme.cardStroke.opacity(0.6), lineWidth: 0.5)
                }
        )
    }
}

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
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Masquer la section" : "Afficher la section")
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

/// Annule le glisser si le geste se termine hors d'une section.
struct PlanHomeSectionDragCancelDelegate: DropDelegate {
    @Binding var draggingSection: PlanHomeSectionKind?

    func validateDrop(info: DropInfo) -> Bool {
        draggingSection != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingSection = nil
        return true
    }
}

/// Bouton liquid glass — fin de page accueil (dans le scroll).
struct PlanHomeCustomizeFloatingButton: View {
    var zoomNamespace: Namespace.ID? = nil
    var action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button {
            HapticManager.shared.impact(.medium)
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.primaryText.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(theme.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                    )

                Text("Modifier l’accueil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primaryText.opacity(0.92))

                Spacer(minLength: 0)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .processGlassEffect(in: Capsule(), interactive: true)
        }
        .buttonStyle(ProcessGlassPressStyle())
        .processZoomSource(id: .homeLayoutEditor, namespace: zoomNamespace)
        .accessibilityLabel("Personnaliser la page d’accueil")
    }
}
