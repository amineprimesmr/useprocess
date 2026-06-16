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

    private init() {
        let uid = UserScopedStorage.currentUserId()
        let onboardingKey = UserScopedStorage.key("onboarding.completed", userId: uid)
        let completedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
        hasCompletedOnboarding = completedOnboarding

        let welcomeKey = UserScopedStorage.key("welcome.plan.chat.completed", userId: uid)
        if completedOnboarding, UserDefaults.standard.object(forKey: welcomeKey) == nil {
            // Utilisateurs existants avant cette feature : pas de re-questionnaire.
            hasCompletedWelcomePlanChat = true
            UserDefaults.standard.set(true, forKey: welcomeKey)
        } else {
            hasCompletedWelcomePlanChat = UserDefaults.standard.bool(forKey: welcomeKey)
        }

        let rawAppearance = UserDefaults.standard.string(forKey: Keys.appearance) ?? AppAppearance.system.rawValue
        appearance = AppAppearance(rawValue: rawAppearance) ?? .system
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingStorageKey)
        AuthenticationManager.shared.completeOnboarding()
    }

    func completeWelcomePlanChat() {
        hasCompletedWelcomePlanChat = true
        UserDefaults.standard.set(true, forKey: welcomePlanChatStorageKey)
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
        AuthenticationManager.shared.hasCompletedOnboarding = false
    }

    /// Suppression complète du compte : données locales + Firebase + retour onboarding.
    func deleteAccount() async {
        isAccountWipeInProgress = true
        defer { isAccountWipeInProgress = false }

        let primaryUID = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
            ?? "local-user"

        WelcomePlanStore.shared.resetForCurrentUser()
        CoachConversationStore.resetThread()
        CoachConversationLibraryStore.shared.clearStoredData(userId: primaryUID)
        CoachMemoryStore.shared.clearForUser(userId: primaryUID)
        SocialProfileStore.shared.resetForUser(userId: primaryUID)
        BodyScanHistoryStore.shared.clearForUser(userId: primaryUID)
        FaceScanHistoryStore.shared.clearForUser(userId: primaryUID)
        OnboardingProgressService.shared.resetProgress()

        hasCompletedOnboarding = false
        hasCompletedWelcomePlanChat = false

        for uid in UserScopedStorage.likelyUserIds(primary: primaryUID) {
            UserScopedStorage.clearAllUserData(userId: uid)
        }

        UnifiedProfileService.shared.clearLocalProfile()

        await AuthenticationManager.shared.deleteRemoteUserIfNeeded()
        AuthenticationManager.shared.applyPostAccountDeletion()

        UserSessionCoordinator.shared.handleAccountDeleted()
    }

    func reloadForCurrentUser() {
        guard !isAccountWipeInProgress else { return }
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingStorageKey)
        let welcomeKey = welcomePlanChatStorageKey
        if hasCompletedOnboarding, UserDefaults.standard.object(forKey: welcomeKey) == nil {
            hasCompletedWelcomePlanChat = true
            UserDefaults.standard.set(true, forKey: welcomeKey)
        } else {
            hasCompletedWelcomePlanChat = UserDefaults.standard.bool(forKey: welcomeKey)
        }
        WelcomePlanStore.shared.reloadForCurrentUser()
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
