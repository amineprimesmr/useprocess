import Foundation
import UserNotifications

@MainActor
enum FaceScanReminderService {
    static let notificationID = "process.facescan.morning"

    static func scheduleMorningReminder(hour: Int = 8, minute: Int = 0) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        let granted = await PermissionsManager.shared.requestNotificationPermission()
        guard granted else { return }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Scan ton visage"
        content.body = "30 sec pour suivre gonflement, cernes et récupération."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}
