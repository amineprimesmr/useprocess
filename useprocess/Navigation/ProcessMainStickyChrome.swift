import SwiftUI
import UIKit

enum ProcessMainChromeMetrics {
    static var topSafeInset: CGFloat { UIApplication.safeAreaTop }

    static var filterBarHeight: CGFloat { LayoutConstants.isIPad ? 52 : 40 }

    /// Padding haut quand l’overlay ignore la safe area (une seule fois).
    static var menuTopInset: CGFloat {
        topSafeInset + (LayoutConstants.isIPad ? 4 : 2)
    }

    static var menuBottomInset: CGFloat { 0 }

    static var scrollTopInset: CGFloat { menuTopInset + filterBarHeight + menuBottomInset }
}

struct CoachSidebarOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CoachSidebarProgressKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ProfileSubrouteActiveKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func reportsProfileSubrouteActive(_ isActive: Bool) -> some View {
        preference(key: ProfileSubrouteActiveKey.self, value: isActive)
    }
}

struct ProcessMainStickyChromeOverlay: View {
    @Binding var selection: ProcessMainSection
    var lockedSections: Set<ProcessMainSection> = []

    var body: some View {
        ProcessMainFilterBar(selection: $selection, lockedSections: lockedSections)
            .padding(.top, ProcessMainChromeMetrics.menuTopInset)
    }
}

struct CoachMainStickyChromeLayer: View {
    @Binding var selection: ProcessMainSection
    var lockedSections: Set<ProcessMainSection> = []
    var profileSubrouteActive: Bool

    @Bindable private var sidebar = CoachSidebarPresentation.shared

    private var opacity: Double {
        if selection == .profile && profileSubrouteActive { return 0 }
        if selection == .coach { return Double(1 - sidebar.progress) }
        return 1
    }

    var body: some View {
        ProcessMainStickyChromeOverlay(
            selection: $selection,
            lockedSections: lockedSections
        )
        .frame(maxWidth: .infinity, alignment: .top)
        .opacity(opacity)
        .allowsHitTesting(opacity > 0.05)
        .animation(.none, value: sidebar.progress)
    }
}
