import SwiftUI
import UIKit

enum ProcessMainChromeMetrics {
    static var topSafeInset: CGFloat { UIApplication.safeAreaTop }
    static var scrollTopInset: CGFloat { 0 }
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
