import Foundation
import UserNotifications

@MainActor
enum OriginPlanNotificationService {
    static let notificationID = "process.originplan.morning"

    static func scheduleMorningBrief(plan: FaceOriginPlan) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        let granted = await PermissionsManager.shared.requestNotificationPermission()
        guard granted else { return }

        let dayIndex = plan.calendar.currentProgramDayIndex()
        let dayNumber = dayIndex + 1
        let day = plan.calendar.day(globalIndex: dayIndex)

        var hour = 7
        var minute = 30
        if let wake = day?.sleep.targetWake ?? plan.sleepProtocol.wakeWindow.components(separatedBy: " ").last {
            let parts = wake.replacingOccurrences(of: "(±30 min)", with: "").split(separator: ":")
            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                hour = h
                minute = max(m - 15, 0)
            }
        }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trainingLine = day?.training.map { "Séance : \($0.sessionName)" } ?? "Récup active + marche"
        let nutritionLine = day.map { "PDJ : \($0.nutrition.breakfast)" } ?? plan.nutritionProtocol.mealExamples.first ?? "Repas dense"

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
