import SwiftUI
import UIKit

enum ProcessMainChromeMetrics {
    static var topSafeInset: CGFloat { UIApplication.safeAreaTop }
    static var scrollTopInset: CGFloat { 0 }
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
