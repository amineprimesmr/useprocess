import SwiftUI

/// Éditeur d’accueil — même blocs que la page, masquer / réordonner.
struct PlanHomeLayoutEditorSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Bindable private var layoutStore = PlanHomeLayoutStore.shared
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(layoutStore.orderedSections.filter { $0 != .resources }) { section in
                    PlanHomeLayoutEditorRow(
                        section: section,
                        isVisible: layoutStore.isVisible(section),
                        onToggleVisibility: {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                layoutStore.toggleVisibility(for: section)
                            }
                            HapticManager.shared.impact(.light)
                        }
                    )
                }
                .onMove(perform: layoutStore.moveSections)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .processTransparentScrollSurface()
            .environment(\.editMode, $editMode)
            .navigationTitle("Personnaliser l’accueil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Réinitialiser") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                            layoutStore.resetToDefault()
                        }
                        HapticManager.shared.notification(.success)
                    }
                    .font(.subheadline.weight(.semibold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }
                        .font(.subheadline.weight(.bold))
                }
            }
        }
        .processAppPageBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct PlanHomeLayoutEditorRow: View {
    let section: PlanHomeSectionKind
    let isVisible: Bool
    var onToggleVisibility: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: section.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.onboardingAccent)
                .frame(width: 28, height: 28)

            Text(section.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(isVisible ? theme.primaryText : theme.secondaryText)

            Spacer(minLength: 8)

            Button(action: onToggleVisibility) {
                Image(systemName: isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isVisible ? theme.onboardingAccent : theme.secondaryText.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Masquer" : "Afficher")
        }
        .opacity(isVisible ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
    }
}

/// Bouton liquid glass — fin de page accueil (dans le scroll).
struct PlanHomeCustomizeFloatingButton: View {
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
        .accessibilityLabel("Personnaliser la page d’accueil")
    }
}
