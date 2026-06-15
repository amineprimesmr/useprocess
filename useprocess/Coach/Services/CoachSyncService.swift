import Foundation

@MainActor
enum CoachSyncService {

    static func loadConversation(userId: String?, conversationId: UUID) async -> CoachChatThread {
        let local = CoachConversationLibraryStore.shared.conversation(for: conversationId)
        let localThread = CoachChatThread(
            messages: local?.messages ?? [],
            updatedAt: local?.updatedAt ?? Date()
        )

        guard let userId,
              AppConfiguration.firebaseConfigured,
              AuthUser.current != nil else {
            return localThread
        }

        let remoteId = conversationId.uuidString
        guard let remote = try? await CoachFirestoreRepository.shared.fetchThreadWithLegacyFallback(
            userId: userId,
            conversationId: remoteId
        ), !remote.messages.isEmpty else {
            return localThread
        }

        if remote.messages.count >= localThread.messages.count {
            CoachConversationLibraryStore.shared.updateConversation(conversationId) { conv in
                conv.messages = remote.messages
                conv.updatedAt = remote.updatedAt
            }
            return remote
        }

        return localThread
    }

    static func appendMessage(
        _ message: CoachMessage,
        userId: String?,
        conversationId: UUID,
        title: String? = nil
    ) async {
        CoachConversationLibraryStore.shared.appendToActive(message)

        guard let userId,
              AppConfiguration.firebaseConfigured,
              AuthUser.current != nil else { return }

        try? await CoachFirestoreRepository.shared.appendMessage(
            userId: userId,
            conversationId: conversationId.uuidString,
            message: message,
            title: title
        )
    }

    static func replaceThread(
        _ thread: CoachChatThread,
        userId: String?,
        conversationId: UUID,
        title: String? = nil
    ) async {
        CoachConversationLibraryStore.shared.setActiveMessages(thread.messages)

        guard let userId,
              AppConfiguration.firebaseConfigured,
              AuthUser.current != nil else { return }

        try? await CoachFirestoreRepository.shared.replaceThread(
            userId: userId,
            conversationId: conversationId.uuidString,
            thread: thread,
            title: title
        )
    }

    static func deleteConversation(id: UUID, userId: String?) async {
        guard let userId,
              AppConfiguration.firebaseConfigured,
              AuthUser.current != nil else { return }

        try? await CoachFirestoreRepository.shared.deleteThread(
            userId: userId,
            conversationId: id.uuidString
        )
    }

    // MARK: - Legacy helpers (onboarding, etc.)

    static func appendMessage(_ message: CoachMessage, userId: String?) async {
        guard let conversationId = CoachConversationLibraryStore.shared.activeConversationId else { return }
        await appendMessage(message, userId: userId, conversationId: conversationId)
    }

    static func loadThread(userId: String?) async -> CoachChatThread {
        guard let id = CoachConversationLibraryStore.shared.activeConversationId else {
            return CoachChatThread()
        }
        return await loadConversation(userId: userId, conversationId: id)
    }

    static func replaceThread(_ thread: CoachChatThread, userId: String?) async {
        guard let id = CoachConversationLibraryStore.shared.activeConversationId else { return }
        await replaceThread(thread, userId: userId, conversationId: id)
    }

    static func resetThread(userId: String?) async {
        guard let id = CoachConversationLibraryStore.shared.activeConversationId else { return }
        let welcome = CoachConversationLibraryStore.shared.activeConversation?.messages.first
        let thread = CoachChatThread(
            messages: welcome.map { [$0] } ?? [],
            updatedAt: Date()
        )
        await replaceThread(thread, userId: userId, conversationId: id)
    }
}
