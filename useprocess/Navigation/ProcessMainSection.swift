import SwiftUI

enum ProcessMainSection: String, CaseIterable, Identifiable, Hashable {
    case coach
    case plan
    case profile

    var id: String { rawValue }

    static let tabOrder: [ProcessMainSection] = [.plan, .profile]

    var isShellTab: Bool {
        self == .plan || self == .profile
    }

    var label: String {
        switch self {
        case .coach: "Coach"
        case .plan: "Accueil"
        case .profile: "Profil"
        }
    }

    var icon: String {
        switch self {
        case .coach: "sparkles"
        case .plan: "house.fill"
        case .profile: "person.crop.circle.fill"
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
