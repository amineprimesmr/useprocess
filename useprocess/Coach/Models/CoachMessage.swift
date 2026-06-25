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
    var reasoning: String?
    var followUps: [String]?
    var deepLinkAction: String?
    var deepLinkLabel: String?

    init(
        id: UUID = UUID(),
        role: CoachMessageRole,
        text: String,
        createdAt: Date = Date(),
        modelUsed: String? = nil,
        reasoning: String? = nil,
        followUps: [String]? = nil,
        deepLinkAction: String? = nil,
        deepLinkLabel: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.modelUsed = modelUsed
        self.reasoning = reasoning
        self.followUps = followUps
        self.deepLinkAction = deepLinkAction
        self.deepLinkLabel = deepLinkLabel
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
