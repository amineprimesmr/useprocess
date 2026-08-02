import SwiftUI

enum ProcessMainSection: String, CaseIterable, Identifiable, Hashable {
    case coach
    case plan
    case statistics
    case profile

    var id: String { rawValue }

    static let tabOrder: [ProcessMainSection] = [.plan, .statistics, .coach, .profile]

    var isShellTab: Bool {
        Self.tabOrder.contains(self)
    }

    var label: String {
        switch self {
        case .coach: "Process IA"
        case .plan: "Accueil"
        case .statistics: "Streak"
        case .profile: "Réglages"
        }
    }

    var icon: String {
        switch self {
        case .coach: "sparkles"
        case .plan: "house.fill"
        case .statistics: "flame.fill"
        case .profile: "gearshape.fill"
        }
    }
}

// MARK: - Tab bar icons

struct ProcessMainTabIcon: View {
    @Environment(\.appTheme) private var theme

    let section: ProcessMainSection
    var size: CGFloat = 22
    var isSelected: Bool = true
    /// Quand `false`, le rendu natif iOS 26 gère l’état sélectionné (tab bar système).
    var appliesSelectionStyle: Bool = true

    var body: some View {
        Image(systemName: section.icon)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(
                appliesSelectionStyle
                    ? (isSelected ? theme.primaryText : theme.secondaryText)
                    : theme.primaryText
            )
    }
}
