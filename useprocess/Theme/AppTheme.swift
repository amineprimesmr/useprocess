import SwiftUI

/// Tokens visuels dérivés du mode clair / sombre.
struct AppTheme {
    let appearance: AppAppearance

    var background: Color {
        appearance == .light ? .white : .black
    }

    var primaryText: Color {
        appearance == .light ? .black : Color(white: 0.98)
    }

    var secondaryText: Color {
        appearance == .light ? .black.opacity(0.55) : .white.opacity(0.65)
    }

    var glow: Color {
        appearance == .light
            ? Color(red: 0.35, green: 0.55, blue: 0.95)
            : Color(red: 0.2, green: 0.4, blue: 0.7)
    }

    var progressTrack: Color {
        appearance == .light ? .black.opacity(0.08) : .white.opacity(0.2)
    }

    var progressFill: Color {
        appearance == .light ? .black : .white
    }

    var cardStroke: Color {
        appearance == .light ? .black.opacity(0.12) : .white.opacity(0.28)
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme(appearance: .dark)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
