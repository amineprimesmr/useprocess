import Foundation

struct DebloatFoodPreferenceState: Codable, Equatable {
    var likedIDs: Set<String> = []
    var dislikedIDs: Set<String> = []
    var haveAtHomeIDs: Set<String> = []
}

@MainActor
@Observable
final class DebloatFoodPreferenceStore {
    static let shared = DebloatFoodPreferenceStore()

    private(set) var state = DebloatFoodPreferenceState()
    private var persistenceGeneration: UInt64 = 0

    private init() {
        reload()
    }

    func reload() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.debloat.food_prefs", userId: uid)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(DebloatFoodPreferenceState.self, from: data) {
            state = decoded
        } else {
            state = DebloatFoodPreferenceState()
        }
    }

    var likedFoods: [DebloatFoodItem] {
        state.likedIDs.compactMap { DebloatFoodCatalog.item(id: $0) }
            .sorted { $0.debloatScore > $1.debloatScore }
    }

    var dislikedFoods: [DebloatFoodItem] {
        state.dislikedIDs.compactMap { DebloatFoodCatalog.item(id: $0) }
    }

    var haveAtHomeFoods: [DebloatFoodItem] {
        state.haveAtHomeIDs.compactMap { DebloatFoodCatalog.item(id: $0) }
    }

    func isLiked(_ id: String) -> Bool { state.likedIDs.contains(id) }
    func isDisliked(_ id: String) -> Bool { state.dislikedIDs.contains(id) }
    func hasAtHome(_ id: String) -> Bool { state.haveAtHomeIDs.contains(id) }

    func toggleLike(_ id: String) {
        if state.likedIDs.contains(id) {
            state.likedIDs.remove(id)
        } else {
            state.likedIDs.insert(id)
            state.dislikedIDs.remove(id)
        }
        persist()
    }

    func toggleDislike(_ id: String) {
        if state.dislikedIDs.contains(id) {
            state.dislikedIDs.remove(id)
        } else {
            state.dislikedIDs.insert(id)
            state.likedIDs.remove(id)
        }
        persist()
    }

    func toggleHaveAtHome(_ id: String) {
        if state.haveAtHomeIDs.contains(id) {
            state.haveAtHomeIDs.remove(id)
        } else {
            state.haveAtHomeIDs.insert(id)
        }
        persist()
    }

    private func persist() {
        persistenceGeneration &+= 1
        let generation = persistenceGeneration
        let snapshot = state
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.debloat.food_prefs", userId: uid)
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            await MainActor.run {
                guard generation == self.persistenceGeneration else { return }
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}
