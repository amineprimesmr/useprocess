import Foundation
import UserNotifications

@MainActor
enum ProcessHydrationTimerNotificationService {
    static let categoryID = "PROCESS_HYDRATION_SIP"
    static let threadID = "process.hydration.timer"
    static let requestPrefix = "process.hydration.sip."

    static let action250 = "HYDRATION_DRINK_250"
    static let action500 = "HYDRATION_DRINK_500"
    static let actionSnooze = "HYDRATION_SNOOZE"

    private static var didConfigureCategory = false

    static func makeCategory() -> UNNotificationCategory {
        let drink250 = UNNotificationAction(
            identifier: action250,
            title: AppCopy.t("+250 ml", en: "+250 ml"),
            options: [.foreground]
        )
        let drink500 = UNNotificationAction(
            identifier: action500,
            title: AppCopy.t("+500 ml", en: "+500 ml"),
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: actionSnooze,
            title: AppCopy.t("Plus tard", en: "Later"),
            options: []
        )
        return UNNotificationCategory(
            identifier: categoryID,
            actions: [drink250, drink500, snooze],
            intentIdentifiers: [],
            options: []
        )
    }

    static func markCategoryConfigured() {
        didConfigureCategory = true
    }

    static func configureCategory() {
        guard !didConfigureCategory else { return }
        didConfigureCategory = true

        Task {
            let center = UNUserNotificationCenter.current()
            let existing = await center.notificationCategories()
            var merged = existing.filter { $0.identifier != categoryID }
            merged.insert(makeCategory())
            center.setNotificationCategories(merged)
        }
    }

    /// Hydratation = Dynamic Island uniquement — pas de demande de permission notif.
    static func requestAuthorizationIfNeeded() async -> Bool {
        true
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(requestPrefix) }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered.map(\.request.identifier).filter { $0.hasPrefix(requestPrefix) }
        if !deliveredIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }
    }

    /// No-op — rappels hydratation via Live Activity / Dynamic Island seulement.
    static func reschedule(from state: ProcessHydrationTimerState) async {
        await cancelAll()
    }

    static func handleAction(identifier: String) async {
        switch identifier {
        case action250:
            _ = await ProcessHydrationTimerStore.shared.logSip(milliliters: 250, celebrateOnHome: true)
        case action500:
            _ = await ProcessHydrationTimerStore.shared.logSip(milliliters: 500, celebrateOnHome: true)
        default:
            await ProcessHydrationTimerStore.shared.syncLiveActivityHydration()
        }
        ProcessHydrationTimerPresenter.shared.clear()
    }
}
