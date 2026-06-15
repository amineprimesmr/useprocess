import SwiftUI

/// État global de l'application.
@MainActor
@Observable
final class AppSession {
    static let shared = AppSession()

    var hasCompletedOnboarding: Bool
    var appearance: AppAppearance

    private init() {
        let uid = UserScopedStorage.currentUserId()
        hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: UserScopedStorage.key("onboarding.completed", userId: uid)
        )
        let rawAppearance = UserDefaults.standard.string(forKey: Keys.appearance) ?? AppAppearance.system.rawValue
        appearance = AppAppearance(rawValue: rawAppearance) ?? .system
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingStorageKey)
        AuthenticationManager.shared.completeOnboarding()
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: onboardingStorageKey)
        AuthenticationManager.shared.resetSession()
        OnboardingProgressService.shared.resetProgress()
    }

    func reloadForCurrentUser() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingStorageKey)
    }

    func setAppearance(_ mode: AppAppearance) {
        appearance = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Keys.appearance)
    }

    private var onboardingStorageKey: String {
        UserScopedStorage.key("onboarding.completed", userId: UserScopedStorage.currentUserId())
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
