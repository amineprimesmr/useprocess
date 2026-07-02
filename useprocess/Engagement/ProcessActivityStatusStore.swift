import Foundation

@MainActor
@Observable
final class ProcessActivityStatusStore {
    static let shared = ProcessActivityStatusStore()

    private(set) var hasSeenIntro = false
    private var statusByDayKey: [String: String] = [:]

    private init() {
        reload()
    }

    func reload() {
        guard let state = loadState() else {
            hasSeenIntro = false
            statusByDayKey = [:]
            return
        }
        hasSeenIntro = state.hasSeenIntro
        statusByDayKey = state.statusByDayKey
    }

    func status(for date: Date, calendar: Calendar = .current) -> ProcessActivityStatus {
        let key = Self.dayKey(for: date, calendar: calendar)
        guard let raw = statusByDayKey[key], let status = ProcessActivityStatus(rawValue: raw) else {
            return .active
        }
        return status
    }

    func setStatus(_ status: ProcessActivityStatus, for date: Date, calendar: Calendar = .current) {
        statusByDayKey[Self.dayKey(for: date, calendar: calendar)] = status.rawValue
        persist()
    }

    func markIntroSeen() {
        guard !hasSeenIntro else { return }
        hasSeenIntro = true
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        guard let uid = UserScopedStorage.currentUserId() else { return }
        let key = UserScopedStorage.key("process.activity.status", userId: uid)
        let state = ProcessActivityStatusState(hasSeenIntro: hasSeenIntro, statusByDayKey: statusByDayKey)
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func loadState() -> ProcessActivityStatusState? {
        guard let uid = UserScopedStorage.currentUserId() else { return nil }
        let key = UserScopedStorage.key("process.activity.status", userId: uid)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProcessActivityStatusState.self, from: data)
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.startOfDay(for: date)
        let y = calendar.component(.year, from: day)
        let m = calendar.component(.month, from: day)
        let d = calendar.component(.day, from: day)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
