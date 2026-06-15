import Foundation

enum CoachMessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

struct CoachMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let role: CoachMessageRole
    let text: String
    let createdAt: Date
    var modelUsed: String?

    init(
        id: UUID = UUID(),
        role: CoachMessageRole,
        text: String,
        createdAt: Date = Date(),
        modelUsed: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.modelUsed = modelUsed
    }
}

struct CoachChatThread: Codable, Sendable {
    var messages: [CoachMessage]
    var updatedAt: Date

    init(messages: [CoachMessage] = [], updatedAt: Date = Date()) {
        self.messages = messages
        self.updatedAt = updatedAt
    }
}
