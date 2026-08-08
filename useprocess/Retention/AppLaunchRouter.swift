import Foundation

/// Route les lancements (Quick Action / notifs marketing) vers offre lifetime ou roue winback.
@MainActor
@Observable
final class AppLaunchRouter {
    static let shared = AppLaunchRouter()

    private(set) var pendingLifetimeOfferSource: ProcessHomeScreenQuickActionKind?
    var showsLifetimeRetentionOffer = false

    /// Deep-link notif → roue complète.
    var showsSpinWinbackFromMarketing = false
    private(set) var pendingSpinCampaignId: String?

    private init() {}

    func handleShortcut(type: String) {
        guard let kind = ProcessHomeScreenQuickActionKind.resolve(shortcutType: type) else { return }

        pendingLifetimeOfferSource = kind
        ProcessAnalytics.trackQuickActionOpened(kind: kind.analyticsSource)
        presentLifetimeOfferIfEligible()
    }

    /// Ouverture depuis une notif marketing (deep-link offre lifetime).
    func presentLifetimeOfferFromMarketing(campaignId: String) {
        ProcessMarketingNotificationService.shared.markOpened(campaignId: campaignId)
        showsSpinWinbackFromMarketing = false
        pendingSpinCampaignId = nil
        pendingLifetimeOfferSource = .lifetimeOffer
        presentLifetimeOfferIfEligible()
    }

    /// Ouverture depuis notif chase / spin_again → roue directe.
    func presentSpinWheelFromMarketing(campaignId: String) {
        ProcessMarketingNotificationService.shared.markOpened(campaignId: campaignId)
        ProcessMarketingNotificationService.shared.markSawSpinWheel()
        showsLifetimeRetentionOffer = false
        pendingLifetimeOfferSource = nil
        pendingSpinCampaignId = campaignId
        presentSpinIfEligible()
    }

    func flushPendingPresentation() {
        if pendingSpinCampaignId != nil {
            presentSpinIfEligible()
        } else {
            presentLifetimeOfferIfEligible()
        }
    }

    func clearLifetimeOfferPresentation() {
        showsLifetimeRetentionOffer = false
        pendingLifetimeOfferSource = nil
    }

    func clearSpinPresentation() {
        showsSpinWinbackFromMarketing = false
        pendingSpinCampaignId = nil
    }

    var activeLifetimeOfferSource: ProcessHomeScreenQuickActionKind {
        pendingLifetimeOfferSource ?? .lifetimeOffer
    }

    private func presentLifetimeOfferIfEligible() {
        guard pendingLifetimeOfferSource != nil else { return }
        guard shouldPresentRetention else { return }
        guard !showsLifetimeRetentionOffer else { return }
        guard !showsSpinWinbackFromMarketing else { return }

        Task { @MainActor in
            await Task.yield()
            guard pendingLifetimeOfferSource != nil, shouldPresentRetention else { return }
            guard !showsSpinWinbackFromMarketing else { return }
            showsLifetimeRetentionOffer = true
        }
    }

    private func presentSpinIfEligible() {
        guard pendingSpinCampaignId != nil else { return }
        guard shouldPresentRetention else {
            clearSpinPresentation()
            return
        }
        guard !showsSpinWinbackFromMarketing else { return }

        Task { @MainActor in
            await Task.yield()
            guard pendingSpinCampaignId != nil, shouldPresentRetention else { return }
            showsLifetimeRetentionOffer = false
            showsSpinWinbackFromMarketing = true
        }
    }

    private var shouldPresentRetention: Bool {
        guard SubscriptionConfiguration.retentionQuickActionLifetimeOfferEnabled else { return false }
        guard !SubscriptionService.shared.subscriptionStatus.isActive else { return false }
        return true
    }
}
