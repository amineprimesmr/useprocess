import SwiftUI
import UIKit

enum ProcessMainSection: String, CaseIterable, Identifiable, Hashable {
    case coach
    case plan
    case scan
    case routine
    case statistics
    case profile
    case food

    var id: String { rawValue }

    static let isCoachTabEnabled = false

    static var tabOrder: [ProcessMainSection] {
        var tabs: [ProcessMainSection] = [.plan, .food, .routine]
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
        case .scan: AppCopy.t("Scan", en: "Scan")
        case .routine: AppCopy.t("Routine", en: "Routine")
        case .statistics: AppCopy.t("Série", en: "Streak")
        case .profile: AppCopy.t("Progrès", en: "Progress")
        case .food: AppCopy.t("Alimentation", en: "Food")
        }
    }

    var icon: String {
        switch self {
        case .coach: "sparkles"
        case .plan: "house.fill"
        case .scan: "viewfinder"
        case .routine: "checklist"
        case .statistics: "flame.fill"
        case .profile: "person.fill"
        case .food: "fork.knife"
        }
    }

    /// Icône custom tab bar (Assets) — `nil` = SF Symbol fallback.
    var tabIconAsset: String? {
        switch self {
        case .plan: "tab_icon_home"
        case .scan: nil
        case .routine: nil
        case .statistics: "tab_icon_streak"
        case .profile: "tab_icon_streak"
        case .coach: nil
        case .food: nil
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

