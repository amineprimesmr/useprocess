import Foundation

@MainActor
enum CoachConversationStore {
    private static let threadKey = "useprocess.coach.thread"
    private static let dailyBriefKey = "useprocess.coach.daily_brief"
    private static let dailyBriefDateKey = "useprocess.coach.daily_brief_date"

    static func loadThreadLocal() -> CoachChatThread {
        guard let data = UserDefaults.standard.data(forKey: threadKey),
              let thread = try? JSONDecoder().decode(CoachChatThread.self, from: data) else {
            return CoachChatThread()
        }
        return thread
    }

    static func saveThreadLocal(_ thread: CoachChatThread) {
        guard let data = try? JSONEncoder().encode(thread) else { return }
        UserDefaults.standard.set(data, forKey: threadKey)
    }

    static func appendMessageLocal(_ message: CoachMessage) {
        var thread = loadThreadLocal()
        thread.messages.append(message)
        thread.updatedAt = Date()
        saveThreadLocal(thread)
    }

    static func resetThreadLocal() {
        UserDefaults.standard.removeObject(forKey: threadKey)
    }

    /// Compat — charge local puis sync Firestore si possible.
    static func loadThread(userId: String? = nil) -> CoachChatThread {
        loadThreadLocal()
    }

    static func appendMessage(_ message: CoachMessage) {
        appendMessageLocal(message)
        Task {
            await CoachSyncService.appendMessage(message, userId: AuthUser.current?.uid)
        }
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
