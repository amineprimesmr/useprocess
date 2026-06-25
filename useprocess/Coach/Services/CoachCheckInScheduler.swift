import Foundation
import UserNotifications

@MainActor
enum CoachCheckInScheduler {
    private static let prefix = "process.coach.checkin."

    static func rescheduleAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        guard CoachCheckInStore.shared.proactiveCheckInsEnabled,
              CoachIntelligenceSettingsStore.shared.isEnabled else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        for checkIn in CoachCheckInStore.shared.checkIns where checkIn.isEnabled {
            for weekday in checkIn.weekdays {
                var components = DateComponents()
                components.weekday = weekday
                components.hour = checkIn.hour
                components.minute = checkIn.minute

                let content = UNMutableNotificationContent()
                content.title = checkIn.title
                content.body = "Process Intelligence — ouvre le coach pour ton check-in."
                content.subtitle = "Process Intelligence"
                content.threadIdentifier = CoachIntelligenceNotificationService.threadID
                content.categoryIdentifier = CoachIntelligenceNotificationService.categoryID
                content.sound = .default
                content.userInfo = [
                    "kind": "coach_checkin",
                    "checkInId": checkIn.id,
                    "prompt": checkIn.prompt
                ]

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let id = "\(prefix)\(checkIn.id).\(weekday)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }
}
