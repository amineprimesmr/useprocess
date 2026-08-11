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

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        Task { @MainActor in
            for context in URLContexts {
                handleIncomingURL(context.url)
            }
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        Task { @MainActor in
            handleIncomingURL(url)
        }
    }

    @MainActor
    private func handleIncomingURL(_ url: URL) {
        if ProcessReferralLink.parseCode(from: url) != nil {
            ProcessReferralAttribution.capture(from: url)
            NotificationCenter.default.post(name: .processReferralCodeCaptured, object: nil)
        } else {
            AppLaunchRouter.shared.handleHydrationURL(url)
        }
    }
}
