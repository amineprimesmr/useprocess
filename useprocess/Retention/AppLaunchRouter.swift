import Foundation

/// Route les lancements via Quick Action vers la rétention essai gratuit.
@MainActor
@Observable
final class AppLaunchRouter {
    static let shared = AppLaunchRouter()

    private(set) var pendingTrialRetentionSource: ProcessHomeScreenQuickActionKind?
    var showsTrialRetentionOffer = false

    private init() {}

    func handleShortcut(type: String) {
        guard let kind = ProcessHomeScreenQuickActionKind(rawValue: type) else { return }

        pendingTrialRetentionSource = kind
        ProcessAnalytics.trackQuickActionOpened(kind: kind.analyticsSource)
        presentTrialRetentionIfEligible()
    }

    func flushPendingPresentation() {
        presentTrialRetentionIfEligible()
    }

    func clearTrialRetentionPresentation() {
        showsTrialRetentionOffer = false
        pendingTrialRetentionSource = nil
        SubscriptionService.shared.setRetentionTrialOfferActive(false)
    }

    var activeTrialRetentionSource: ProcessHomeScreenQuickActionKind {
        pendingTrialRetentionSource ?? .trialOffer
    }

    private func presentTrialRetentionIfEligible() {
        guard pendingTrialRetentionSource != nil else { return }
        guard shouldPresentTrialRetention else { return }
        guard !showsTrialRetentionOffer else { return }

        // Laisse SwiftUI monter AppShellView avant de présenter le fullScreenCover.
        Task { @MainActor in
            await Task.yield()
            guard pendingTrialRetentionSource != nil, shouldPresentTrialRetention else { return }
            SubscriptionService.shared.setRetentionTrialOfferActive(true)
            showsTrialRetentionOffer = true
        }
    }

    private var shouldPresentTrialRetention: Bool {
        guard SubscriptionConfiguration.retentionQuickActionTrialDays > 0 else { return false }
        guard !SubscriptionService.shared.subscriptionStatus.isActive else { return false }
        return true
    }
}
