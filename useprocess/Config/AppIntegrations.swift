import Foundation

@MainActor
@Observable
final class AppIntegrations {
    static let shared = AppIntegrations()

    private(set) var firebaseReady = false
    private(set) var authReady = false

    private init() {}

    func refresh() {
        firebaseReady = AppConfiguration.firebaseConfigured
        authReady = firebaseReady && AuthUser.current != nil
        SubscriptionService.shared.configure()
    }

    var summary: String {
        if !firebaseReady { return "Firebase non configuré" }
        let sub = SubscriptionService.shared.subscriptionStatus.isActive ? "Premium actif" : "Premium inactif"
        return authReady ? "Firebase · Auth · \(sub)" : "Firebase · Auth en attente · \(sub)"
    }
}
