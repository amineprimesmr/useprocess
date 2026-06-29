//
//  useprocessApp.swift
//  useprocess
//

import SwiftUI
import FirebaseCore
import UIKit

final class ProcessAppDelegate: NSObject, UIApplicationDelegate {}

@main
struct useprocessApp: App {
    @UIApplicationDelegateAdaptor(ProcessAppDelegate.self) private var appDelegate

    init() {
        iOS26Stability.configureAtLaunch()
        FirebaseBootstrap.configure()
        ProcessMetricKitMonitor.shared.start()
        CoachIntelligenceNotificationService.configure()
        SubscriptionService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .task {
                    await PermissionsManager.shared.clearAppBadge()
                    await FaceScanReminderService.scheduleNextReminder(
                        after: FaceScanHistoryStore.shared.latestResult?.createdAt
                    )
                }
                .onAppear {
                    AppIntegrations.shared.refresh()
                }
        }
    }
}
