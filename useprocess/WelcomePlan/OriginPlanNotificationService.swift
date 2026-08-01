import Foundation
import UserNotifications

/// Ancien brief plan du matin — remplacé par `CoachDailyRhythmService`.
@MainActor
enum OriginPlanNotificationService {
    static let notificationID = "process.originplan.morning"

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}
