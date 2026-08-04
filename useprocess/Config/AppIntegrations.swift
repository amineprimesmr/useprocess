import Foundation

@MainActor
@Observable
final class AppIntegrations {
    static let shared = AppIntegrations()

    private(set) var firebaseReady = false
    private(set) var authReady = false
    private(set) var analyticsReady = false

    private init() {}

    func refresh() {
        firebaseReady = AppConfiguration.firebaseConfigured
        authReady = firebaseReady && AuthUser.current != nil
        analyticsReady = ProcessAnalytics.isReady
        SubscriptionService.shared.configure()
        ProcessAnalytics.configure()
    }

    var summary: String {
        if !firebaseReady { return "Firebase non configuré" }
        let sub = SubscriptionService.shared.subscriptionStatus.isActive ? "Premium actif" : "Premium inactif"
        let analytics = analyticsReady ? "PostHog" : "PostHog off"
        return authReady
            ? "Firebase · Auth · \(sub) · \(analytics)"
            : "Firebase · Auth en attente · \(sub) · \(analytics)"
    }
}
