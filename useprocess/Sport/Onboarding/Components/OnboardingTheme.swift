import SwiftUI
import UIKit

/// Couleurs sémantiques onboarding — s'adaptent au mode clair / sombre.
enum OnboardingTheme {
    static var screenBackground: Color { Color(.systemBackground) }
    static var primaryText: Color { Color.primary }
    static var secondaryText: Color { Color.secondary }

    /// Texte narratif (machine à écrire, titres secondaires).
    static var narrativeText: Color { adaptiveLabelOpacity(dark: 0.92, light: 0.95) }

    /// Corps de texte, descriptions.
    static var bodyText: Color { adaptiveLabelOpacity(dark: 0.78, light: 0.88) }

    /// Statistiques, légendes.
    static var footnoteText: Color { adaptiveLabelOpacity(dark: 0.68, light: 0.80) }

    /// Placeholders, hints discrets.
    static var mutedText: Color { adaptiveLabelOpacity(dark: 0.52, light: 0.68) }

    /// Boutons glass / actions principales.
    static var actionButtonText: Color { Color.primary }
    static var progressTrack: Color { Color.primary.opacity(0.15) }
    static var progressFill: Color { Color.primary }

    /// Barre d'analyse (chat + création programme) — visible en clair et sombre.
    static var analysisProgressTrack: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.20, green: 0.16, blue: 0.30, alpha: 1)
                : UIColor(red: 0.94, green: 0.90, blue: 0.99, alpha: 1)
        })
    }
    static var analysisProgressBorder: Color {
        Color(UIColor { traits in
            UIColor(red: 0.72, green: 0.58, blue: 0.92, alpha: traits.userInterfaceStyle == .dark ? 0.55 : 0.45)
        })
    }
    static var analysisProgressFillGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.82, green: 0.70, blue: 0.98),
                Color(red: 0.68, green: 0.48, blue: 0.88),
                Color(red: 0.58, green: 0.36, blue: 0.82)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    static var accentHighlight: Color { Color(red: 0.655, green: 0.769, blue: 0.949) }
    static var titleShadow: Color { Color.primary.opacity(0.12) }

    static var subtleFill: Color { Color.primary.opacity(0.06) }
    static var mutedFill: Color { Color.primary.opacity(0.12) }
    static var softFill: Color { Color.primary.opacity(0.2) }
    static var borderStroke: Color { Color.primary.opacity(0.12) }
    static var softBorder: Color { Color.primary.opacity(0.3) }
    static var graphGrid: Color { Color.primary.opacity(0.1) }
    static var graphTooltip: Color { Color.primary.opacity(0.08) }

    static var cardBackground: Color { Color(.secondarySystemGroupedBackground) }
    static var cardBorder: Color { Color(.separator).opacity(0.35) }

    /// Scan caméra, vidéo plein écran — reste sombre volontairement.
    static var immersiveBackground: Color { Color.black }

    static func filledButtonText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }

    static func filledButtonBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    static func imageScrimGradient(for colorScheme: ColorScheme) -> [Color] {
        let base: Color = colorScheme == .dark ? .black : .white
        return [
            base.opacity(colorScheme == .dark ? 0.3 : 0.15),
            base.opacity(colorScheme == .dark ? 0.6 : 0.45),
            base.opacity(colorScheme == .dark ? 0.8 : 0.7)
        ]
    }

    static func wheelFadeGradient(from colorScheme: ColorScheme, reversed: Bool) -> [Color] {
        let bg = Color(.systemBackground)
        if reversed {
            return [bg.opacity(0), bg]
        }
        return [bg, bg.opacity(0)]
    }

    static func segmentTrack(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 18 / 255, green: 18 / 255, blue: 20 / 255)
            : Color(.systemGray5)
    }

    static func segmentSelectedFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 35 / 255, green: 35 / 255, blue: 37 / 255)
            : Color(.systemBackground)
    }

    static func segmentTrackShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black.opacity(0.6) : .black.opacity(0.08)
    }

    static func segmentSelectedShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black.opacity(0.4) : .black.opacity(0.1)
    }

    static func tickActiveTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    static func tickInactiveTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.35) : .black.opacity(0.22)
    }

    static func valueGlowColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    private static func adaptiveLabelOpacity(dark: CGFloat, light: CGFloat) -> Color {
        Color(UIColor { traits in
            UIColor.label.withAlphaComponent(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}
