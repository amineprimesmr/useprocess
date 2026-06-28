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
    private var mealDetailPresentationCount = 0

    var isMealDetailPresented: Bool {
        mealDetailPresentationCount > 0
    }

    func beginMealDetailPresentation() {
        mealDetailPresentationCount += 1
    }

    func endMealDetailPresentation() {
        mealDetailPresentationCount = max(0, mealDetailPresentationCount - 1)
    }

    /// Typewriter haptics uniquement quand le coach est réellement affiché.
    var allowsTypewriterHaptics: Bool {
        isCoachPresented
    }

    private init() {}

    func shouldSuppressReplyNotification(for conversationId: UUID) -> Bool {
        applicationIsActive
            && isCoachPresented
            && isCoachChatActive
            && activeConversationId == conversationId
    }
}
