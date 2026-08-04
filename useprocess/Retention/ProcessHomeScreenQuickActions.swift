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

        let trialDays = SubscriptionConfiguration.retentionQuickActionTrialDays
        let trialTitle = trialDays > 0 ? "🎁 \(trialDays) JOURS OFFERTS" : "🎁 ESSAI GRATUIT"

        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: ProcessHomeScreenQuickActionKind.trialOffer.rawValue,
                localizedTitle: trialTitle,
                localizedSubtitle: "Accès illimité à Process",
                icon: UIApplicationShortcutIcon(systemImageName: "gift.fill")
            )
        ]
    }

    @MainActor
    private static var shouldOfferRetentionShortcuts: Bool {
        guard SubscriptionConfiguration.retentionQuickActionTrialDays > 0 else { return false }
        guard !SubscriptionService.shared.subscriptionStatus.isActive else { return false }
        return true
    }
}
