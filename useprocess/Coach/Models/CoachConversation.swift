import Foundation

struct CoachConversation: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var messages: [CoachMessage]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "Nouvelle conversation",
        messages: [CoachMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var preview: String {
        if let user = messages.last(where: { $0.role == .user })?.text, !user.isEmpty {
            return user
        }
        return messages.last(where: { $0.role == .assistant })?.text ?? "Conversation vide"
    }

    var messageCount: Int { messages.count }

    mutating func append(_ message: CoachMessage) {
        messages.append(message)
        updatedAt = Date()
    }

    mutating func applyAutoTitle(from userText: String) {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard title == "Nouvelle conversation" || title.isEmpty else { return }
        let maxLen = 44
        if trimmed.count <= maxLen {
            title = trimmed
        } else {
            title = String(trimmed.prefix(maxLen - 1)) + "…"
        }
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

struct CoachConversationLibrary: Codable, Sendable {
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
