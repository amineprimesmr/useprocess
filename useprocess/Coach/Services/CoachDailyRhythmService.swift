import Foundation
import UserNotifications

/// Unique owner du rythme quotidien (brief matin uniquement). Purge les anciens schedulers.
@MainActor
enum CoachDailyRhythmService {
    private static let outlookID = "process.coach.daily.outlook"
    private static let reviewID = "process.coach.daily.review"

    private static let orphanFixedIDs = [
        "process.originplan.morning",
        "process.facescan.cadence",
        "process.paywall.exit.reminder",
        reviewID
    ]
    private static let orphanPrefixes = [
        "process.coach.checkin."
    ]

    static var morningOutlookEnabled: Bool {
        get { UserDefaults.standard.object(forKey: settingsKey("morning")) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: settingsKey("morning"))
            Task { await rescheduleAll() }
        }
    }

    /// Purge les notifs orphelines (dont « Check du jour ») puis replanifie le brief matin.
    static func rescheduleAll() async {
        await purgeOrphanNotifications()
        await reschedule()
    }

    static func reschedule() async {
        cancelEveningCheckNotification()
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [outlookID])

        guard CoachIntelligenceSettingsStore.shared.isEnabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        if morningOutlookEnabled {
            await schedule(
                id: outlookID,
                title: dailyOutlookTitle(),
                body: dailyOutlookBody(),
                hour: 7,
                minute: 30,
                kind: "daily_outlook"
            )
        }
    }

    /// Annule toute notif « Check du jour » encore en file ou déjà livrée.
    static func cancelEveningCheckNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reviewID])
        center.removeDeliveredNotifications(withIdentifiers: [reviewID])
    }

    // MARK: - Purge

    private static func purgeOrphanNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: orphanFixedIDs)

        let pending = await center.pendingNotificationRequests()
        let orphanIDs = pending.map(\.identifier).filter { id in
            orphanPrefixes.contains { id.hasPrefix($0) }
        }
        if !orphanIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: orphanIDs)
            center.removeDeliveredNotifications(withIdentifiers: orphanIDs)
        }
        center.removeDeliveredNotifications(withIdentifiers: orphanFixedIDs)

        FaceScanReminderService.cancelReminder()
        OriginPlanNotificationService.cancel()
        await CoachCheckInScheduler.cancelAll()
    }

    // MARK: - Schedule

    private static func schedule(
        id: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        kind: String
    ) async {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.threadIdentifier = CoachIntelligenceNotificationService.threadID
        content.sound = .default
        content.userInfo = ["kind": kind]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Copy

    private static func dailyOutlookTitle() -> String {
        if let plan = WelcomePlanStore.shared.plan,
           let dayTitle = OriginPlanPresenter.todayDayTitle(in: plan) {
            return dayTitle
        }
        let sleep = HealthManager.shared.todaySnapshot.sleep.sleepDuration
        if sleep >= 7.5 { return AppCopy.t("Bonne nuit — prêt à avancer", en: "Great sleep — ready to go") }
        if sleep >= 6 { return AppCopy.t("Journée modérée", en: "Take it moderately today") }
        return AppCopy.t("Priorité récup aujourd'hui", en: "Prioritize recovery today")
    }

    private static func dailyOutlookBody() -> String {
        var parts: [String] = []

        if let plan = WelcomePlanStore.shared.plan {
            let dayIndex = plan.calendar.currentProgramDayIndex()
            parts.append(AppCopy.t("Jour \(dayIndex + 1)", en: "Day \(dayIndex + 1)"))
            if plan.calendar.day(globalIndex: dayIndex) != nil {
                let cardio = DebloatCardioDayCatalog.session()
                parts.append(cardio.prescriptionLine)
            }
        }

        let sleep = HealthManager.shared.todaySnapshot.sleep.sleepDuration
        if sleep > 0 {
            parts.append(AppCopy.t(String(format: "Sommeil %.1fh", sleep), en: String(format: "Sleep %.1f hr", sleep)))
        }

        if FaceScanCadence.isScanDue(since: FaceScanHistoryStore.shared.latestResult?.createdAt) {
            parts.append(AppCopy.t("Scan visage à faire", en: "Face scan due"))
        }

        if parts.isEmpty {
            return AppCopy.t("Ouvre l’app pour ton plan du jour.", en: "Open the app for today's plan.")
        }
        return parts.joined(separator: " · ")
    }

    private static func settingsKey(_ suffix: String) -> String {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        return UserScopedStorage.key("coach.daily_rhythm.\(suffix)", userId: uid)
    }
}
