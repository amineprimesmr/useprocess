import Foundation
import UserNotifications

/// Notifications locales liées à l'essai gratuit (rappel fin d'essai uniquement).
@MainActor
final class PaywallTrialNotificationService {
    static let shared = PaywallTrialNotificationService()

    private let trialEndIdentifier = "process.trial.end.reminder"
    private let paywallExitIdentifier = "process.paywall.exit.reminder"

    private init() {}

    func scheduleTrialEndingReminder(trialEndDate: Date) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        center.removePendingNotificationRequests(withIdentifiers: [trialEndIdentifier])

        let reminderDate = Calendar.current.date(byAdding: .hour, value: -24, to: trialEndDate)
            ?? Calendar.current.date(byAdding: .day, value: -1, to: trialEndDate)
            ?? trialEndDate

        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ton essai se termine bientôt"
        content.body = "Il te reste 24 h d'essai gratuit. Annule à tout moment si tu ne souhaites pas continuer."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: trialEndIdentifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    func scheduleTrialEndingReminder(days: Int) async {
        guard days > 0 else { return }
        let end = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        await scheduleTrialEndingReminder(trialEndDate: end)
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
