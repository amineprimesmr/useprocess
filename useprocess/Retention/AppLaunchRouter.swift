import Foundation

/// Route les lancements via Quick Action vers l’offre lifetime winback.
@MainActor
@Observable
final class AppLaunchRouter {
    static let shared = AppLaunchRouter()

    private(set) var pendingLifetimeOfferSource: ProcessHomeScreenQuickActionKind?
    var showsLifetimeRetentionOffer = false

    private init() {}

    func handleShortcut(type: String) {
        guard let kind = ProcessHomeScreenQuickActionKind.resolve(shortcutType: type) else { return }

        pendingLifetimeOfferSource = kind
        ProcessAnalytics.trackQuickActionOpened(kind: kind.analyticsSource)
        presentLifetimeOfferIfEligible()
    }

    func flushPendingPresentation() {
        presentLifetimeOfferIfEligible()
    }

    func clearLifetimeOfferPresentation() {
        showsLifetimeRetentionOffer = false
        pendingLifetimeOfferSource = nil
    }

    var activeLifetimeOfferSource: ProcessHomeScreenQuickActionKind {
        pendingLifetimeOfferSource ?? .lifetimeOffer
    }

    private func presentLifetimeOfferIfEligible() {
        guard pendingLifetimeOfferSource != nil else { return }
        guard shouldPresentLifetimeOffer else { return }
        guard !showsLifetimeRetentionOffer else { return }

        Task { @MainActor in
            await Task.yield()
            guard pendingLifetimeOfferSource != nil, shouldPresentLifetimeOffer else { return }
            showsLifetimeRetentionOffer = true
        }
    }

    private var shouldPresentLifetimeOffer: Bool {
        guard SubscriptionConfiguration.retentionQuickActionLifetimeOfferEnabled else { return false }
        guard !SubscriptionService.shared.subscriptionStatus.isActive else { return false }
        return true
    }
}
