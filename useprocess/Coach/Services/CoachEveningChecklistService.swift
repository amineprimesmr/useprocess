import Foundation

@MainActor
enum CoachEveningChecklistService {
    static let messageMarker = "process.evening_checklist"

    static func isEveningMessage(_ message: CoachMessage) -> Bool {
        message.modelUsed == messageMarker
    }

    @discardableResult
    static func deliverEveningMessageIfNeeded(force: Bool = false) async -> Bool {
        guard CoachIntelligenceSettingsStore.shared.isEnabled else { return false }
        guard CoachDailyRhythmService.eveningReviewEnabled else { return false }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        guard force || hour >= 21 else { return false }

        guard let plan = WelcomePlanStore.shared.plan,
              OriginPlanPresenter.todayDay(in: plan) != nil else { return false }

        if alreadyDeliveredToday() { return false }

        guard let conversationId = ensureTargetConversationId() else { return false }

        let store = CoachConversationLibraryStore.shared
        if let conversation = store.conversation(for: conversationId),
           conversation.messages.contains(where: { isEveningMessage($0) && calendar.isDateInToday($0.createdAt) }) {
            markDeliveredToday()
            return false
        }

        let streak = ProcessStreakStore.shared.snapshot.currentStreak
        let message = CoachMessage(
            role: .assistant,
            text: messageText(streak: streak),
            modelUsed: messageMarker
        )

        let userId = UserScopedStorage.currentUserId()
        await CoachSyncService.appendMessage(message, userId: userId, conversationId: conversationId)
        markDeliveredToday()
        CoachPlanNavigationBridge.shared.bumpEveningChecklistRefresh()
        return true
    }

    static func messageText(streak: Int) -> String {
        if streak > 0 {
            return "Salut ! Avant de dormir, fais ta checklist du soir — ça compte pour garder ta streak de \(streak) jour\(streak > 1 ? "s" : "") 🔥"
        }
        return "Salut ! Deux minutes pour ta checklist du soir ? Ça lance ou garde ta streak 🔥"
    }

    private static func ensureTargetConversationId() -> UUID? {
        let store = CoachConversationLibraryStore.shared
        store.loadLocal()

        if let activeId = store.activeConversationId,
           let conversation = store.conversation(for: activeId),
           conversation.hasUserMessages {
            return activeId
        }

        if let recent = store.mostRecentConversationWithUserMessages() {
            store.selectConversation(recent.id)
            return recent.id
        }

        return store.createConversation()
    }

    private static func alreadyDeliveredToday() -> Bool {
        guard let stored = UserDefaults.standard.string(forKey: deliveredDayKey()) else { return false }
        return stored == todayKey()
    }

    private static func markDeliveredToday() {
        UserDefaults.standard.set(todayKey(), forKey: deliveredDayKey())
    }

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private static func deliveredDayKey() -> String {
        UserScopedStorage.key(
            "coach.evening_checklist.delivered_day",
            userId: UserScopedStorage.currentUserId()
        )
    }
}
