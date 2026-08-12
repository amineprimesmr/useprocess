import SwiftUI
import UIKit

enum ProcessMainSection: String, CaseIterable, Identifiable, Hashable {
    case coach
    case plan
    case statistics
    case profile

    var id: String { rawValue }

    static let isCoachTabEnabled = false

    static var tabOrder: [ProcessMainSection] {
        var tabs: [ProcessMainSection] = [.plan, .statistics]
        if isCoachTabEnabled {
            tabs.append(.coach)
        }
        tabs.append(.profile)
        return tabs
    }

    var isShellTab: Bool {
        Self.tabOrder.contains(self)
    }

    @MainActor
    var label: String {
        switch self {
        case .coach: AppCopy.t("Process IA", en: "Process AI")
        case .plan: AppCopy.home
        case .statistics: AppCopy.t("Série", en: "Streak")
        case .profile: AppCopy.profile
        }
    }

    var icon: String {
        switch self {
        case .coach: "sparkles"
        case .plan: "house.fill"
        case .statistics: "flame.fill"
        case .profile: "person.fill"
        }
    }

    /// Icône custom tab bar (Assets) — `nil` = SF Symbol fallback.
    var tabIconAsset: String? {
        switch self {
        case .plan: "tab_icon_home"
        case .statistics: "tab_icon_streak"
        case .profile: nil
        case .coach: nil
        }
    }

    func tabBarUIImage() -> UIImage? {
        if let asset = tabIconAsset, let image = UIImage(named: asset) {
            return Self.sizedTabIcon(image)
        }
        return UIImage(systemName: icon)?
            .withConfiguration(
                UIImage.SymbolConfiguration(
                    font: .systemFont(ofSize: ProcessIGTabMetrics.iconSize, weight: .semibold)
                )
            )
            .withRenderingMode(.alwaysTemplate)
    }

    private static func sizedTabIcon(_ image: UIImage) -> UIImage {
        let side = ProcessIGTabMetrics.iconSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: side, height: side)))
        }
        return rendered.withRenderingMode(.alwaysTemplate)
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
        Group {
            if let asset = section.tabIconAsset {
                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundStyle(
                        appliesSelectionStyle
                            ? (isSelected ? theme.primaryText : theme.secondaryText)
                            : theme.primaryText
                    )
            } else {
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
    }
}
