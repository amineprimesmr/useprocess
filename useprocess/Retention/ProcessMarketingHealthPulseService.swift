import Foundation
import UserNotifications

/// Notifs HealthKit pour non-payeurs : prouve que Process travaille (pas, sommeil, activité).
@MainActor
final class ProcessMarketingHealthPulseService {
    static let shared = ProcessMarketingHealthPulseService()

    private static let lastPulseDayKey = "process.mkt.health.lastPulseDay"
    private static let lastPulseKindKey = "process.mkt.health.lastPulseKind"
    private static let quietHourStart = 22
    private static let quietHourEnd = 8

    /// Seuil pas pour un « milestone » engageant.
    private static let stepsMilestone = 5_000
    private static let lowMovementCeiling = 2_200
    private static let sleepMinimumHours = 3.5
    private static let exerciseMinimumMinutes = 12
    private static let caloriesMinimum = 280
    /// Bilan soir seulement après cet horaire (métriques plus fraîches).
    private static let eveningEarliestHour = 16

    private init() {}

    // MARK: - Public

    /// Évalue le snapshot HealthKit et planifie au plus 1 pulse / jour civil.
    func evaluateAfterHealthSync(reason: String) async {
        guard !SubscriptionService.shared.subscriptionStatus.isActive else {
            cancelAll()
            return
        }

        let health = HealthManager.shared
        guard health.isHealthDataAvailable else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        if hasPulseForToday() { return }

        let metrics = ProcessMarketingHealthPulseMetrics.from(health.todaySnapshot)
        guard hasMeaningfulData(metrics) else { return }

        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)

        if let signal = pickImmediateSignal(metrics: metrics, hour: hour) {
            let fireDate = respectQuietHours(now.addingTimeInterval(75))
            await schedule(kind: signal, metrics: metrics, fireDate: fireDate, reason: reason)
            return
        }

        // Pas de signal fort → bilan soir (après 16h pour des chiffres à jour).
        guard hour >= Self.eveningEarliestHour else { return }
        if metrics.steps > 0 || metrics.sleepHours >= Self.sleepMinimumHours || metrics.activeCalories >= 100 {
            await scheduleEveningRecapIfNeeded(metrics: metrics, now: now, reason: reason)
        }
    }

    func cancelAll() {
        let ids = ProcessMarketingHealthPulseKind.allCases.map(\.notificationIdentifier)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        UserDefaults.standard.removeObject(forKey: Self.lastPulseDayKey)
        UserDefaults.standard.removeObject(forKey: Self.lastPulseKindKey)
    }

    // MARK: - Selection

    private func hasMeaningfulData(_ metrics: ProcessMarketingHealthPulseMetrics) -> Bool {
        metrics.steps > 0
            || metrics.sleepHours >= Self.sleepMinimumHours
            || metrics.exerciseMinutes >= Self.exerciseMinimumMinutes
            || metrics.workoutCount > 0
            || metrics.activeCalories >= Self.caloriesMinimum
            || metrics.hrv > 0
    }

    private func pickImmediateSignal(
        metrics: ProcessMarketingHealthPulseMetrics,
        hour: Int
    ) -> ProcessMarketingHealthPulseKind? {
        var candidates: [ProcessMarketingHealthPulseKind] = []

        if metrics.workoutCount > 0 || metrics.exerciseMinutes >= Self.exerciseMinimumMinutes {
            candidates.append(.activityDetected)
        }
        if metrics.steps >= Self.stepsMilestone {
            candidates.append(.stepsMilestone)
        }
        if hour < 12, metrics.sleepHours >= Self.sleepMinimumHours {
            candidates.append(.sleepDetected)
        }
        if metrics.activeCalories >= Self.caloriesMinimum {
            candidates.append(.caloriesBurned)
        }
        if hour < 13, metrics.hrv > 0 {
            candidates.append(.hrvSignal)
        }
        // Après 14h, peu de pas → nudge doux (montre que l’app surveille).
        if hour >= 14, hour < 21, metrics.steps > 0, metrics.steps < Self.lowMovementCeiling {
            candidates.append(.lowMovement)
        }

        return candidates.max(by: { $0.priority < $1.priority })
    }

    private func scheduleEveningRecapIfNeeded(
        metrics: ProcessMarketingHealthPulseMetrics,
        now: Date,
        reason: String
    ) async {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 19
        components.minute = 30
        guard var fire = calendar.date(from: components) else { return }

        if fire <= now.addingTimeInterval(90) {
            // Trop tard pour 19h30 → tire vers 20h45 max, sinon skip.
            guard let late = calendar.date(bySettingHour: 20, minute: 45, second: 0, of: now),
                  late > now.addingTimeInterval(90) else {
                return
            }
            fire = late
        }

        fire = respectQuietHours(fire)
        await schedule(kind: .eveningRecap, metrics: metrics, fireDate: fire, reason: reason)
    }

    // MARK: - Schedule

    private func schedule(
        kind: ProcessMarketingHealthPulseKind,
        metrics: ProcessMarketingHealthPulseMetrics,
        fireDate: Date,
        reason: String
    ) async {
        guard fireDate > Date().addingTimeInterval(30) else { return }

        // Remplace tout pending health pulse (1 seule en vol).
        cancelAll()

        let content = UNMutableNotificationContent()
        content.title = kind.title(metrics: metrics)
        content.body = kind.body(metrics: metrics)
        content.sound = .default
        content.threadIdentifier = "process.marketing.health"
        content.userInfo = [
            "kind": kind.userInfoKind,
            "campaign_id": kind.rawValue,
            "opens_lifetime_offer": kind.opensLifetimeOffer,
            "health_pulse": true,
            "steps": metrics.steps,
            "sleep_hours": metrics.sleepHours
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: kind.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            markPulseScheduled(kind: kind)
            ProcessAnalytics.trackMarketingNotificationsScheduled(
                reason: "health_pulse_\(reason)",
                campaignIds: [kind.rawValue],
                sawSpin: ProcessMarketingNotificationService.shared.hasSawSpinWheel
            )
        } catch {
            // ignore
        }
    }

    // MARK: - Caps / quiet hours

    private func hasPulseForToday() -> Bool {
        let day = dayKey(Date())
        if UserDefaults.standard.string(forKey: Self.lastPulseDayKey) == day {
            return true
        }
        return false
    }

    private func markPulseScheduled(kind: ProcessMarketingHealthPulseKind) {
        UserDefaults.standard.set(dayKey(Date()), forKey: Self.lastPulseDayKey)
        UserDefaults.standard.set(kind.rawValue, forKey: Self.lastPulseKindKey)
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }

    private func respectQuietHours(_ date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        if hour >= Self.quietHourStart {
            guard let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else {
                return date
            }
            return calendar.date(bySettingHour: 9, minute: 15, second: 0, of: next) ?? date
        }
        if hour < Self.quietHourEnd {
            return calendar.date(bySettingHour: 9, minute: 15, second: 0, of: date) ?? date
        }
        return date
    }
}
