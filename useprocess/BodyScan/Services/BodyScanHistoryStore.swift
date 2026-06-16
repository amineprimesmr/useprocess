import Foundation

@MainActor
@Observable
final class BodyScanHistoryStore {
    static let shared = BodyScanHistoryStore()

    private(set) var latestResult: BodyScanResult?
    private(set) var history: [BodyScanResult] = []

    private var userId: String?

    private var latestKey: String {
        UserScopedStorage.key("bodyscan.latest", userId: userId)
    }

    private var historyKey: String {
        UserScopedStorage.key("bodyscan.history", userId: userId)
    }

    private init() {
        reloadForUser(userId: UserScopedStorage.currentUserId())
    }

    func reloadForUser(userId: String?) {
        self.userId = userId
        loadFromDisk()
    }

    func push(_ result: BodyScanResult) {
        latestResult = result
        history.removeAll { $0.id == result.id }
        history.insert(result, at: 0)
        if history.count > 50 { history = Array(history.prefix(50)) }
        persist()
    }

    func replace(with results: [BodyScanResult]) {
        history = results
        latestResult = results.first
        persist()
    }

    private func persist() {
        if let latest = latestResult, let data = try? JSONEncoder().encode(latest) {
            UserDefaults.standard.set(data, forKey: latestKey)
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let items = try? JSONDecoder().decode([BodyScanResult].self, from: data) {
            history = items
            latestResult = items.first
            return
        }
        if let data = UserDefaults.standard.data(forKey: latestKey),
           let result = try? JSONDecoder().decode(BodyScanResult.self, from: data) {
            latestResult = result
            history = [result]
            return
        }
        latestResult = nil
        history = []
    }

    func clearForUser(userId: String?) {
        if let userId {
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("bodyscan.latest", userId: userId))
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("bodyscan.history", userId: userId))
        }
        self.userId = userId
        latestResult = nil
        history = []
    }
}
