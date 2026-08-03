//
//  useprocessApp.swift
//  useprocess
//

import SwiftUI
import UIKit

final class ProcessAppDelegate: NSObject, UIApplicationDelegate {}

@main
struct useprocessApp: App {
    @UIApplicationDelegateAdaptor(ProcessAppDelegate.self) private var appDelegate

    init() {
        // Sync avant tout View / Auth / AppSession — sinon Auth.auth() crashe le cold launch.
        iOS26Stability.configureAtLaunch()
        ProcessAudioSession.configureForMixingWithOthers()
        FirebaseBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .task {
                    // Idempotent si déjà fait dans init ; MetricKit / notifs hors chemin critique.
                    FirebaseBootstrap.configure()
                    ProcessMetricKitMonitor.shared.start()

                    await PermissionsManager.shared.clearAppBadge()
                    try? await Task.sleep(for: .milliseconds(300))
                    CoachIntelligenceNotificationService.configure()
                    SubscriptionService.shared.configure()
                }
                .onAppear {
                    AppIntegrations.shared.refresh()
                }
        }
    }
}
