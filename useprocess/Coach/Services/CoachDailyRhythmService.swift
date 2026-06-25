import Foundation
import UserNotifications

@MainActor
enum CoachDailyRhythmService {
    private static let outlookID = "process.coach.daily.outlook"
    private static let reviewID = "process.coach.daily.review"

    static var morningOutlookEnabled: Bool {
        get { UserDefaults.standard.object(forKey: settingsKey("morning")) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: settingsKey("morning"))
            Task { await reschedule() }
        }
    }

    static var eveningReviewEnabled: Bool {
        get { UserDefaults.standard.object(forKey: settingsKey("evening")) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: settingsKey("evening"))
            Task { await reschedule() }
        }
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
                minute: 15
            )
        }

        if eveningReviewEnabled {
            await schedule(
                id: reviewID,
                title: "Bilan du jour",
                body: eveningReviewBody(),
                hour: 21,
                minute: 0
            )
        }
    }

    static func sendMorningOutlookNowIfNeeded() async {
        guard morningOutlookEnabled, CoachIntelligenceSettingsStore.shared.isEnabled else { return }
        guard !CoachPresentationTracker.shared.applicationIsActive else { return }

        await CoachIntelligenceNotificationService.notifyCustom(
            title: dailyOutlookTitle(),
            body: dailyOutlookBody(),
            kind: "daily_outlook"
        )
    }

    private static func schedule(id: String, title: String, body: String, hour: Int, minute: Int) async {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.subtitle = "Process Intelligence"
        content.threadIdentifier = CoachIntelligenceNotificationService.threadID
        content.sound = .default
        content.userInfo = ["kind": id.contains("outlook") ? "daily_outlook" : "daily_review"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func dailyOutlookTitle() -> String {
        let readiness = HealthManager.shared.readinessScore
        if readiness >= 67 { return "Bonne récup — prêt à avancer" }
        if readiness >= 34 { return "Journée modérée" }
        return "Priorité récup aujourd'hui"
    }

    private static func dailyOutlookBody() -> String {
        var parts: [String] = []
        if let plan = WelcomePlanStore.shared.plan {
            parts.append(OriginPlanPresenter.todayDayTitle(in: plan) ?? "Ton protocole t'attend")
        }
        let readiness = HealthManager.shared.readinessScore
        if readiness > 0 {
            parts.append("Readiness \(readiness)%")
        }
        parts.append("Ouvre le coach pour ton plan du jour.")
        return parts.joined(separator: " · ")
    }

    private static func eveningReviewBody() -> String {
        let streak = ProcessStreakStore.shared.snapshot.currentStreak
        if streak > 0 {
            return "Streak \(streak) jour\(streak > 1 ? "s" : ""). Vérifie ton journal avant de dormir."
        }
        return "Complète ton journal pour lancer ou garder ta streak."
    }

    private static func settingsKey(_ suffix: String) -> String {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        return UserScopedStorage.key("coach.daily_rhythm.\(suffix)", userId: uid)
    }
}
