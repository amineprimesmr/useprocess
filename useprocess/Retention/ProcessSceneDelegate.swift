import UIKit
import UserNotifications

/// Quick Actions au long-press — avec SwiftUI / UIScene, c’est le scene delegate qui reçoit l’action.
final class ProcessSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let response = connectionOptions.notificationResponse {
            Task { @MainActor in
                CoachNotificationCenterDelegate.shared.handleNotificationResponse(response)
            }
        }
        for context in connectionOptions.urlContexts {
            Task { @MainActor in
                ProcessAppsFlyer.shared.handleOpen(context.url)
                handleIncomingURL(context.url)
            }
        }
        if let activity = connectionOptions.userActivities.first {
            handleUserActivity(activity)
        }
    }

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
                ProcessAppsFlyer.shared.handleOpen(context.url)
                handleIncomingURL(context.url)
            }
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handleUserActivity(userActivity)
    }

    private func handleUserActivity(_ userActivity: NSUserActivity) {
        ProcessAppsFlyer.shared.continueUserActivity(userActivity)
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
        } else if ProcessReferralLink.isAcquisitionURL(url) {
            ProcessAcquisitionAttribution.capture(from: url)
        } else {
            ProcessAcquisitionAttribution.capture(from: url)
            AppLaunchRouter.shared.handleHydrationURL(url)
        }
    }
}
