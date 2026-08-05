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
        case .goals: return AppCopy.t("Objectifs", en: "Goals")
        case .identity: return AppCopy.t("Identité", en: "Identity")
        case .lifestyle: return AppCopy.t("Style de vie", en: "Lifestyle")
        case .preferences: return AppCopy.t("Préférences coach", en: "Coach preferences")
        case .events: return AppCopy.t("Événements", en: "Events")
        case .healthHistory: return AppCopy.t("Historique santé", en: "Health history")
        case .mood: return AppCopy.t("Humeur", en: "Mood")
        }
    }

    var placeholder: String {
        switch self {
        case .goals: return AppCopy.t("Ex : debloat visage, -5 kg, 3 séances/semaine", en: "e.g., reduce facial puffiness, lose 11 lb, work out 3 times a week")
        case .identity: return AppCopy.t("Ex : travail de bureau, parent, Paris", en: "e.g., office worker, parent, New York")
        case .lifestyle: return AppCopy.t("Ex : coucher 23h, OMAD, marche quotidienne", en: "e.g., bedtime 11 PM, OMAD, daily walks")
        case .preferences: return AppCopy.t("Ex : réponses courtes, pas de moraline", en: "e.g., short answers, no lecturing")
        case .events: return AppCopy.t("Ex : voyage dans 5 jours, compétition dimanche", en: "e.g., trip in 5 days, competition Sunday")
        case .healthHistory: return AppCopy.t("Ex : blessure genou, reflux, GLP-1", en: "e.g., knee injury, reflux, GLP-1")
        case .mood: return AppCopy.t("Ex : stressé cette semaine, motivé", en: "e.g., stressed this week, motivated")
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
