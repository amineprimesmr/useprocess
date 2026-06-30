import SwiftUI

/// État global de l'application.
@MainActor
@Observable
final class AppSession {
    static let shared = AppSession()

    var hasCompletedOnboarding: Bool
    var hasCompletedWelcomePlanChat: Bool
    var appearance: AppAppearance
    /// Empêche UserSessionCoordinator de recharger l'onboarding pendant une suppression.
    private(set) var isAccountWipeInProgress = false
    var accountDeletionErrorMessage: String?

    func beginAccountDeletion() {
        isAccountWipeInProgress = true
        accountDeletionErrorMessage = nil
    }

    func cancelAccountDeletion() {
        isAccountWipeInProgress = false
    }

    private init() {
        let uid = UserScopedStorage.currentUserId()
        let onboardingKey = UserScopedStorage.key("onboarding.completed", userId: uid)
        let completedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
        hasCompletedOnboarding = completedOnboarding

        hasCompletedWelcomePlanChat = Self.resolveWelcomePlanChatCompleted(
            completedOnboarding: completedOnboarding,
            userId: uid
        )

        let rawAppearance = UserDefaults.standard.string(forKey: Keys.appearance) ?? AppAppearance.system.rawValue
        appearance = AppAppearance(rawValue: rawAppearance) ?? .system
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingStorageKey)
        AuthenticationManager.shared.completeOnboarding()

