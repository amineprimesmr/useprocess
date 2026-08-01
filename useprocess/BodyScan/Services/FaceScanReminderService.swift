import Foundation
import UserNotifications

/// Ancien rappel scan séparé — le rappel est désormais intégré au brief matin.
@MainActor
enum FaceScanReminderService {
    static let notificationID = "process.facescan.cadence"

    static func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}
