import UIKit

@MainActor
enum ScreenMetrics {
    static var activeScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .screen
    }

    static var bounds: CGRect {
        activeScreen?.bounds ?? .zero
    }

    static var width: CGFloat { bounds.width }
    static var height: CGFloat { bounds.height }
}

extension UIView {
    var resolvedScreenBounds: CGRect {
        window?.windowScene?.screen.bounds ?? ScreenMetrics.bounds
    }
}

extension UIViewController {
    var resolvedScreenBounds: CGRect {
        view.window?.windowScene?.screen.bounds ?? ScreenMetrics.bounds
    }
}
