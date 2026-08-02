import Foundation
import UserNotifications

/// Unique owner du rythme quotidien (1 matin + 1 soir). Purge les anciens schedulers.
@MainActor
enum CoachDailyRhythmService {
    private static let outlookID = "process.coach.daily.outlook"
    private static let reviewID = "process.coach.daily.review"

    private static let orphanFixedIDs = [
        "process.originplan.morning",
        "process.facescan.cadence",
        "process.paywall.exit.reminder"
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

    static var eveningReviewEnabled: Bool {
        get { UserDefaults.standard.object(forKey: settingsKey("evening")) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: settingsKey("evening"))
            Task { await rescheduleAll() }
        }
    }

    /// Purge les notifs orphelines puis replanifie matin + soir uniquement.
    static func rescheduleAll() async {
        await purgeOrphanNotifications()
        await reschedule()
    }

    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [outlookID, reviewID])

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

        if eveningReviewEnabled {
            await schedule(
                id: reviewID,
                title: "Bilan du soir",
                body: eveningReviewBody(),
                hour: 21,
                minute: 0,
                kind: "daily_review"
            )
        }
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
        }

        FaceScanReminderService.cancelReminder()
        OriginPlanNotificationService.cancel()
        await CoachCheckInScheduler.cancelAll()
        PaywallTrialNotificationService.shared.clearExitNotification()
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
        content.subtitle = "Process"
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
        if sleep >= 7.5 { return "Bonne nuit — prêt à avancer" }
        if sleep >= 6 { return "Journée modérée" }
        return "Priorité récup aujourd'hui"
    }

    private static func dailyOutlookBody() -> String {
        var parts: [String] = []

        if let plan = WelcomePlanStore.shared.plan {
            let dayIndex = plan.calendar.currentProgramDayIndex()
            parts.append("Jour \(dayIndex + 1)")
            if let day = plan.calendar.day(globalIndex: dayIndex) {
                if let training = day.training {
                    parts.append(training.sessionName)
                } else {
                    parts.append("Récup active")
                }
            }
        }

        let sleep = HealthManager.shared.todaySnapshot.sleep.sleepDuration
        if sleep > 0 {
            parts.append(String(format: "Sommeil %.1fh", sleep))
        }

        if FaceScanCadence.isScanDue(since: FaceScanHistoryStore.shared.latestResult?.createdAt) {
            parts.append("Scan visage à faire")
        }

        if parts.isEmpty {
            return "Ouvre Process pour ton plan du jour."
        }
        return parts.joined(separator: " · ")
    }

    private static func eveningReviewBody() -> String {
        let validatedDays = ProcessStreakStore.shared.snapshot.totalCompletedDays
        if validatedDays > 0 {
            return "\(validatedDays) jour\(validatedDays > 1 ? "s" : "") validé\(validatedDays > 1 ? "s" : ""). Valide ton bilan sur l'accueil avant de dormir."
        }
        return "Deux minutes sur l'accueil pour valider ta journée."
    }

    private static func settingsKey(_ suffix: String) -> String {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        return UserScopedStorage.key("coach.daily_rhythm.\(suffix)", userId: uid)
    }
}
