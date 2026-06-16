import Foundation
import UserNotifications

/// Notifications locales liées à l'essai gratuit (fin d'essai + rappel paywall abandonné).
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

    func scheduleExitNotification(hasPurchased: Bool) async {
        guard !hasPurchased else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        center.removePendingNotificationRequests(withIdentifiers: [paywallExitIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "3 jours gratuits t'attendent"
        content.body = "Reviens activer ton essai gratuit sur Process — annulable à tout moment."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: paywallExitIdentifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    func clearTrialNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [trialEndIdentifier, paywallExitIdentifier]
        )
    }
}

/// Alias historique utilisé par le paywall.
typealias PaywallExitNotificationService = PaywallTrialNotificationService
