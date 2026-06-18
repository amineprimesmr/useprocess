import SwiftUI

enum ProcessMainSection: String, CaseIterable, Identifiable, Hashable {
    case coach
    case health
    case profile

    var id: String { rawValue }

    /// Onglets visibles dans le menu principal.
    static let menuSections: [ProcessMainSection] = [.coach, .health, .profile]

    /// Ordre des onglets dans le pager principal.
    static let tabOrder: [ProcessMainSection] = menuSections

    var label: String {
        switch self {
        case .coach: "Coach"
        case .health: "Santé"
        case .profile: "Profil"
        }
    }

    var icon: String {
        switch self {
        case .coach: "sparkles"
        case .health: "heart.text.square.fill"
        case .profile: "person.crop.circle.fill"
        }
    }

    /// Icône asset custom (ex. ProcessIA pour le coach).
    var assetIconName: String? {
        switch self {
        case .coach: "ProcessIA"
        default: nil
        }
    }
}

struct ProcessMainFilterBar: View {
    @Binding var selection: ProcessMainSection
    var lockedSections: Set<ProcessMainSection> = []
    var glassAnimationsEnabled: Bool = true
    @Namespace private var chipNamespace
    @Environment(\.colorScheme) private var colorScheme

    private var isRegularLayout: Bool { LayoutConstants.isIPad }

    private var chipSpacing: CGFloat { isRegularLayout ? 16 : 10 }
    private var chipFontSize: CGFloat { isRegularLayout ? 18 : 16 }
    private var chipHorizontalPadding: CGFloat { isRegularLayout ? 26 : 18 }
    private var chipVerticalPadding: CGFloat { isRegularLayout ? 15 : 12 }
    private var chipAssetIconSize: CGFloat { isRegularLayout ? 26 : 22 }
    private var chipSystemIconSize: CGFloat { isRegularLayout ? 19 : 17 }
    private var lockIconSize: CGFloat { isRegularLayout ? 14 : 12 }
    private var horizontalInset: CGFloat { isRegularLayout ? 32 : 16 }

    private var selectedFill: Color { colorScheme == .dark ? .white : .black }
    private var selectedLabel: Color { colorScheme == .dark ? .black : .white }

    var body: some View {
        filterContent
            .padding(.top, isRegularLayout ? 4 : 2)
            .padding(.bottom, isRegularLayout ? 10 : 8)
    }

    private var filterContent: some View {
        HStack(spacing: chipSpacing) {
            ForEach(ProcessMainSection.menuSections) { item in
                filterChip(item)
            }
        }
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: isRegularLayout ? .center : .leading)
        .animation(ProcessGlass.spring, value: selection)
    }

    private func filterChip(_ item: ProcessMainSection) -> some View {
        let isSelected = selection == item
        let isLocked = lockedSections.contains(item)

        return Button {
            guard selection != item else { return }
            if isLocked {
                HapticManager.shared.notification(.warning)
            } else {
                HapticManager.shared.selection()
            }
            withAnimation(ProcessGlass.spring) {
                selection = item
            }
        } label: {
            HStack(spacing: isRegularLayout ? 9 : 7) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: lockIconSize, weight: .semibold))
                        .opacity(0.7)
                } else {
                    chipIcon(for: item, isSelected: isSelected)
                }
                Text(item.label)
                    .font(.system(size: chipFontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? selectedLabel : Color.primary)
            .opacity(isLocked && !isSelected ? 0.58 : 1)
            .padding(.horizontal, chipHorizontalPadding)
            .padding(.vertical, chipVerticalPadding)
            .background {
                ProcessFilterChipBackground(
                    isSelected: isSelected,
                    glassAnimationsEnabled: glassAnimationsEnabled,
                    selectedFill: selectedFill,
                    namespace: chipNamespace
                )
            }
        }
        .buttonStyle(.plain)
        .buttonStyle(ProcessGlassPressStyle())
    }

    @ViewBuilder
    private func chipIcon(for item: ProcessMainSection, isSelected: Bool) -> some View {
        if let asset = item.assetIconName {
            Image(asset)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: chipAssetIconSize, height: chipAssetIconSize)
        } else {
            Image(systemName: item.icon)
                .font(.system(size: chipSystemIconSize, weight: .semibold))
        }
    }
}

private struct ProcessFilterChipBackground: View {
    let isSelected: Bool
    let glassAnimationsEnabled: Bool
    let selectedFill: Color
    let namespace: Namespace.ID

    var body: some View {
        if isSelected {
            if #available(iOS 26.0, *) {
                Capsule()
                    .fill(.clear)
                    .glassEffect(ProcessGlass.filterSelected(selectedFill), in: .capsule)
                    .glassEffectID("filter-selection", in: namespace)
            } else {
                Capsule()
                    .fill(selectedFill)
                    .matchedGeometryEffect(id: "filter-selection", in: namespace)
            }
        } else if #available(iOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(ProcessGlass.regular, in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

/// Barre de sections flottante en bas (profil Totem).
struct ProcessFloatingSectionBar: View {
    @Binding var selection: ProcessMainSection

    var body: some View {
        ProcessMainFilterBar(selection: $selection)
            .padding(.bottom, 12)
    }
}
