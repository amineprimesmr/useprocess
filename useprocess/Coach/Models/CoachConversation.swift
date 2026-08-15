import Foundation

struct CoachConversation: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    /// Sujet court (mots-clés) pour l’historique — distinct de la question complète.
    var subjectLabel: String?
    var messages: [CoachMessage]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "Nouvelle conversation",
        subjectLabel: String? = nil,
        messages: [CoachMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subjectLabel = subjectLabel
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var preview: String {
        if let user = messages.last(where: { $0.role == .user })?.text, !user.isEmpty {
            return user
        }
        return messages.last(where: { $0.role == .assistant })?.text
            ?? AppCopy.tSync("Conversation vide", en: "Empty conversation")
    }

    /// Sujet court pour l’historique (menu latéral).
    var sidebarSubject: String {
        if let firstUser = messages.first(where: { $0.role == .user })?.text {
            let keywords = CoachConversationSubjectService.keywords(from: firstUser)
            if let subjectLabel, !subjectLabel.isEmpty, !Self.looksLikeFullQuestion(subjectLabel) {
                return Self.localizedStoredTitle(subjectLabel)
            }
            return keywords
        }
        if !Self.isPlaceholderTitle(title), !Self.looksLikeFullQuestion(title) {
            return Self.localizedStoredTitle(title)
        }
        if !Self.isPlaceholderTitle(title) {
            return CoachConversationSubjectService.keywords(from: title)
        }
        return AppCopy.tSync("Conversation", en: "Conversation")
    }

    var messageCount: Int { messages.count }

    /// Une conversation n’entre dans l’historique qu’après au moins un message utilisateur.
    var hasUserMessages: Bool {
        messages.contains { message in
            guard message.role == .user else { return false }
            return !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    mutating func append(_ message: CoachMessage) {
        messages.append(message)
        updatedAt = Date()
    }

    mutating func applyAutoTitle(from userText: String) {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard Self.isUntitled(title) else { return }

        let subject = CoachConversationSubjectService.keywords(from: trimmed)
        subjectLabel = subject
        title = subject
    }

    mutating func applySubjectLabel(_ label: String) {
        let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        subjectLabel = cleaned
        title = cleaned
    }

    private static let placeholderTitles: Set<String> = [
        "Nouvelle conversation",
        "New conversation",
        "Conversation",
        "Conversation vide",
        "Empty conversation",
    ]

    private static func isPlaceholderTitle(_ title: String) -> Bool {
        placeholderTitles.contains(title.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func isUntitled(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            || trimmed == "Nouvelle conversation"
            || trimmed == "New conversation"
    }

    static func localizedStoredTitle(_ title: String) -> String {
        switch title.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Nouvelle conversation", "New conversation":
            return AppCopy.tSync("Nouvelle conversation", en: "New conversation")
        case "Conversation":
            return AppCopy.tSync("Conversation", en: "Conversation")
        case "Conversation vide", "Empty conversation":
            return AppCopy.tSync("Conversation vide", en: "Empty conversation")
        case "Trajectoire debloat", "Debloat trajectory":
            return AppCopy.tSync("Trajectoire debloat", en: "Debloat trajectory")
        default:
            return title
        }
    }

    private static func looksLikeFullQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("?") || trimmed.count > 44
    }

    static func fromLegacyThread(_ thread: CoachChatThread, title: String = "Conversation") -> CoachConversation {
        CoachConversation(
            title: title,
            messages: thread.messages,
            createdAt: thread.messages.first?.createdAt ?? thread.updatedAt,
            updatedAt: thread.updatedAt
        )
    }
}

struct CoachConversationLibrary: nonisolated Codable, Sendable {
    var conversations: [CoachConversation]
    var activeConversationId: UUID?

    init(conversations: [CoachConversation] = [], activeConversationId: UUID? = nil) {
        self.conversations = conversations
        self.activeConversationId = activeConversationId
    }

    var activeConversation: CoachConversation? {
        guard let id = activeConversationId else { return conversations.first }
        return conversations.first { $0.id == id }
    }

    mutating func sortByRecent() {
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }
}
