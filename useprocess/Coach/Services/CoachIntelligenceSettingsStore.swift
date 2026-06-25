import Foundation

enum CoachIntelligencePersonality: String, CaseIterable, Identifiable, Codable {
    case dataNerd = "data_nerd"
    case guardian = "guardian"
    case warmGuide = "warm_guide"
    case directCoach = "direct_coach"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dataNerd: return "Nerd des données"
        case .guardian: return "Guardian"
        case .warmGuide: return "Guide bienveillant"
        case .directCoach: return "Commander"
        }
    }
}

@MainActor
@Observable
final class CoachIntelligenceSettingsStore {
    static let shared = CoachIntelligenceSettingsStore()

    var isEnabled: Bool {
        didSet { persist() }
    }

    var personality: CoachIntelligencePersonality {
        didSet { persist() }
    }

    var showsExtendedReasoning: Bool {
        didSet { persist() }
    }

    var showsSuggestedFollowUps: Bool {
        didSet { persist() }
    }

    var sharesReproductiveHealth: Bool {
        didSet { persist() }
    }

    var weeklyMessageCount: Int {
        didSet { persistUsage() }
    }

    var extraCredits: Int {
        didSet { persistUsage() }
    }

    private(set) var weeklyResetAt: Date

    private let weeklyLimit = 120

    var weeklyUsagePercent: Int {
        guard weeklyLimit > 0 else { return 0 }
        return min(100, Int((Double(weeklyMessageCount) / Double(weeklyLimit)) * 100))
    }

    var weeklyUsageLabel: String { "\(weeklyUsagePercent) % utilisés" }
    var creditsLabel: String { "\(extraCredits) crédit\(extraCredits > 1 ? "s" : "")" }

    var canSendCoachMessage: Bool {
        rollWeeklyUsageIfNeeded()
        if weeklyMessageCount < weeklyLimit { return true }
        return extraCredits > 0
    }

    var quotaExceededMessage: String {
        "Limite hebdomadaire atteinte. Réinitialisation \(weeklyResetLabel.lowercased())."
    }

    var weeklyResetLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM"
        let day = formatter.string(from: weeklyResetAt)
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: weeklyResetAt)
        return "Limite réinitialisée à \(day) à \(time)"
    }

    private init() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let prefix = UserScopedStorage.key("coach.intelligence", userId: uid)

        isEnabled = UserDefaults.standard.object(forKey: "\(prefix).enabled") as? Bool ?? true
        let personalityRaw = UserDefaults.standard.string(forKey: "\(prefix).personality") ?? CoachIntelligencePersonality.dataNerd.rawValue
        personality = CoachIntelligencePersonality(rawValue: personalityRaw) ?? .dataNerd
        showsExtendedReasoning = UserDefaults.standard.object(forKey: "\(prefix).extendedReasoning") as? Bool ?? true
        showsSuggestedFollowUps = UserDefaults.standard.object(forKey: "\(prefix).followUps") as? Bool ?? true
        sharesReproductiveHealth = UserDefaults.standard.object(forKey: "\(prefix).reproductiveHealth") as? Bool ?? false

        weeklyMessageCount = UserDefaults.standard.integer(forKey: "\(prefix).weeklyCount")
        extraCredits = UserDefaults.standard.integer(forKey: "\(prefix).extraCredits")

        if let reset = UserDefaults.standard.object(forKey: "\(prefix).weeklyReset") as? Date {
            weeklyResetAt = reset
        } else {
            weeklyResetAt = Self.nextWeeklyReset(from: .now)
        }

        rollWeeklyUsageIfNeeded()
    }

    func reloadForCurrentUser() {
        rollWeeklyUsageIfNeeded()
    }

    func recordCoachMessageSent() {
        rollWeeklyUsageIfNeeded()
        if weeklyMessageCount < weeklyLimit {
            weeklyMessageCount += 1
        } else if extraCredits > 0 {
            extraCredits -= 1
        }
    }

    func syncSubscriberCreditsIfNeeded() {
        rollWeeklyUsageIfNeeded()
        guard SubscriptionService.shared.subscriptionStatus.isActive else { return }

        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let prefix = UserScopedStorage.key("coach.intelligence", userId: uid)
        let grantKey = "\(prefix).subscriberGrantWeek"
        let weekToken = ISO8601DateFormatter().string(from: weeklyResetAt)

        guard UserDefaults.standard.string(forKey: grantKey) != weekToken else { return }
        extraCredits += 50
        UserDefaults.standard.set(weekToken, forKey: grantKey)
        persistUsage()
    }

    #if DEBUG
    func grantDebugCredits(_ amount: Int) {
        extraCredits += max(0, amount)
    }
    #endif

    func resyncConversationHistory() async {
        guard let uid = UserScopedStorage.currentUserId(),
              AppConfiguration.firebaseConfigured,
              AuthUser.current != nil else { return }

        let library = CoachConversationLibraryStore.shared
        for conversation in library.sortedConversations {
            _ = await CoachSyncService.loadConversation(userId: uid, conversationId: conversation.id)
        }
    }

    func deleteAllConversations(userId: String?) async {
        let ids = CoachConversationLibraryStore.shared.sortedConversations.map(\.id)
        for id in ids {
            await CoachSyncService.deleteConversation(id: id, userId: userId)
            CoachConversationLibraryStore.shared.deleteConversation(id)
        }
        CoachConversationLibraryStore.shared.purgeEmptyConversations()
    }

    func deleteAllCoachFiles(userId: String?) {
        if let uid = userId {
            CoachConversationLibraryStore.shared.clearStoredData(userId: uid)
        }
        FaceScanHistoryStore.shared.clearForUser(userId: userId)
        CoachProcessFilesStore.shared.deleteAll()
        CoachMyMemoryStore.shared.deleteAll()
    }

    @discardableResult
    private func rollWeeklyUsageIfNeeded() -> Bool {
        guard Date.now >= weeklyResetAt else { return false }
        weeklyMessageCount = 0
        weeklyResetAt = Self.nextWeeklyReset(from: .now)
        persistUsage()
        return true
    }

    private static func nextWeeklyReset(from date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.firstWeekday = 2
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return calendar.date(byAdding: .day, value: 7, to: startOfWeek)?
            .addingTimeInterval(2 * 3600) ?? date.addingTimeInterval(7 * 24 * 3600)
    }

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let prefix = UserScopedStorage.key("coach.intelligence", userId: uid)
        UserDefaults.standard.set(isEnabled, forKey: "\(prefix).enabled")
        UserDefaults.standard.set(personality.rawValue, forKey: "\(prefix).personality")
        UserDefaults.standard.set(showsExtendedReasoning, forKey: "\(prefix).extendedReasoning")
        UserDefaults.standard.set(showsSuggestedFollowUps, forKey: "\(prefix).followUps")
        UserDefaults.standard.set(sharesReproductiveHealth, forKey: "\(prefix).reproductiveHealth")
    }

    private func persistUsage() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let prefix = UserScopedStorage.key("coach.intelligence", userId: uid)
        UserDefaults.standard.set(weeklyMessageCount, forKey: "\(prefix).weeklyCount")
        UserDefaults.standard.set(extraCredits, forKey: "\(prefix).extraCredits")
        UserDefaults.standard.set(weeklyResetAt, forKey: "\(prefix).weeklyReset")
    }
}
