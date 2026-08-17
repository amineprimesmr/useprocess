import Foundation

/// Persisté — timer rappel boire (intervalle + prochaine gorgée).
struct ProcessHydrationTimerState: Codable, Equatable, Sendable {
    var isRunning: Bool
    var intervalMinutes: Int
    var nextSipAt: Date?
    var startedAt: Date?
    var dayId: String?
    var targetMilliliters: Int

    nonisolated static let defaultHydrationTargetML = ProcessDailyTargets.hydrationTargetMilliliters

    static let `default` = ProcessHydrationTimerState(
        isRunning: false,
        intervalMinutes: 45,
        nextSipAt: nil,
        startedAt: nil,
        dayId: nil,
        targetMilliliters: defaultHydrationTargetML
    )
}

enum ProcessHydrationTimerInterval: Int, CaseIterable, Identifiable, Sendable {
    case fifteen = 15
    case thirty = 30
    case fortyFive = 45
    case sixty = 60
    case ninety = 90

    var id: Int { rawValue }

    var title: String {
        AppCopy.t("\(rawValue) min", en: "\(rawValue) min")
    }

    var subtitle: String {
        switch self {
        case .fifteen:
            return AppCopy.t("Très régulier", en: "Very steady")
        case .thirty:
            return AppCopy.t("Rythme soutenu", en: "Steady pace")
        case .fortyFive:
            return AppCopy.t("Équilibré", en: "Balanced")
        case .sixty:
            return AppCopy.t("Léger", en: "Light")
        case .ninety:
            return AppCopy.t("Doux", en: "Gentle")
        }
    }
}

@MainActor
@Observable
final class ProcessHydrationTimerStore {
    static let shared = ProcessHydrationTimerStore()

    private(set) var state: ProcessHydrationTimerState = .default

    private let storageKey = "process.hydration_timer"

    private init() {
        reload()
    }

    var isRunning: Bool { state.isRunning }
    var intervalMinutes: Int { state.intervalMinutes }
    var nextSipAt: Date? { state.nextSipAt }

    var selectedInterval: ProcessHydrationTimerInterval {
        ProcessHydrationTimerInterval(rawValue: state.intervalMinutes) ?? .fortyFive
    }

    func reload() {
        guard let data = UserDefaults.standard.data(forKey: UserScopedStorage.key(storageKey)),
              let decoded = try? JSONDecoder().decode(ProcessHydrationTimerState.self, from: data) else {
            state = .default
            return
        }
        state = decoded
    }

    func clearAllData() {
        state = .default
        persist()
        Task {
            await ProcessHydrationTimerNotificationService.cancelAll()
            await ProcessHydrationTimerLiveActivityController.shared.end()
        }
        ProcessHydrationTimerMonitor.shared.refreshMonitoring()
        ProcessHydrationTimerPresenter.shared.clear()
    }

    func setInterval(_ interval: ProcessHydrationTimerInterval) {
        state.intervalMinutes = interval.rawValue
        persist()
        if state.isRunning {
            Task { await restartCountdown(presentIslandIfDue: false) }
        }
    }

    @discardableResult
    func start(
        interval: ProcessHydrationTimerInterval? = nil,
        dayId: String?,
        targetMilliliters: Int = ProcessHydrationTimerState.defaultHydrationTargetML
    ) async -> Bool {
        if let interval {
            state.intervalMinutes = interval.rawValue
        }
        state.dayId = dayId
        state.targetMilliliters = max(targetMilliliters, 1)
        state.isRunning = true
        state.startedAt = Date()
        state.nextSipAt = Date().addingTimeInterval(TimeInterval(state.intervalMinutes * 60))
        persist()

        await ProcessHydrationTimerNotificationService.cancelAll()
        await ProcessHydrationTimerLiveActivityController.shared.startOrUpdate(from: state)
        ProcessHydrationTimerMonitor.shared.refreshMonitoring()
        ProcessHydrationTimerPresenter.shared.clear()
        return true
    }

    func stop() async {
        state.isRunning = false
        state.nextSipAt = nil
        state.startedAt = nil
        persist()

        await ProcessHydrationTimerNotificationService.cancelAll()
        await ProcessHydrationTimerLiveActivityController.shared.end()
        ProcessHydrationTimerMonitor.shared.refreshMonitoring()
        ProcessHydrationTimerPresenter.shared.clear()
    }

    /// Remet le compte à rebours après une gorgée (ou snooze).
    func restartCountdown(presentIslandIfDue: Bool) async {
        guard state.isRunning else { return }
        state.nextSipAt = Date().addingTimeInterval(TimeInterval(state.intervalMinutes * 60))
        persist()

        await ProcessHydrationTimerLiveActivityController.shared.sync(from: state)
        ProcessHydrationTimerMonitor.shared.refreshMonitoring()
        ProcessHydrationTimerPresenter.shared.clear()
    }

    func markDrinkDue(source: ProcessHydrationTimerDueSource) async {
        guard state.isRunning else { return }

        if let next = state.nextSipAt, next > Date().addingTimeInterval(2) {
            state.nextSipAt = Date()
            persist()
        } else if state.nextSipAt == nil {
            state.nextSipAt = Date()
            persist()
        }

        await syncLiveActivityHydration()
        ProcessHydrationTimerPresenter.shared.clear()
    }

    @discardableResult
    func logSip(
        milliliters: Int,
        healthKitWaterLiters: Double = 0,
        celebrateOnHome: Bool = false
    ) async -> Int {
        let before = ProcessHydrationLogStore.shared.milliliters()
        let target = state.targetMilliliters
        let total = ProcessHydrationLogStore.shared.addWater(
            milliliters: milliliters,
            dayId: state.dayId,
            targetMilliliters: target
        )
        _ = healthKitWaterLiters
        await restartCountdown(presentIslandIfDue: true)

        if celebrateOnHome {
            ProcessHydrationSipCelebrationCoordinator.shared.requestHomeCelebration(fromMilliliters: before)
        }
        return total
    }

    func syncLiveActivityHydration() async {
        guard state.isRunning else { return }
        await ProcessHydrationTimerLiveActivityController.shared.sync(from: state)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: UserScopedStorage.key(storageKey))
    }
}

enum ProcessHydrationTimerDueSource: String, Sendable {
    case timer
    case notification
    case liveActivity
    case manual
}
