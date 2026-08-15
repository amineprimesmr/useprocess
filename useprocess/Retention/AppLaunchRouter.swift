import Foundation

/// Route les lancements (Quick Action / notifs marketing) vers offre lifetime ou roue winback.
@MainActor
@Observable
final class AppLaunchRouter {
    static let shared = AppLaunchRouter()

    private static let pendingSpinKey = "process.launch.pendingSpinCampaign"
    private static let pendingLifetimeKey = "process.launch.pendingLifetimeCampaign"

    private(set) var pendingLifetimeOfferSource: ProcessHomeScreenQuickActionKind?
    var showsLifetimeRetentionOffer = false

    /// Deep-link notif → roue complète.
    var showsSpinWinbackFromMarketing = false
    private(set) var pendingSpinCampaignId: String?

    /// Deep-link Live Activity hydratation (bouton +500 / ouverture).
    var pendingHydrationAction: ProcessHydrationDeepLinkAction?

    private init() {
        if let spin = UserDefaults.standard.string(forKey: Self.pendingSpinKey), !spin.isEmpty {
            pendingSpinCampaignId = spin
        } else if UserDefaults.standard.bool(forKey: Self.pendingLifetimeKey) {
            pendingLifetimeOfferSource = .lifetimeOffer
        }
    }

    func handleHydrationURL(_ url: URL) {
        guard let action = ProcessHydrationDeepLink.parse(url) else { return }
        pendingHydrationAction = action
        Task { @MainActor in
            // Laisse l'accueil monter avant scroll + animation eau.
            try? await Task.sleep(for: .milliseconds(280))
            await flushHydrationActionIfNeeded()
        }
    }

    @MainActor
    func flushHydrationActionIfNeeded() async {
        guard let action = pendingHydrationAction else { return }
        pendingHydrationAction = nil

        switch action {
        case .open:
            await ProcessHydrationTimerStore.shared.syncLiveActivityHydration()
        case .sip(let milliliters):
            if ProcessHydrationTimerStore.shared.isRunning {
                _ = await ProcessHydrationTimerStore.shared.logSip(
                    milliliters: milliliters,
                    celebrateOnHome: true
                )
            } else {
                let before = ProcessHydrationLogStore.shared.milliliters()
                _ = ProcessHydrationLogStore.shared.addWater(
                    milliliters: milliliters,
                    dayId: nil,
                    targetMilliliters: ProcessDailyTargets.hydrationTargetMilliliters
                )
                ProcessHydrationSipCelebrationCoordinator.shared.requestHomeCelebration(fromMilliliters: before)
            }
            ProcessHydrationTimerPresenter.shared.clear()
        }
    }

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
        UserDefaults.standard.removeObject(forKey: Self.pendingSpinKey)
        pendingLifetimeOfferSource = .lifetimeOffer
        UserDefaults.standard.set(true, forKey: Self.pendingLifetimeKey)
        presentLifetimeOfferIfEligible()
    }

    /// Ouverture depuis notif chase / spin_again → roue directe.
    func presentSpinWheelFromMarketing(campaignId: String) {
        ProcessMarketingNotificationService.shared.markOpened(campaignId: campaignId)
        ProcessMarketingNotificationService.shared.markSawSpinWheel()
        showsLifetimeRetentionOffer = false
        pendingLifetimeOfferSource = nil
        UserDefaults.standard.removeObject(forKey: Self.pendingLifetimeKey)
        pendingSpinCampaignId = campaignId
        UserDefaults.standard.set(campaignId, forKey: Self.pendingSpinKey)
        presentSpinIfEligible()
    }

    func flushPendingPresentation() {
        if pendingSpinCampaignId != nil {
            presentSpinIfEligible()
        } else {
            presentLifetimeOfferIfEligible()
        }
        Task { @MainActor in
            await flushHydrationActionIfNeeded()
        }
    }

    func clearLifetimeOfferPresentation() {
        showsLifetimeRetentionOffer = false
        pendingLifetimeOfferSource = nil
        UserDefaults.standard.removeObject(forKey: Self.pendingLifetimeKey)
    }

    func clearSpinPresentation() {
        showsSpinWinbackFromMarketing = false
        pendingSpinCampaignId = nil
        UserDefaults.standard.removeObject(forKey: Self.pendingSpinKey)
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
        guard shouldPresentRetention else { return }
        guard !showsSpinWinbackFromMarketing else { return }

        showsLifetimeRetentionOffer = false
        showsSpinWinbackFromMarketing = true
    }

    private var shouldPresentRetention: Bool {
        guard AppSession.shared.hasCompletedOnboarding else { return false }
        guard SubscriptionConfiguration.retentionQuickActionLifetimeOfferEnabled else { return false }
        guard !SubscriptionService.shared.subscriptionStatus.isActive else { return false }
        return true
    }
}
