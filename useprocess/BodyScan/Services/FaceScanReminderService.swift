import Foundation
import UserNotifications

@MainActor
enum FaceScanReminderService {
    static let notificationID = "process.facescan.cadence"

    /// Planifie une notif pour le prochain scan (tous les 3 jours après le dernier).
    static func scheduleNextReminder(after lastScan: Date?, hour: Int = 8, minute: Int = 0) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        let granted = await PermissionsManager.shared.requestNotificationPermission()
        guard granted else { return }

        let calendar = Calendar.current
        let now = Date()
        var fireDate: Date

        if let lastScan {
            fireDate = FaceScanCadence.nextScanDate(after: lastScan, calendar: calendar)
            var morning = calendar.dateComponents([.year, .month, .day], from: fireDate)
            morning.hour = hour
            morning.minute = minute
            fireDate = calendar.date(from: morning) ?? fireDate
            if fireDate <= now {
                fireDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
                var tomorrowMorning = calendar.dateComponents([.year, .month, .day], from: fireDate)
                tomorrowMorning.hour = hour
                tomorrowMorning.minute = minute
                fireDate = calendar.date(from: tomorrowMorning) ?? fireDate
            }
        } else {
            var todayMorning = calendar.dateComponents([.year, .month, .day], from: now)
            todayMorning.hour = hour
            todayMorning.minute = minute
            fireDate = calendar.date(from: todayMorning) ?? now
            if fireDate <= now {
                fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate.addingTimeInterval(86_400)
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "Scan visage — c'est le moment"
        content.body = "30 sec pour suivre gonflement, cernes et récupération (tous les 3 jours)."
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}
