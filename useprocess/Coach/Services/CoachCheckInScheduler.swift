import Foundation
import UserNotifications

/// Ancien scheduler de check-ins — conservé uniquement pour purger les pending orphelines.
@MainActor
enum CoachCheckInScheduler {
    private static let prefix = "process.coach.checkin."

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Compat : ne replanifie plus rien, purge seulement.
    static func rescheduleAll() async {
        await cancelAll()
    }
}
