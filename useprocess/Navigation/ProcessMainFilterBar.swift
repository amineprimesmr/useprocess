import SwiftUI

enum ProcessMainSection: String, CaseIterable, Identifiable, Hashable {
    case coach
    case health
    case scan
    case profile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .coach: "Coach"
        case .health: "Santé"
        case .scan: "Scan"
        case .profile: "Profil"
        }
    }

    var icon: String {
        switch self {
        case .coach: "sparkles"
        case .health: "heart.text.square.fill"
        case .scan: "viewfinder"
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
    @Namespace private var glassNamespace
    @Environment(\.colorScheme) private var colorScheme

    private var selectedFill: Color { colorScheme == .dark ? .white : .black }
    private var selectedLabel: Color { colorScheme == .dark ? .black : .white }

    var body: some View {
        filterContent
            .padding(.top, 2)
            .padding(.bottom, 8)
    }

    private var filterContent: some View {
        HStack(spacing: 8) {
            ForEach(ProcessMainSection.allCases) { item in
                filterChip(item)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func filterChip(_ item: ProcessMainSection) -> some View {
        let isSelected = selection == item

        return Button {
            withAnimation(ProcessGlass.spring) {
                selection = item
            }
        } label: {
            HStack(spacing: 7) {
                chipIcon(for: item, isSelected: isSelected)
                Text(item.label)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? selectedLabel : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background {
            if #available(iOS 26.0, *) {
                EmptyView()
            } else if isSelected {
                Capsule().fill(selectedFill)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay {
            if #unavailable(iOS 26.0), !isSelected {
                Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
        }
        .modifier(ProcessFilterGlassChipModifier(
            isSelected: isSelected,
            id: item.id,
            namespace: glassNamespace,
            selectedFill: selectedFill
        ))
        .buttonStyle(ProcessGlassPressStyle())
    }

    @ViewBuilder
    private func chipIcon(for item: ProcessMainSection, isSelected: Bool) -> some View {
        if let asset = item.assetIconName {
            Image(asset)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: item.icon)
                .font(.system(size: 15, weight: .semibold))
        }
    }
}

private struct ProcessFilterGlassChipModifier: ViewModifier {
    let isSelected: Bool
    let id: String
    let namespace: Namespace.ID
    let selectedFill: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    isSelected
                        ? ProcessGlass.filterSelected(selectedFill)
                        : ProcessGlass.regular,
                    in: .capsule
                )
                .glassEffectID("filter-\(id)", in: namespace)
        } else {
            content
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
