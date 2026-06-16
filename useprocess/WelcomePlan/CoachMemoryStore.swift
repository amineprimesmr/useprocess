import Foundation

struct CoachConversationDigest: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var lastUserSnippet: String
    var lastAssistantSnippet: String
    var updatedAt: Date
    var messageCount: Int
}

struct CoachGlobalMemory: Codable, Equatable {
    var lastUpdated: Date = Date()
    var keyFacts: [String] = []
    var planAdjustments: [String] = []
    var conversationDigests: [CoachConversationDigest] = []
    var aiSummary: String?
    var aiSummaryUpdatedAt: Date?
}

@MainActor
@Observable
final class CoachMemoryStore {
    static let shared = CoachMemoryStore()

    private(set) var memory = CoachGlobalMemory()

    private init() {
        reload()
    }

    func reload() {
        let key = storageKey
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(CoachGlobalMemory.self, from: data) else {
            memory = CoachGlobalMemory()
            return
        }
        memory = decoded
    }

    func reloadForCurrentUser() {
        reload()
        refreshConversationDigests(excludingActiveId: CoachConversationLibraryStore.shared.activeConversationId)
    }

    func refreshConversationDigests(excludingActiveId: UUID? = nil) {
        let conversations = CoachConversationLibraryStore.shared.sortedConversations
        memory.conversationDigests = conversations
            .filter { $0.id != excludingActiveId }
            .prefix(12)
            .map { conv in
                let lastUser = conv.messages.last(where: { $0.role == .user })?.text ?? ""
                let lastAssistant = conv.messages.last(where: { $0.role == .assistant })?.text ?? ""
                return CoachConversationDigest(
                    id: conv.id.uuidString,
                    title: conv.title,
                    lastUserSnippet: String(lastUser.prefix(120)),
                    lastAssistantSnippet: String(lastAssistant.prefix(120)),
                    updatedAt: conv.updatedAt,
                    messageCount: conv.messageCount
                )
            }
        memory.lastUpdated = Date()
        persist()
    }

    func recordExchange(userText: String, assistantText: String, conversationTitle: String?) {
        extractFacts(from: userText)

        if let title = conversationTitle, !title.isEmpty, title != "Nouvelle conversation" {
            if !memory.keyFacts.contains(where: { $0.contains(title) }) {
                appendFact("Conversation « \(title) » : sujet abordé récemment")
            }
        }

        let userLower = userText.lowercased()
        if userLower.contains("douleur") || userLower.contains("bless") {
            appendFact("Mention récente douleur/blessure : \(String(userText.prefix(80)))")
        }
        if userLower.contains("plan") || userLower.contains("protocole") {
            appendFact("Discussion plan récente : \(String(userText.prefix(80)))")
        }

        memory.lastUpdated = Date()
        persist()
    }

    func recordPlanAdjustment(_ summary: String) {
        memory.planAdjustments.insert(summary, at: 0)
        memory.planAdjustments = Array(memory.planAdjustments.prefix(20))
        appendFact("Ajustement plan : \(summary)")
        persist()
    }

    func setAISummary(_ summary: String) {
        memory.aiSummary = summary
        memory.aiSummaryUpdatedAt = Date()
        memory.lastUpdated = Date()
        persist()
    }

    private func extractFacts(from userText: String) {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 12 else { return }
        if trimmed.hasSuffix("?") { return }
        appendFact("Utilisateur : \(String(trimmed.prefix(100)))")
    }

    private func appendFact(_ fact: String) {
        memory.keyFacts.insert(fact, at: 0)
        memory.keyFacts = Array(memory.keyFacts.prefix(35))
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        if let uid = UserScopedStorage.currentUserId() {
            Task {
                await WelcomePlanFirestoreRepository.shared.saveMemory(memory, userId: uid)
            }
        }
    }

    private var storageKey: String {
        UserScopedStorage.key("coach.global.memory", userId: UserScopedStorage.currentUserId())
    }

    func clearForUser(userId: String) {
        UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("coach.global.memory", userId: userId))
        memory = CoachGlobalMemory()
    }
}
