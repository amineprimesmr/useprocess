import Foundation

@MainActor
@Observable
final class BodyScanHistoryStore {
    static let shared = BodyScanHistoryStore()

    private(set) var latestResult: BodyScanResult?
    private(set) var history: [BodyScanResult] = []

    private let latestKey = (AppConfiguration.bundleIdentifier) + ".bodyscan.latest"

    private init() {
        loadCachedLatest()
    }

    func push(_ result: BodyScanResult) {
        latestResult = result
        history.removeAll { $0.id == result.id }
        history.insert(result, at: 0)
        if history.count > 20 { history = Array(history.prefix(20)) }
        persistLatest(result)
    }

    func replace(with results: [BodyScanResult]) {
        history = results
        latestResult = results.first
        if let latest = results.first { persistLatest(latest) }
    }

    private func persistLatest(_ result: BodyScanResult) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        UserDefaults.standard.set(data, forKey: latestKey)
    }

    private func loadCachedLatest() {
        guard let data = UserDefaults.standard.data(forKey: latestKey),
              let result = try? JSONDecoder().decode(BodyScanResult.self, from: data) else { return }
        latestResult = result
        history = [result]
    }
}
