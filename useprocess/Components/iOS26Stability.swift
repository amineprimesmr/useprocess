import SwiftUI

/// Contournements pour les bugs SwiftUI iOS 26 (CALayer rendering, gesture containers, `.glass`).
enum iOS26Stability {
    /// À appeler le plus tôt possible — avant le premier `UIHostingView`.
    static func configureAtLaunch() {
    }

    static var isEnabled: Bool {
        false
    }

    /// Délai avant de monter une hiérarchie avec gestes / materials.
    static var bootstrapDelayNanoseconds: UInt64 {
        isEnabled ? 600_000_000 : 0
    }
}

extension View {
    /// Désactive les `.animation(_:value:)` implicites sur iOS 26.
    @ViewBuilder
    func ios26SafeAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else if let animation {
            self.animation(animation, value: value)
        } else {
            self
        }
    }
}
