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
        purgeEmptyConversations()
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
    }

    var activeConversation: CoachConversation? {
        library.activeConversation
    }

    var activeConversationId: UUID? {
        library.activeConversationId
    }

    var sortedConversations: [CoachConversation] {
        library.conversations
            .filter(\.hasUserMessages)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func mostRecentConversationWithUserMessages() -> CoachConversation? {
        sortedConversations.first
    }

    /// Supprime les fils vides (aucun message utilisateur) — ne doivent pas apparaître dans l’historique.
    func purgeEmptyConversations() {
        let previousCount = library.conversations.count
        library.conversations.removeAll { !$0.hasUserMessages }

        if let activeId = library.activeConversationId,
           !library.conversations.contains(where: { $0.id == activeId }) {
            library.activeConversationId = library.conversations.first?.id
        }

        if library.conversations.count != previousCount {
            saveLocal()
        }
    }

    func clearActiveSelection() {
        library.activeConversationId = nil
        saveLocal()
    }

    @discardableResult
    func promoteDraftConversation(id: UUID) -> UUID {
        if library.conversations.contains(where: { $0.id == id }) {
            library.activeConversationId = id
            saveLocal()
            return id
        }

        let conversation = CoachConversation(id: id, title: "Nouvelle conversation", messages: [])
        library.conversations.insert(conversation, at: 0)
        library.activeConversationId = id
        saveLocal()
        return id
    }

    func selectConversation(_ id: UUID) {
        library.activeConversationId = id
        saveLocal()
    }

    @discardableResult
    func createConversation(id: UUID? = nil) -> UUID {
        let conversationId = id ?? UUID()
        if library.conversations.contains(where: { $0.id == conversationId }) {
            library.activeConversationId = conversationId
            saveLocal()
            return conversationId
        }

        let conversation = CoachConversation(id: conversationId, title: "Nouvelle conversation", messages: [])
        library.conversations.insert(conversation, at: 0)
        library.activeConversationId = conversation.id
        saveLocal()
        return conversation.id
    }

    func updateConversation(_ id: UUID, _ transform: (inout CoachConversation) -> Void) {
        for conversationIndex in library.conversations.indices {
            guard library.conversations[conversationIndex].id == id else { continue }
            transform(&library.conversations[conversationIndex])
            library.conversations[conversationIndex].updatedAt = Date()
            saveLocal()
            return
        }
    }

    func updateActiveConversation(_ transform: (inout CoachConversation) -> Void) {
        guard let id = library.activeConversationId else { return }
        updateConversation(id, transform)
    }

    func setActiveMessages(_ messages: [CoachMessage]) {
        updateActiveConversation { $0.messages = messages }
    }

    func appendToActive(_ message: CoachMessage) {
        updateActiveConversation { $0.append(message) }
    }

    func deleteConversation(_ id: UUID) {
        library.conversations.removeAll { $0.id == id }
        library.sortByRecent()
        if library.activeConversationId == id
            || library.activeConversationId == nil
            || !library.conversations.contains(where: { $0.id == library.activeConversationId }) {
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
