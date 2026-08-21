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
        // Analytics avant abonnements.
        ProcessAnalytics.configure()
        ProcessCrispSupport.configure()
        analyticsReady = ProcessAnalytics.isReady
        PaywallPricingExperiment.shared.resolve()
        SubscriptionService.shared.configure()
    }

    var summary: String {
        if !firebaseReady {
            return AppCopy.t("Firebase non configuré", en: "Firebase not configured")
        }
        let sub = SubscriptionService.shared.subscriptionStatus.isActive
            ? AppCopy.t("Premium actif", en: "Premium active")
            : AppCopy.t("Premium inactif", en: "Premium inactive")
        let analytics = analyticsReady ? "PostHog" : "PostHog off"
        return authReady
            ? "Firebase · Auth · \(sub) · \(analytics)"
            : AppCopy.t(
                "Firebase · Auth en attente · \(sub) · \(analytics)",
                en: "Firebase · Auth pending · \(sub) · \(analytics)"
            )
    }
}
