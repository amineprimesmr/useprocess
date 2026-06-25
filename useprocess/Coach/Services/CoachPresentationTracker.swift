import Foundation

/// État global du coach — évite les notifs quand l'utilisateur lit déjà la conversation.
@MainActor
@Observable
final class CoachPresentationTracker {
    static let shared = CoachPresentationTracker()

    var isCoachPresented = false
    var isCoachChatActive = false
    var activeConversationId: UUID?
    var applicationIsActive = true

    private init() {}

    func shouldSuppressReplyNotification(for conversationId: UUID) -> Bool {
        applicationIsActive
            && isCoachPresented
            && isCoachChatActive
            && activeConversationId == conversationId
    }
}
