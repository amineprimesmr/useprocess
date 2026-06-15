//
//  useprocessApp.swift
//  useprocess
//
//  Created by Amine Ennasri on 13/06/2026.
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
        WindowGroup {
            AppShellView()
                .onAppear {
                    AppIntegrations.shared.refresh()
                }
        }
    }
}
