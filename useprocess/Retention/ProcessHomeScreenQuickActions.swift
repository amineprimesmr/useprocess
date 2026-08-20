import UIKit

/// Quick Actions écran d’accueil — rétention avant suppression de l’app (style QUITTR).
enum ProcessHomeScreenQuickActions {

    @MainActor
    static func syncForCurrentUser() {
        let application = UIApplication.shared

        guard shouldOfferRetentionShortcuts else {
            if application.shortcutItems?.isEmpty == false {
                application.shortcutItems = nil
            }
            return
        }

        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: ProcessHomeScreenQuickActionKind.lifetimeOffer.rawValue,
                localizedTitle: AppCopy.t("Accès à vie offert", en: "Lifetime Access Offer"),
                localizedSubtitle: AppCopy.t(
                    "Offre exclusive — \(SubscriptionService.shared.winbackLifetimeDisplayPrice)",
                    en: "Exclusive offer — \(SubscriptionService.shared.winbackLifetimeDisplayPrice)"
                ),
                icon: UIApplicationShortcutIcon(systemImageName: "gift.fill")
            )
        ]
    }

    @MainActor
    private static var shouldOfferRetentionShortcuts: Bool {
        guard SubscriptionConfiguration.retentionQuickActionLifetimeOfferEnabled else { return false }
        guard !SubscriptionService.shared.subscriptionStatus.isActive else { return false }
        return true
    }
}
