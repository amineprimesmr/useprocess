import Foundation
import UserNotifications

/// Compat essais gratuits (désactivés) — la conversion non-payeurs est dans `ProcessMarketingNotificationService`.
@MainActor
final class PaywallTrialNotificationService {
    static let shared = PaywallTrialNotificationService()

    private let trialEndIdentifier = "process.trial.end.reminder"
    private let paywallExitIdentifier = "process.paywall.exit.reminder"

    private init() {}

    func scheduleTrialEndingReminder(trialEndDate: Date) async {
        _ = trialEndDate
        clearTrialNotifications()
    }

    func scheduleTrialEndingReminder(days: Int) async {
        _ = days
        clearTrialNotifications()
        // Permission notif accordée en onboarding — amorce la série marketing si déjà non-payer.
        if !SubscriptionService.shared.subscriptionStatus.isActive {
            await ProcessMarketingNotificationService.shared.scheduleConversionSeries(
                reason: "notification_permission_granted"
            )
        }
    }

    func clearExitNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [paywallExitIdentifier]
        )
    }

    func clearTrialNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [trialEndIdentifier, paywallExitIdentifier]
        )
    }
}
