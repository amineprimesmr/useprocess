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
                }
                .onAppear {
                    AppIntegrations.shared.refresh()
                }
        }
    }
}
