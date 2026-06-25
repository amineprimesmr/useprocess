import Foundation

struct CoachProcessFile: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var content: String
    var updatedAt: Date

    init(id: String = UUID().uuidString, title: String, content: String, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.content = content
        self.updatedAt = updatedAt
    }
}

@MainActor
@Observable
final class CoachProcessFilesStore {
    static let shared = CoachProcessFilesStore()

    private(set) var files: [CoachProcessFile] = []

    private init() {
        reload()
    }

    func reload() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("coach.process_files", userId: uid)
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CoachProcessFile].self, from: data) else {
            files = []
            seedFromPlanIfNeeded()
            return
        }
        files = decoded
        seedFromPlanIfNeeded()
    }

    func upsert(title: String, content: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else { return }

        if let index = files.firstIndex(where: { $0.title.caseInsensitiveCompare(trimmedTitle) == .orderedSame }) {
            files[index].content = trimmedContent
            files[index].updatedAt = .now
        } else {
            files.insert(CoachProcessFile(title: trimmedTitle, content: trimmedContent), at: 0)
        }
        persist()
    }

    func delete(id: String) {
        files.removeAll { $0.id == id }
        persist()
    }

    func update(id: String, title: String, content: String) {
        guard let index = files.firstIndex(where: { $0.id == id }) else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else { return }
        files[index].title = trimmedTitle
        files[index].content = trimmedContent
        files[index].updatedAt = .now
        persist()
    }

    func deleteAll() {
        files = []
        persist()
    }

    func syncFromExchange(userText: String, assistantText: String, plan: FaceOriginPlan?) {
        if let plan {
            upsert(
                title: "Protocole actif",
                content: "Objectif : \(plan.primaryFaceGoal). Semaine \(plan.calendar.currentWeekNumber())/13. Jour : \(OriginPlanPresenter.todayDayTitle(in: plan) ?? "—")."
            )
        }

        let lower = userText.lowercased()
        if lower.contains("objectif") || lower.contains("but ") {
            upsert(title: "Objectifs debloat", content: String(userText.prefix(280)))
        }
        if lower.contains("bless") || lower.contains("douleur") {
            upsert(title: "Contraintes santé", content: String(userText.prefix(280)))
        }
        if lower.contains("voyage") || lower.contains("week-end") || lower.contains("weekend") {
            upsert(title: "Événements à venir", content: String(userText.prefix(280)))
        }

        if assistantText.count > 40 {
            upsert(title: "Dernière synthèse coach", content: String(assistantText.prefix(400)))
        }
    }

    func promptBlock() -> String {
        guard !files.isEmpty else { return "" }
        let lines = files.prefix(6).map { "• [\($0.title)] \(String($0.content.prefix(180)))" }
        return "\nFICHIERS PROCESS (contexte persistant) :\n" + lines.joined(separator: "\n")
    }

    private func seedFromPlanIfNeeded() {
        guard files.isEmpty, let plan = WelcomePlanStore.shared.plan else { return }
        upsert(
            title: "Protocole actif",
            content: "Objectif : \(plan.primaryFaceGoal). Nutrition : \(plan.nutritionStructureLabel)."
        )
    }

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("coach.process_files", userId: uid)
        if let data = try? JSONEncoder().encode(files) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

private extension FaceOriginPlan {
    var nutritionStructureLabel: String {
        nutritionPlanType.label
    }
}
