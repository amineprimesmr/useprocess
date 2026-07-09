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

    func resetToday(for date: Date = Date(), dayId: String?) {
        let key = dayKey(for: date)
        logsByDay[key] = ProcessHydrationDayLog()
        persist()
        if let dayId {
            WelcomePlanStore.shared.setJournalTaskStatus(nil, taskId: "\(dayId).core.hydrate", dayId: dayId)
        }
    }

    private func syncJournalTask(dayId: String, totalMilliliters: Int, targetMilliliters: Int) {
        let status: JournalTaskStatus? = totalMilliliters >= targetMilliliters ? .completed : nil
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
