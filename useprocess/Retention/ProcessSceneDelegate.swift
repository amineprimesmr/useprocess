import UIKit

/// Quick Actions au long-press — avec SwiftUI / UIScene, c’est le scene delegate qui reçoit l’action.
final class ProcessSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            AppLaunchRouter.shared.handleShortcut(type: shortcutItem.type)
            completionHandler(true)
        }
    }
}