        // Le Protocole Origine reste obligatoire après l'onboarding.
        hasCompletedWelcomePlanChat = false
        UserDefaults.standard.set(false, forKey: welcomePlanChatStorageKey)
    }

    func completeWelcomePlanChat() {
        hasCompletedWelcomePlanChat = true
        UserDefaults.standard.set(true, forKey: welcomePlanChatStorageKey)
    }

    func setWelcomePlanChatCompleted(_ completed: Bool) {
        hasCompletedWelcomePlanChat = completed
        UserDefaults.standard.set(completed, forKey: welcomePlanChatStorageKey)
    }

    func resetOnboarding() {
        let uid = UnifiedProfileService.shared.currentProfile?.userId
            ?? UserScopedStorage.currentUserId()
            ?? "local-user"

        hasCompletedOnboarding = false
        hasCompletedWelcomePlanChat = false

        for id in UserScopedStorage.likelyUserIds(primary: uid) {
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("onboarding.completed", userId: id))
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("welcome.plan.chat.completed", userId: id))
        }

        OnboardingProgressService.shared.resetProgress()
        WelcomePlanStore.shared.resetForCurrentUser()
        WelcomePlanCoachPresentation.resetForCurrentUser()
        AuthenticationManager.shared.hasCompletedOnboarding = false
    }

    /// Remet l'app au parcours d'accueil (onboarding) après suppression de compte.
    func resetAfterAccountDeletion(primaryUID: String? = nil) {
        hasCompletedOnboarding = false
        hasCompletedWelcomePlanChat = false

        let primary = primaryUID
            ?? UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
            ?? "local-user"

        for uid in UserScopedStorage.likelyUserIds(primary: primary) {
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("onboarding.completed", userId: uid))
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("welcome.plan.chat.completed", userId: uid))
        }

        OnboardingProgressService.shared.resetProgress()
        WelcomePlanStore.shared.resetForCurrentUser()
        WelcomePlanCoachPresentation.resetForCurrentUser()

        AuthenticationManager.shared.applyPostAccountDeletion()
        AuthenticationManager.shared.startOnboarding()
    }

    /// Suppression complète du compte : Firebase d'abord, puis données locales + retour onboarding.
    func deleteAccount() async throws {
        accountDeletionErrorMessage = nil
        isAccountWipeInProgress = true
        defer { isAccountWipeInProgress = false }

        try await AuthenticationManager.shared.deleteRemoteAccount()

        let primaryUID = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
            ?? "local-user"

        CoachConversationStore.resetThread()
        CoachConversationLibraryStore.shared.clearStoredData(userId: primaryUID)
        CoachMemoryStore.shared.clearForUser(userId: primaryUID)
        SocialProfileStore.shared.resetForUser(userId: primaryUID)
        BodyScanHistoryStore.shared.clearForUser(userId: primaryUID)
        FaceScanHistoryStore.shared.clearForUser(userId: primaryUID)
        FaceScanImageStore.deleteAllStoredMedia()
        OnboardingFaceMarkersStore.clear()

        for uid in UserScopedStorage.likelyUserIds(primary: primaryUID) {
            UserScopedStorage.clearAllUserData(userId: uid)
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("onboarding.completed", userId: uid))
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("welcome.plan.chat.completed", userId: uid))
        }

        UnifiedProfileService.shared.clearLocalProfile()
        resetAfterAccountDeletion(primaryUID: primaryUID)
        UserSessionCoordinator.shared.handleAccountDeleted()
    }

    func reloadForCurrentUser() {
        guard !isAccountWipeInProgress else { return }

        guard AuthUser.current != nil else {
            hasCompletedOnboarding = false
            hasCompletedWelcomePlanChat = false
            return
        }

        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingStorageKey)
        WelcomePlanStore.shared.reloadForCurrentUser()
        hasCompletedWelcomePlanChat = Self.resolveWelcomePlanChatCompleted(
            completedOnboarding: hasCompletedOnboarding,
            userId: UserScopedStorage.currentUserId() ?? UnifiedProfileService.shared.currentProfile?.userId
        )
    }

    /// Détermine si le questionnaire Protocole Origine est vraiment terminé (évite la fausse complétion au relaunch).
    private static func resolveWelcomePlanChatCompleted(completedOnboarding: Bool, userId: String?) -> Bool {
        guard completedOnboarding else { return false }

        let uid = userId ?? "local-user"
        let welcomeKey = UserScopedStorage.key("welcome.plan.chat.completed", userId: uid)
        let questionnaire = loadPersistedQuestionnaire(userId: uid)
        let isFullyAnswered = questionnaire.map {
            WelcomePlanQuestionBank.isFullyAnswered(answers: $0.answers)
        } ?? false
        let hasCompletedQuestionnaire = questionnaire?.completedAt != nil && isFullyAnswered
        let hasSavedPlan = UserDefaults.standard.data(
            forKey: UserScopedStorage.key("welcome.plan", userId: uid)
        ) != nil
        let hasValidCompletion = hasCompletedQuestionnaire && hasSavedPlan && isFullyAnswered

        if UserDefaults.standard.object(forKey: welcomeKey) != nil {
            let explicit = UserDefaults.standard.bool(forKey: welcomeKey)
            if explicit, hasValidCompletion {
                return true
            }
            if explicit {
                // Flag true sans configuration réellement terminée → réparer.
                UserDefaults.standard.set(false, forKey: welcomeKey)
            }
            return false
        }

        // Anciens comptes (avant le flag) : exemptés seulement s'ils ont un plan ET toutes les réponses.
        if hasValidCompletion {
            UserDefaults.standard.set(true, forKey: welcomeKey)
            return true
        }

        return false
    }

    private static func loadPersistedQuestionnaire(userId: String) -> WelcomePlanQuestionnaireState? {
        let key = UserScopedStorage.key("welcome.questionnaire", userId: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WelcomePlanQuestionnaireState.self, from: data)
    }

    func setAppearance(_ mode: AppAppearance) {
        appearance = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Keys.appearance)
    }

    private var onboardingStorageKey: String {
        UserScopedStorage.key(
            "onboarding.completed",
            userId: UserScopedStorage.currentUserId() ?? UnifiedProfileService.shared.currentProfile?.userId
        )
    }

    private var welcomePlanChatStorageKey: String {
        UserScopedStorage.key(
            "welcome.plan.chat.completed",
            userId: UserScopedStorage.currentUserId() ?? UnifiedProfileService.shared.currentProfile?.userId
        )
    }

    private enum Keys {
        static var appearance: String { UserScopedStorage.globalKey("appearance") }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Automatique"
        case .dark: return "Sombre"
        case .light: return "Clair"
        }
    }

    /// `nil` = suit le réglage iPhone.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    func resolved(with system: ColorScheme) -> AppAppearance {
        switch self {
        case .system: return system == .dark ? .dark : .light
        case .dark: return .dark
        case .light: return .light
        }
    }
}
