import Foundation
import Network
import SwiftUI

/// Contournements pour les bugs connus iOS 26+ / Xcode 26+ au lancement.
enum iOS26Stability {
    private static var didConfigure = false

    /// À appeler le plus tôt possible — avant Firebase et le premier `UIHostingView`.
    static func configureAtLaunch() {
        guard !didConfigure else { return }
        didConfigure = true

        // Bug connu Xcode 26+ : crash si URLSession n'est pas initialisé avant d'autres SDK réseau.
        _ = URLSessionConfiguration.default
        _ = URLSessionConfiguration.ephemeral
        if #available(iOS 14.0, *) {
            _ = nw_tls_create_options()
        }
    }

    /// Active les contournements SwiftUI (animations, glass, etc.) sur OS récents.
    static var isEnabled: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// Délai avant de monter une hiérarchie avec gestes / materials.
    static var bootstrapDelayNanoseconds: UInt64 {
        isEnabled ? 600_000_000 : 0
    }
}

extension View {
    /// Désactive les `.animation(_:value:)` implicites sur iOS 26+ (bug CALayer).
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
