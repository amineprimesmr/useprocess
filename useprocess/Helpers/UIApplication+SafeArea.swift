import UIKit

extension UIApplication {
    static var safeAreaTop: CGFloat {
        guard
            let scene = shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
        else { return 0 }
        return window.safeAreaInsets.top
    }

    static var safeAreaBottom: CGFloat {
        guard
            let scene = shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
        else { return 0 }
        return window.safeAreaInsets.bottom
    }
}
