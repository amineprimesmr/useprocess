import Foundation

enum CoachMyMemoryCategory: String, CaseIterable, Identifiable, Codable {
    case goals
    case identity
    case lifestyle
    case preferences
    case events
    case healthHistory
    case mood

    var id: String { rawValue }

    var label: String {
        switch self {
        case .goals: return "Objectifs"
        case .identity: return "Identité"
        case .lifestyle: return "Style de vie"
        case .preferences: return "Préférences coach"
        case .events: return "Événements"
        case .healthHistory: return "Historique santé"
        case .mood: return "Humeur"
        }
    }

    var placeholder: String {
        switch self {
        case .goals: return "Ex : debloat visage, -5 kg, 3 séances/semaine"
        case .identity: return "Ex : travail de bureau, parent, Paris"
        case .lifestyle: return "Ex : coucher 23h, OMAD, marche quotidienne"
        case .preferences: return "Ex : réponses courtes, pas de moraline"
        case .events: return "Ex : voyage dans 5 jours, compétition dimanche"
        case .healthHistory: return "Ex : blessure genou, reflux, GLP-1"
        case .mood: return "Ex : stressé cette semaine, motivé"
        }
    }
}

struct CoachMyMemoryEntry: Codable, Identifiable, Equatable {
    let id: String
    var category: CoachMyMemoryCategory
    var text: String
    var updatedAt: Date

    init(id: String = UUID().uuidString, category: CoachMyMemoryCategory, text: String, updatedAt: Date = .now) {
        self.id = id
        self.category = category
        self.text = text
        self.updatedAt = updatedAt
    }
}

@MainActor
@Observable
final class CoachMyMemoryStore {
    static let shared = CoachMyMemoryStore()

    private(set) var entries: [CoachMyMemoryEntry] = []
    var isMemoryEnabled: Bool {
        didSet { persist() }
    }

    private init() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("coach.my_memory", userId: uid)
        isMemoryEnabled = UserDefaults.standard.object(forKey: "\(key).enabled") as? Bool ?? true
        reload()
    }

    func reload() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("coach.my_memory", userId: uid)
        isMemoryEnabled = UserDefaults.standard.object(forKey: "\(key).enabled") as? Bool ?? true
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CoachMyMemoryEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }

    func add(category: CoachMyMemoryCategory, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if entries.contains(where: {
            $0.category == category && $0.text.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return
        }
        entries.insert(CoachMyMemoryEntry(category: category, text: trimmed), at: 0)
        persist()
    }

    func update(_ entry: CoachMyMemoryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        persist()
    }

    func delete(id: String) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func deleteAll() {
        entries = []
        persist()
    }

    func promptBlock() -> String {
        guard isMemoryEnabled, !entries.isEmpty else { return "" }
        let lines = entries.prefix(20).map { "• [\($0.category.label)] \($0.text)" }
        return "\nMA MÉMOIRE (contexte perso — respecte et mets à jour mentalement) :\n" + lines.joined(separator: "\n")
    }

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("coach.my_memory", userId: uid)
        UserDefaults.standard.set(isMemoryEnabled, forKey: "\(key).enabled")
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
