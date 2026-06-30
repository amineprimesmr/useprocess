//
//  OnboardingTitleView.swift
//  Process
//
//  Composant standardisé pour les titres d'onboarding
//  Position ABSOLUE fixe : 100pt depuis le haut de l'écran (juste sous le bouton retour)
//

import SwiftUI

struct OnboardingTitleView: View {
    let lines: [String]
    let opacity: Double

    /// Initialiser avec une seule ligne (fixe)
    init(_ title: String, opacity: Double = 1.0) {
        self.lines = [title]
        self.opacity = opacity
    }

    /// Initialiser avec plusieurs lignes (fixes)
    init(_ line1: String, _ line2: String, opacity: Double = 1.0) {
        self.lines = [line1, line2]
        self.opacity = opacity
    }

    /// Initialiser avec 3 lignes (fixes)
    init(_ line1: String, _ line2: String, _ line3: String, opacity: Double = 1.0) {
        self.lines = [line1, line2, line3]
        self.opacity = opacity
    }

    /// Initialiser avec titre et sous-titres (pour compatibilité avec l'overlay)
    init(_ title: String, subtitle: String? = nil, subtitle2: String? = nil, opacity: Double = 1.0) {
        var allLines = [title]
        if let subtitle = subtitle {
            allLines.append(subtitle)
        }
        if let subtitle2 = subtitle2 {
            allLines.append(subtitle2)
        }
        self.lines = allLines
        self.opacity = opacity
    }

    /// Initialiser avec des lignes dynamiques (pour titres variables)
    init(lines: [String], opacity: Double = 1.0) {
        self.lines = lines
        self.opacity = opacity
    }

    private var displayLines: [String] {
        OnboardingCopy.titleLines(from: lines)
    }

    var body: some View {
        // ✅ Combiner toutes les lignes en un seul texte pour permettre le retour à la ligne naturel
        Text(displayLines.joined(separator: " "))
                    .font(.system(size: 26, weight: .bold, design: .default))
            .foregroundStyle(OnboardingTheme.primaryText)
                    .shadow(color: OnboardingTheme.titleShadow, radius: 2, x: 1, y: 1)
                    .opacity(opacity)
            .lineLimit(3) // Maximum 3 lignes pour éviter les titres trop longs
                    .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: false) // Permet le retour à la ligne naturel
        .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 40)
            .padding(.trailing, 20)
    }

    /// Overlay titre fixe — laisse passer les taps (toggle, champs, boutons).
    func onboardingTitleOverlay() -> some View {
        VStack {
            self
                .padding(.top, OnboardingConstants.titleTopPadding)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    /// Vue avec positionnement absolu depuis le haut de l'écran (à utiliser en overlay)
    func positioned() -> some View {
        GeometryReader { geometry in
            // ✅ Combiner toutes les lignes en un seul texte pour permettre le retour à la ligne naturel
            Text(displayLines.joined(separator: " "))
                        .font(.system(size: 26, weight: .bold, design: .default))
                .foregroundStyle(OnboardingTheme.primaryText)
                        .shadow(color: OnboardingTheme.titleShadow, radius: 2, x: 1, y: 1)
                        .opacity(opacity)
                .lineLimit(3) // Maximum 3 lignes pour éviter les titres trop longs
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: false) // Permet le retour à la ligne naturel
            .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 40)
                .padding(.trailing, 20)
            .frame(width: geometry.size.width)
            .position(
                x: geometry.size.width / 2,
                y: OnboardingConstants.titleTopPaddingFromScreenTop + 26
            )
        }
        .frame(height: 150, alignment: .top)
    }
}
