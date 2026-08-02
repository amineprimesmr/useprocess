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
        // Bootstrap minimal sync — Firebase / MetricKit / gestures hors de ce chemin.
        iOS26Stability.configureAtLaunch()
        ProcessAudioSession.configureForMixingWithOthers()
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .task {
                    // Après le 1er frame : Firebase (si pas déjà tiré par Auth) + services.
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
