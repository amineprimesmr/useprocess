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
    }

    var body: some Scene {
        LaunchScreen(config: .init(forceHideLogo: false)) {
            Image("LaunchScreenLogo")
        } rootContent: {
            AppShellView()
                .onAppear {
                    AppIntegrations.shared.refresh()
                }
        }
    }
}
