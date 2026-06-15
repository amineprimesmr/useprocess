import SwiftUI

/// État global de l'application.
@MainActor
@Observable
final class AppSession {
    static let shared = AppSession()

    var hasCompletedOnboarding: Bool
    var appearance: AppAppearance

    private init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.completed)
        let rawAppearance = UserDefaults.standard.string(forKey: Keys.appearance) ?? AppAppearance.dark.rawValue
        appearance = AppAppearance(rawValue: rawAppearance) ?? .dark
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Keys.completed)
        AuthenticationManager.shared.completeOnboarding()
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: Keys.completed)
        AuthenticationManager.shared.resetSession()
        OnboardingProgressService.shared.resetProgress()
    }

    func setAppearance(_ mode: AppAppearance) {
        appearance = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Keys.appearance)
    }

    private enum Keys {
        private static let prefix = (Bundle.main.bundleIdentifier ?? "useprocess") + "."

        static var completed: String { prefix + "onboarding.completed" }
        static var appearance: String { prefix + "appearance" }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dark: return "Sombre"
        case .light: return "Clair"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .dark: return .dark
        case .light: return .light
        }
    }
}
