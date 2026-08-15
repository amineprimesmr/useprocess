//
//  useprocessApp.swift
//  useprocess
//

import SwiftUI
import UIKit
import UserNotifications

final class ProcessAppDelegate: NSObject, UIApplicationDelegate {
    private var pendingLaunchShortcut: UIApplicationShortcutItem?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Avant le 1er frame — sinon le tap notif cold-start est perdu
        // et l’app reprend l’onboarding (dashboard preview).
        UNUserNotificationCenter.current().delegate = CoachNotificationCenterDelegate.shared

        // Fallback sans UIScene (peu probable avec SwiftUI App).
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            pendingLaunchShortcut = shortcut
            return false
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            pendingLaunchShortcut = shortcut
        }

        let configuration = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = ProcessSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            AppLaunchRouter.shared.handleShortcut(type: shortcutItem.type)
            completionHandler(true)
        }
    }

    @MainActor
    func consumePendingLaunchShortcut() {
        guard let shortcut = pendingLaunchShortcut else { return }
        pendingLaunchShortcut = nil
        AppLaunchRouter.shared.handleShortcut(type: shortcut.type)
    }
}

@main
struct useprocessApp: App {
    @UIApplicationDelegateAdaptor(ProcessAppDelegate.self) private var appDelegate

    init() {
        // Sync avant tout View / Auth / AppSession — sinon Auth.auth() crashe le cold launch.
        iOS26Stability.configureAtLaunch()
        ProcessAppLanguage.shared.bootstrap()
        ProcessAudioSession.configureForMixingWithOthers()
        FirebaseBootstrap.configure()
        ProcessAnalytics.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .task {
                    // Idempotent si déjà fait dans init ; MetricKit / notifs hors chemin critique.
                    FirebaseBootstrap.configure()
                    ProcessAnalytics.configure()
                    ProcessMetricKitMonitor.shared.start()

                    await PermissionsManager.shared.clearAppBadge()
                    try? await Task.sleep(for: .milliseconds(300))
                    CoachIntelligenceNotificationService.configure()
                    SubscriptionService.shared.configure()
                    ProcessHomeScreenQuickActions.syncForCurrentUser()
                    AppLaunchRouter.shared.flushPendingPresentation()
                }
                .onAppear {
                    AppIntegrations.shared.refresh()
                }
        }
    }
}
