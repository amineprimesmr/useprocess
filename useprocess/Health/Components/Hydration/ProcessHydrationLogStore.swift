import Foundation

struct ProcessHydrationEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let milliliters: Int
    let loggedAt: Date

    init(id: UUID = UUID(), milliliters: Int, loggedAt: Date = Date()) {
        self.id = id
        self.milliliters = milliliters
        self.loggedAt = loggedAt
    }
}

struct ProcessHydrationDayLog: Codable, Equatable {
    var milliliters: Int = 0
    var entries: [ProcessHydrationEntry] = []
}

struct ProcessHydrationLogState: Codable, Equatable {
    var logsByDay: [String: ProcessHydrationDayLog] = [:]
}

struct ProcessHydrationEveningPrefill: Equatable, Sendable {
    let milliliters: Int
    let targetMilliliters: Int
    /// `"yes"` / `"no"` pour `EveningCheckInQuestionID.water`.
    let answer: String
    let metTarget: Bool

    var litersLabel: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        let current = formatter.string(from: NSNumber(value: Double(milliliters) / 1000.0)) ?? "0"
        let target = formatter.string(from: NSNumber(value: Double(targetMilliliters) / 1000.0)) ?? "2"
        return "\(current) / \(target) L"
    }

    var statusLine: String {
        if metTarget {
            return "Hydratation \(litersLabel) · objectif atteint"
        }
        return "Hydratation \(litersLabel) · objectif non atteint"
    }
}

/// Journal d'hydratation in-app — source principale du niveau d'eau affiché.
@MainActor
@Observable
final class ProcessHydrationLogStore {
    static let shared = ProcessHydrationLogStore()

    private(set) var logsByDay: [String: ProcessHydrationDayLog] = [:]

    private init() {
        reload()
    }

    func reload() {
        logsByDay = loadState()?.logsByDay ?? [:]
    }

    func milliliters(for date: Date = Date()) -> Int {
        logsByDay[dayKey(for: date)]?.milliliters ?? 0
    }

    func liters(for date: Date = Date()) -> Double {
        Double(milliliters(for: date)) / 1000
    }

    func entries(for date: Date = Date()) -> [ProcessHydrationEntry] {
        logsByDay[dayKey(for: date)]?.entries ?? []
    }

    /// Combine journal in-app et HealthKit (prend le maximum pour éviter la double comptabilisation).
    func effectiveLiters(for date: Date = Date(), healthKitLiters: Double) -> Double {
        max(liters(for: date), healthKitLiters)
    }

    func progress(for date: Date = Date(), targetLiters: Double, healthKitLiters: Double = 0) -> Double {
        guard targetLiters > 0 else { return 0 }
        return min(1, effectiveLiters(for: date, healthKitLiters: healthKitLiters) / targetLiters)
    }

    @discardableResult
    func addWater(
        milliliters amount: Int,
        for date: Date = Date(),
        dayId: String?,
        targetMilliliters: Int
    ) -> Int {
        guard amount > 0 else { return milliliters(for: date) }

        let key = dayKey(for: date)
        var log = logsByDay[key] ?? ProcessHydrationDayLog()
        log.milliliters += amount
        log.entries.insert(ProcessHydrationEntry(milliliters: amount), at: 0)
        logsByDay[key] = log
        persist()

        if let dayId {
            syncJournalTask(dayId: dayId, totalMilliliters: log.milliliters, targetMilliliters: targetMilliliters)
        }
        return log.milliliters
    }

    @discardableResult
    func removeWater(
        milliliters amount: Int,
        for date: Date = Date(),
        dayId: String?,
        targetMilliliters: Int
    ) -> Int {
        guard amount > 0 else { return milliliters(for: date) }

        let key = dayKey(for: date)
        var log = logsByDay[key] ?? ProcessHydrationDayLog()
        guard log.milliliters > 0 else { return 0 }

        let removedAmount = min(amount, log.milliliters)
        log.milliliters -= removedAmount
        log.entries.insert(ProcessHydrationEntry(milliliters: -removedAmount), at: 0)
        logsByDay[key] = log
        persist()

        if let dayId {
            syncJournalTask(dayId: dayId, totalMilliliters: log.milliliters, targetMilliliters: targetMilliliters)
        }
        return log.milliliters
    }

    /// Fixe le total du jour (permet d'ajuster même si HealthKit affiche plus).
    @discardableResult
    func setMilliliters(
        _ milliliters: Int,
        for date: Date = Date(),
        dayId: String?,
        targetMilliliters: Int
    ) -> Int {
        let key = dayKey(for: date)
        let clamped = max(0, milliliters)
        var log = logsByDay[key] ?? ProcessHydrationDayLog()
        let delta = clamped - log.milliliters
        log.milliliters = clamped
        if delta != 0 || log.entries.isEmpty {
            log.entries.insert(ProcessHydrationEntry(milliliters: delta), at: 0)
        }
        logsByDay[key] = log
        persist()

        if let dayId {
            syncJournalTask(dayId: dayId, totalMilliliters: log.milliliters, targetMilliliters: targetMilliliters)
        }
        return log.milliliters
    }

    func hasLocalAdjustments(for date: Date = Date()) -> Bool {
        !(logsByDay[dayKey(for: date)]?.entries.isEmpty ?? true)
    }

    /// Prefill bilan du soir : si l'utilisateur a suivi l'eau dans l'app, on ne repose pas la question.
    func eveningCheckInPrefill(
        for date: Date = Date(),
        targetLiters: Int? = nil
    ) -> ProcessHydrationEveningPrefill? {
        guard hasLocalAdjustments(for: date) else { return nil }

        let targetMilliliters = ProcessDailyTargets.hydrationTargetMilliliters
        let milliliters = max(0, self.milliliters(for: date))
        let metTarget = milliliters >= targetMilliliters

        return ProcessHydrationEveningPrefill(
            milliliters: milliliters,
            targetMilliliters: targetMilliliters,
            answer: metTarget ? "yes" : "no",
            metTarget: metTarget
        )
    }

    func resetToday(for date: Date = Date(), dayId: String?) {
        let key = dayKey(for: date)
        // Garde une entrée locale à 0 pour ne pas remonter au total HealthKit.
        logsByDay[key] = ProcessHydrationDayLog(
            milliliters: 0,
            entries: [ProcessHydrationEntry(milliliters: 0)]
        )
        persist()
        if let dayId {
            WelcomePlanStore.shared.setJournalTaskStatus(nil, taskId: "\(dayId).core.hydrate", dayId: dayId)
        }
    }

    private func syncJournalTask(dayId: String, totalMilliliters: Int, targetMilliliters: Int) {
        let canonical = ProcessDailyTargets.hydrationTargetMilliliters
        let status: JournalTaskStatus? = totalMilliliters >= canonical ? .completed : nil
        WelcomePlanStore.shared.setJournalTaskStatus(
            status,
            taskId: "\(dayId).core.hydrate",
            dayId: dayId
        )
    }

    private func dayKey(for date: Date) -> String {
        ProcessStreakStore.dayKey(for: date)
    }

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.hydration_log", userId: uid)
        let state = ProcessHydrationLogState(logsByDay: logsByDay)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadState() -> ProcessHydrationLogState? {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.hydration_log", userId: uid)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProcessHydrationLogState.self, from: data)
    }
}
