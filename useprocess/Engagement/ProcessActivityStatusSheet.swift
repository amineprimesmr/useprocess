import SwiftUI

/// Flux statut d'activité — intro Bevel (grille 2×2) puis sélecteur liste.
struct ProcessActivityStatusSheet: View {
    @Binding var selectedDate: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Bindable private var store = ProcessActivityStatusStore.shared

    @State private var draft: ProcessActivityStatus
    @State private var phase: Phase

    private enum Phase {
        case intro
        case picker
    }

    private enum SheetMetrics {
        static let introSheetHeight: CGFloat = 500
        static let pickerSheetHeight: CGFloat = 548
        static let rowHeight: CGFloat = 72
        static let introTileHeight: CGFloat = 64
    }

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate
        let current = ProcessActivityStatusStore.shared.status(for: selectedDate.wrappedValue)
        _draft = State(initialValue: current)
        _phase = State(initialValue: ProcessActivityStatusStore.shared.hasSeenIntro ? .picker : .intro)
    }

    var body: some View {
        Group {
            switch phase {
            case .intro:
                introContent
            case .picker:
                pickerContent
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([sheetDetent])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private var sheetDetent: PresentationDetent {
        switch phase {
        case .intro:
            return .height(SheetMetrics.introSheetHeight)
        case .picker:
            return .height(SheetMetrics.pickerSheetHeight)
        }
    }

    // MARK: - Intro

    private var introContent: some View {
        VStack(spacing: 18) {
            HStack {
                Button {
                    HapticManager.shared.impact(.light)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .frame(width: 34, height: 34)
                        .processGlassCircle(interactive: true)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            introStatusGrid

            VStack(spacing: 10) {
                Text("Statut d'activité")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)

                Text(
                    "Définissez votre statut sur Actif(ve), Malade, Blessé(e) ou En pause. Process ajustera ses recommandations en fonction de votre état."
                )
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            }

            Button(action: confirmIntroSelection) {
                Text("Continuer")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.isDark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule(style: .continuous).fill(theme.isDark ? Color.white : Color.black))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private var introStatusGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]

        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach([ProcessActivityStatus.active, .injured, .sick, .paused]) { status in
                Button {
                    HapticManager.shared.selection()
                    draft = status
                } label: {
                    ProcessActivityStatusIntroTile(
                        status: status,
                        isSelected: draft == status
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Picker

    private var pickerContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    HapticManager.shared.impact(.light)
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .frame(width: 34, height: 34)
                        .processGlassCircle(interactive: true)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Statut d'activité")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Spacer()

                Color.clear.frame(width: 34, height: 34)
            }

            VStack(spacing: 10) {
                ForEach(ProcessActivityStatus.allCases) { status in
                    Button {
                        HapticManager.shared.selection()
                        draft = status
                    } label: {
                        ProcessActivityStatusPickerRow(
                            status: status,
                            isSelected: draft == status
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 12) {
                Button(action: applySelection) {
                    Text("Mettre à jour")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .processNeutralLiquidGlass(in: Capsule(style: .continuous), interactive: true)
                }
                .buttonStyle(.plain)

                Text("La mise à jour de votre statut historique l'appliquera à toutes les activités et tendances de cette journée.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 22)
    }

    private func confirmIntroSelection() {
        HapticManager.shared.impact(.medium)
        store.setStatus(draft, for: selectedDate)
        store.markIntroSeen()
        dismiss()
    }

    private func applySelection() {
        HapticManager.shared.impact(.medium)
        store.setStatus(draft, for: selectedDate)
        dismiss()
    }
}

// MARK: - Intro tile

private struct ProcessActivityStatusIntroTile: View {
    let status: ProcessActivityStatus
    let isSelected: Bool

    private let shape = Capsule(style: .continuous)

    var body: some View {
        ProcessActivityStatusIconBadge(status: status, size: 44, iconSize: 22)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .processNeutralLiquidGlass(in: shape, interactive: true)
            .overlay {
                shape.strokeBorder(
                    Color.primary.opacity(isSelected ? 0.22 : 0.10),
                    lineWidth: isSelected ? 2 : 1
                )
            }
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
            .accessibilityLabel(status.title)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Picker row

private struct ProcessActivityStatusPickerRow: View {
    let status: ProcessActivityStatus
    let isSelected: Bool

    @Environment(\.appTheme) private var theme

    private let shape = Capsule(style: .continuous)

    var body: some View {
        HStack(spacing: 14) {
            ProcessActivityStatusIconBadge(status: status, size: 44, iconSize: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(status.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Text(status.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .strokeBorder(isSelected ? theme.primaryText : theme.secondaryText.opacity(0.38), lineWidth: 2)
                    .frame(width: 24, height: 24)

                if isSelected {
                    Circle()
                        .fill(theme.primaryText)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 72)
        .processNeutralLiquidGlass(in: shape, interactive: true)
        .overlay {
            shape.strokeBorder(Color.primary.opacity(isSelected ? 0.16 : 0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Icône colorée (seul élément en couleur)

private struct ProcessActivityStatusIconBadge: View {
    let status: ProcessActivityStatus
    var size: CGFloat
    var iconSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(status.accentColor)

            Image(systemName: status.systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Liquid glass neutre

private extension View {
    @ViewBuilder
    func processNeutralLiquidGlass<S: InsettableShape>(
        in shape: S,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(
                interactive ? ProcessGlass.regular : ProcessGlass.regularSurface,
                in: shape
            )
        } else {
            processGlassEffect(in: shape, interactive: interactive)
        }
    }
}

// MARK: - Chrome badge (header)

struct ProcessActivityStatusBadge: View {
    let status: ProcessActivityStatus
    var size: CGFloat = 36
    var iconSize: CGFloat = 16

    var body: some View {
        ProcessActivityStatusIconBadge(status: status, size: size, iconSize: iconSize)
            .accessibilityLabel("Statut d'activité : \(status.title)")
    }
}
