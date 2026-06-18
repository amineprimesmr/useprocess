import SwiftUI

/// Tokens visuels dérivés du mode clair / sombre (résolu depuis système ou préférence).
struct AppTheme {
    let resolved: AppAppearance

    init(appearance: AppAppearance, colorScheme: ColorScheme) {
        resolved = appearance.resolved(with: colorScheme)
    }

    init(appearance: AppAppearance) {
        resolved = appearance == .light ? .light : .dark
    }

    var isDark: Bool { resolved == .dark }

    var background: Color {
        resolved == .light ? Color(.systemBackground) : Color(.systemBackground)
    }

    var primaryText: Color {
        Color(.label)
    }

    var secondaryText: Color {
        Color(.secondaryLabel)
    }

    var glow: Color {
        resolved == .light
            ? Color(red: 0.35, green: 0.55, blue: 0.95)
            : Color(red: 0.2, green: 0.4, blue: 0.7)
    }

    var progressTrack: Color {
        resolved == .light ? Color(.label).opacity(0.12) : Color(.label).opacity(0.22)
    }

    var progressFill: Color {
        Color(.label)
    }

    var cardStroke: Color {
        resolved == .light ? Color(.separator).opacity(0.35) : Color(.separator).opacity(0.5)
    }

    var cardBackground: Color {
        primaryText.opacity(isDark ? 0.08 : 0.06)
    }

    var cardBackgroundStrong: Color {
        primaryText.opacity(isDark ? 0.12 : 0.08)
    }

    var coachUserBubble: Color {
        resolved == .light
            ? Color(red: 0.949, green: 0.949, blue: 0.949)
            : Color(.systemGray6)
    }

    var coachAssistantBubble: Color {
        resolved == .light ? Color(.systemGray6) : Color.white.opacity(0.1)
    }

    /// Accent bleu clair (titres onboarding, surlignage).
    var onboardingAccent: Color {
        Color(red: 0.655, green: 0.769, blue: 0.949)
    }

    var inverseBackground: Color {
        isDark ? .white : .black
    }

    var inverseText: Color {
        isDark ? .black : .white
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme(appearance: .system, colorScheme: .dark)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
