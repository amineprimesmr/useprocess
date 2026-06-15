import SwiftUI

/// État global de l'application.
@MainActor
@Observable
final class AppSession {
    static let shared = AppSession()

    var hasCompletedOnboarding: Bool
    var hasCompletedWelcomePlanChat: Bool
    var appearance: AppAppearance

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
        hasCompletedOnboarding = false
        hasCompletedWelcomePlanChat = false
        UserDefaults.standard.set(false, forKey: onboardingStorageKey)
        UserDefaults.standard.set(false, forKey: welcomePlanChatStorageKey)
        AuthenticationManager.shared.resetSession()
        OnboardingProgressService.shared.resetProgress()
        WelcomePlanStore.shared.resetForCurrentUser()
    }

    func reloadForCurrentUser() {
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
        UserScopedStorage.key("onboarding.completed", userId: UserScopedStorage.currentUserId())
    }

    private var welcomePlanChatStorageKey: String {
        UserScopedStorage.key("welcome.plan.chat.completed", userId: UserScopedStorage.currentUserId())
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
