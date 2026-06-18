import Foundation

@MainActor
@Observable
final class CoachConversationLibraryStore {
    static let shared = CoachConversationLibraryStore()

    private(set) var library = CoachConversationLibrary()
    private var userId: String?

    private var libraryKey: String {
        UserScopedStorage.key("coach.conversations.library", userId: userId)
    }

    private var legacyThreadKey: String {
        UserScopedStorage.key("coach.thread", userId: userId)
    }

    private init() {}

    func reloadForUser(userId newUserId: String?) {
        userId = newUserId
        loadLocal()
    }

    func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: libraryKey),
              let decoded = try? JSONDecoder().decode(CoachConversationLibrary.self, from: data) else {
            library = CoachConversationLibrary()
            return
        }
        library = decoded
        library.sortByRecent()
    }

    func saveLocal() {
        library.sortByRecent()
        guard let data = try? JSONEncoder().encode(library) else { return }
        UserDefaults.standard.set(data, forKey: libraryKey)
    }

    func migrateLegacyThreadIfNeeded() {
        guard library.conversations.isEmpty else { return }

        if let data = UserDefaults.standard.data(forKey: legacyThreadKey),
           let legacy = try? JSONDecoder().decode(CoachChatThread.self, from: data),
           !legacy.messages.isEmpty {
            let sanitized = CoachHomeContext.sanitizedMessages(legacy.messages)
            let title = sanitized
                .first(where: { $0.role == .user })
                .map { CoachConversationSubjectService.keywords(from: $0.text) } ?? "Conversation"
            var conversation = CoachConversation.fromLegacyThread(
                CoachChatThread(messages: sanitized),
                title: title
            )
            conversation.subjectLabel = title
            if conversation.title.isEmpty { conversation.title = "Conversation" }
            library.conversations = [conversation]
            library.activeConversationId = conversation.id
            saveLocal()
            return
        }

        let conversation = CoachConversation(title: "Nouvelle conversation", messages: [])
        library.conversations = [conversation]
        library.activeConversationId = conversation.id
        saveLocal()
    }

    var activeConversation: CoachConversation? {
        library.activeConversation
    }

    var activeConversationId: UUID? {
        library.activeConversationId
    }

    var sortedConversations: [CoachConversation] {
        library.conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func selectConversation(_ id: UUID) {
        library.activeConversationId = id
        saveLocal()
    }

    @discardableResult
    func createConversation() -> UUID {
        let conversation = CoachConversation(title: "Nouvelle conversation", messages: [])
        library.conversations.insert(conversation, at: 0)
        library.activeConversationId = conversation.id
        saveLocal()
        return conversation.id
    }

    func updateConversation(_ id: UUID, _ transform: (inout CoachConversation) -> Void) {
        guard let index = library.conversations.firstIndex(where: { $0.id == id }) else { return }
        transform(&library.conversations[index])
        library.conversations[index].updatedAt = Date()
        saveLocal()
    }

    func updateActiveConversation(_ transform: (inout CoachConversation) -> Void) {
        guard let id = library.activeConversationId,
              let index = library.conversations.firstIndex(where: { $0.id == id }) else { return }
        transform(&library.conversations[index])
        library.conversations[index].updatedAt = Date()
        saveLocal()
    }

    func setActiveMessages(_ messages: [CoachMessage]) {
        updateActiveConversation { $0.messages = messages }
    }

    func appendToActive(_ message: CoachMessage) {
        updateActiveConversation { $0.append(message) }
    }

    func deleteConversation(_ id: UUID) {
        library.conversations.removeAll { $0.id == id }
        if library.activeConversationId == id {
            library.activeConversationId = library.conversations.first?.id
        }
        saveLocal()
    }

    func conversation(for id: UUID) -> CoachConversation? {
        library.conversations.first { $0.id == id }
    }

    func clearStoredData(userId: String) {
        UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("coach.conversations.library", userId: userId))
        UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("coach.thread", userId: userId))
        library = CoachConversationLibrary()
        self.userId = nil
    }
}
