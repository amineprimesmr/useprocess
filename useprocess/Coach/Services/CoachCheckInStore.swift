import Foundation

struct CoachCheckIn: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var prompt: String
    var hour: Int
    var minute: Int
    var weekdays: Set<Int> // 1=Sun ... 7=Sat Calendar
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        prompt: String,
        hour: Int,
        minute: Int,
        weekdays: Set<Int> = [2, 3, 4, 5, 6, 7, 1],
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}

enum CoachCheckInTemplate: String, CaseIterable, Identifiable {
    case morningOutlook
    case journalReminder
    case scanReminder
    case streakGuard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningOutlook: return "Brief matin"
        case .journalReminder: return "Rappel journal"
        case .scanReminder: return "Rappel scan visage"
        case .streakGuard: return "Jours validés en jeu"
        }
    }

    var defaultPrompt: String {
        switch self {
        case .morningOutlook:
            return "Crée un check-in matin avec mon readiness, mon jour du plan personnalisé et 1 action prioritaire."
        case .journalReminder:
            return "Rappelle-moi de compléter mon journal du jour si des tâches restent ouvertes."
        case .scanReminder:
            return "Rappelle-moi de faire mon scan visage si je ne l'ai pas fait aujourd'hui."
        case .streakGuard:
            return "Préviens-moi en fin de journée si mes jours validés sont en danger."
        }
    }
}

@MainActor
@Observable
final class CoachCheckInStore {
    static let shared = CoachCheckInStore()

    private(set) var checkIns: [CoachCheckIn] = []
    /// Feature retirée du produit — toujours off, pending purgées.
    var proactiveCheckInsEnabled: Bool {
        didSet { persistSettings() }
    }

    private init() {
        proactiveCheckInsEnabled = false
        reload()
    }

    func reload() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let prefix = UserScopedStorage.key("coach.checkins", userId: uid)

        // Migration : désactive et vide les check-ins programmés (spam).
        proactiveCheckInsEnabled = false
        UserDefaults.standard.set(false, forKey: "\(prefix).enabled")
        checkIns = []
        UserDefaults.standard.removeObject(forKey: prefix)

        Task { await CoachCheckInScheduler.cancelAll() }
    }

    func add(from template: CoachCheckInTemplate, hour: Int, minute: Int) {
        // No-op — check-ins programmés retirés.
        _ = (template, hour, minute)
    }

    func delete(id: String) {
        checkIns.removeAll { $0.id == id }
        persist()
        Task { await CoachCheckInScheduler.cancelAll() }
    }

    func toggle(id: String, enabled: Bool) {
        guard let index = checkIns.firstIndex(where: { $0.id == id }) else { return }
        checkIns[index].isEnabled = enabled
        persist()
        Task { await CoachCheckInScheduler.cancelAll() }
    }

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("coach.checkins", userId: uid)
        if let data = try? JSONEncoder().encode(checkIns) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func persistSettings() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("coach.checkins", userId: uid)
        UserDefaults.standard.set(false, forKey: "\(key).enabled")
    }
}
