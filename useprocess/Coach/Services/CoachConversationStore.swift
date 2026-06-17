import Foundation

@MainActor
enum CoachConversationStore {
    private static var userId: String?

    private static var threadKey: String {
        UserScopedStorage.key("coach.thread", userId: userId)
    }

    private static var dailyBriefKey: String {
        UserScopedStorage.key("coach.daily_brief", userId: userId)
    }

    private static var dailyBriefDateKey: String {
        UserScopedStorage.key("coach.daily_brief_date", userId: userId)
    }

    static func reloadForUser(userId newUserId: String?) {
        userId = newUserId
        CoachConversationLibraryStore.shared.reloadForUser(userId: newUserId)
    }

    static func loadThreadLocal() -> CoachChatThread {
        if let active = CoachConversationLibraryStore.shared.activeConversation {
            return CoachChatThread(messages: active.messages, updatedAt: active.updatedAt)
        }
        guard let data = UserDefaults.standard.data(forKey: threadKey),
              let thread = try? JSONDecoder().decode(CoachChatThread.self, from: data) else {
            return CoachChatThread()
        }
        return thread
    }

    static func saveThreadLocal(_ thread: CoachChatThread) {
        CoachConversationLibraryStore.shared.setActiveMessages(thread.messages)
    }

    static func appendMessageLocal(_ message: CoachMessage) {
        CoachConversationLibraryStore.shared.appendToActive(message)
    }

    static func resetThreadLocal() {
        CoachConversationLibraryStore.shared.setActiveMessages([])
    }

    static func loadThread(userId: String? = nil) -> CoachChatThread {
        loadThreadLocal()
    }

    static func appendMessage(_ message: CoachMessage) {
        Task { @MainActor in
            let store = CoachConversationLibraryStore.shared
            store.loadLocal()
            let welcome = CoachEngine.welcomeMessage(profile: UnifiedProfileService.shared.currentProfile)
            store.migrateLegacyThreadIfNeeded(welcome: welcome)
            guard let conversationId = store.activeConversationId else { return }
            await CoachSyncService.appendMessage(
                message,
                userId: AuthUser.current?.uid,
                conversationId: conversationId,
                title: store.activeConversation?.title
            )
        }
    }

    static func stripInjectedProgramSummaryMessages() {
        let store = CoachConversationLibraryStore.shared
        store.loadLocal()
        guard store.activeConversation != nil else { return }

        let filtered = store.activeConversation?.messages.filter { !isInjectedProgramSummary($0) } ?? []
        guard filtered.count != store.activeConversation?.messages.count else { return }

        store.setActiveMessages(filtered)

        Task {
            guard let conversationId = store.activeConversationId else { return }
            await CoachSyncService.replaceThread(
                CoachChatThread(messages: filtered),
                userId: AuthUser.current?.uid,
                conversationId: conversationId,
                title: store.activeConversation?.title
            )
        }
    }

    static func shouldHideProgramSummaryMessage(_ message: CoachMessage) -> Bool {
        isInjectedProgramSummary(message)
    }

    private static func isInjectedProgramSummary(_ message: CoachMessage) -> Bool {
        guard message.role == .assistant else { return false }
        let text = message.text
        if text.contains("## Bienvenue dans \(AppBranding.name)") { return true }
        if text.contains("Pose-moi tes questions ici quand tu veux.") { return true }
        return text.count > 320 && text.localizedCaseInsensitiveContains("protocole origine")
    }

    static func resetThread() {
        resetThreadLocal()
        Task {
            await CoachSyncService.resetThread(userId: AuthUser.current?.uid)
        }
    }

    static func cachedDailyBrief() -> String? {
        let today = Calendar.current.startOfDay(for: Date())
        guard let cachedDate = UserDefaults.standard.object(forKey: dailyBriefDateKey) as? Date,
              Calendar.current.isDate(cachedDate, inSameDayAs: today) else {
            return nil
        }
        return UserDefaults.standard.string(forKey: dailyBriefKey)
    }

    static func cacheDailyBrief(_ text: String) {
        UserDefaults.standard.set(text, forKey: dailyBriefKey)
        UserDefaults.standard.set(Date(), forKey: dailyBriefDateKey)
    }
}
