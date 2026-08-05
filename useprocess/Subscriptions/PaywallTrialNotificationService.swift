import Foundation
import UserNotifications

/// Ancien service de rappel fin d’essai — no-op (essais gratuits désactivés).
@MainActor
final class PaywallTrialNotificationService {
    static let shared = PaywallTrialNotificationService()

    private let trialEndIdentifier = "process.trial.end.reminder"
    private let paywallExitIdentifier = "process.paywall.exit.reminder"

    private init() {}

    func scheduleTrialEndingReminder(trialEndDate: Date) async {
        // Essais gratuits désactivés — ne jamais planifier de rappel d’essai.
        _ = trialEndDate
        clearTrialNotifications()
    }

    func scheduleTrialEndingReminder(days: Int) async {
        _ = days
        clearTrialNotifications()
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
