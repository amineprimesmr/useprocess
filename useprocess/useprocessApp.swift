//
//  useprocessApp.swift
//  useprocess
//

import SwiftUI
import FirebaseCore

@main
struct useprocessApp: App {
    init() {
        iOS26Stability.configureAtLaunch()
        FirebaseBootstrap.configure()
        SubscriptionService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .task {
                    await PermissionsManager.shared.clearAppBadge()
                    await FaceScanReminderService.scheduleMorningReminder()
                }
                .onAppear {
                    AppIntegrations.shared.refresh()
                }
        }
    }
}
