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
            await refreshEveningNotification()
        }
    }

    /// Replanifie la notif du soir — skip si le bilan du jour est déjà validé.
    static func refreshEveningNotification() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reviewID])

        guard CoachIntelligenceSettingsStore.shared.isEnabled else { return }
        guard eveningReviewEnabled else { return }
        guard !ProcessEveningCheckInStore.shared.hasSubmittedToday else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let calendar = Calendar.current
        let now = Date()
        var components = DateComponents()
        components.hour = ProcessEveningCheckInSchedule.reminderHour
        components.minute = 0

        guard var fireDate = calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime
        ) else { return }

        if calendar.isDateInToday(fireDate),
           calendar.component(.hour, from: now) >= ProcessEveningCheckInSchedule.reminderHour {
            fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }

        let triggerComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )

        let content = UNMutableNotificationContent()
        content.title = AppCopy.t("Check du jour", en: "Daily check-in")
        content.body = eveningReviewBody()
        content.threadIdentifier = CoachIntelligenceNotificationService.threadID
        content.sound = .default
        content.userInfo = ["kind": "daily_review"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: reviewID, content: content, trigger: trigger)
        try? await center.add(request)
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

    private static func eveningReviewBody() -> String {
        let streak = ProcessStreakStore.shared.displayStreak
        if streak > 0 {
            return AppCopy.t(
                "Série \(streak) jour\(streak > 1 ? "s" : "") — deux minutes pour valider ta journée.",
                en: "\(streak)-day streak — take two minutes to complete your day."
            )
        }
        return AppCopy.t("Deux minutes sur l'accueil pour valider ta journée.", en: "Take two minutes on Home to complete your day.")
    }

    private static func settingsKey(_ suffix: String) -> String {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        return UserScopedStorage.key("coach.daily_rhythm.\(suffix)", userId: uid)
    }
}
