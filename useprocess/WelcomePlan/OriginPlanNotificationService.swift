import Foundation
import UserNotifications

@MainActor
enum OriginPlanNotificationService {
    static let notificationID = "process.originplan.morning"

    static func scheduleMorningBrief(plan: FaceOriginPlan) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let dayIndex = plan.calendar.currentProgramDayIndex()
        let dayNumber = dayIndex + 1
        let day = plan.calendar.day(globalIndex: dayIndex)

        var hour = 7
        var minute = 30
        if let wake = day?.sleep.targetWake ?? plan.sleepProtocol.wakeWindow.components(separatedBy: " ").last {
            let parts = wake
                .replacingOccurrences(of: "(±30 min)", with: "")
                .replacingOccurrences(of: #"\(marge \d+ min\)"#, with: "", options: .regularExpression)
                .split(separator: ":")
            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                hour = h
                minute = max(m - 15, 0)
            }
        }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trainingLine = day?.training.map { "Séance : \($0.sessionName)" } ?? "Récup active + marche"
        let nutritionLine: String = {
            if let day, let meal = plan.progress.validatedMeals[day.id], !meal.isEmpty {
                return "Repas : \(OriginPlanPresenter.truncate(meal, max: 40))"
            }
            return "Nutrition : demande une idée de repas dans l'app"
        }()

        let content = UNMutableNotificationContent()
        content.title = "Protocole Origine — Jour \(dayNumber)"
        content.body = "\(day?.title ?? "Ton programme") · \(trainingLine) · \(nutritionLine)"
        content.sound = .default
        content.userInfo = ["planDay": dayNumber]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}
