import Foundation

@MainActor
enum CoachSyncService {

    static func loadThread(userId: String?) async -> CoachChatThread {
        if let userId,
           AppConfiguration.firebaseConfigured,
           AuthUser.current != nil,
           let remote = try? await CoachFirestoreRepository.shared.fetchThread(userId: userId),
           !remote.messages.isEmpty {
            CoachConversationStore.saveThreadLocal(remote)
            return remote
        }
        return CoachConversationStore.loadThreadLocal()
    }

    static func appendMessage(_ message: CoachMessage, userId: String?) async {
        CoachConversationStore.appendMessageLocal(message)
        guard let userId,
              AppConfiguration.firebaseConfigured,
              AuthUser.current != nil else { return }
        try? await CoachFirestoreRepository.shared.appendMessage(userId: userId, message: message)
    }

    static func replaceThread(_ thread: CoachChatThread, userId: String?) async {
        CoachConversationStore.saveThreadLocal(thread)
        guard let userId,
              AppConfiguration.firebaseConfigured,
              AuthUser.current != nil else { return }
        try? await CoachFirestoreRepository.shared.replaceThread(userId: userId, thread: thread)
    }

    static func resetThread(userId: String?) async {
        CoachConversationStore.resetThreadLocal()
        guard let userId,
              AppConfiguration.firebaseConfigured,
              AuthUser.current != nil else { return }
        try? await CoachFirestoreRepository.shared.resetThread(userId: userId)
    }
}
