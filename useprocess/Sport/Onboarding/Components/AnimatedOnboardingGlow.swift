//
//  AnimatedOnboardingGlow.swift
//  Process
//
//  Lueur bleutée ancrée en bas des premières pages d'onboarding
//

import SwiftUI

struct AnimatedOnboardingGlow: View {
    @Environment(\.colorScheme) private var colorScheme

    let currentStep: Int
    let visitedStepsCount: Int // Nombre d'étapes réellement visitées
    let totalStepsForFlow: Int // Total d'étapes pour le flux actuel

    /// Ancrage bas — la lueur remonte depuis le bord inférieur, pas le centre écran.
    private static let bottomGlowCenter = UnitPoint(x: 0.5, y: 1.16)
    private static let bottomGlowRadius: CGFloat = 560

    @State private var animatedRadius: CGFloat = bottomGlowRadius

    // ✅ Calculer le rayon cible
    private func calculateTargetRadius(for step: Int) -> CGFloat {
        let baseRadius: CGFloat = Self.bottomGlowRadius
        // Variation subtile pour un effet organique
        let variation = sin(Double(step) * 0.2) * 20
        return baseRadius + CGFloat(variation)
    }

    var body: some View {
        if iOS26Stability.isEnabled {
            RadialGradient(
                colors: lightModeGlowColors,
                center: Self.bottomGlowCenter,
                startRadius: 0,
                endRadius: Self.bottomGlowRadius
            )
            .allowsHitTesting(false)
        } else {
            animatedGlowBody
        }
    }

    private var lightModeGlowColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.3, green: 0.45, blue: 0.95).opacity(0.12),
                Color(red: 0.2, green: 0.35, blue: 0.85).opacity(0.06),
                Color.clear
            ]
        }
        return [
            Color(red: 0.35, green: 0.52, blue: 0.98).opacity(0.05),
            Color(red: 0.25, green: 0.42, blue: 0.92).opacity(0.025),
            Color.clear
        ]
    }

    private var glowOpacityScale: Double {
        colorScheme == .dark ? 1.0 : 0.45
    }

    @ViewBuilder
    private var animatedGlowBody: some View {
        // ✅ Calculer la progression dans l'onboarding (0.0 = début, 1.0 = fin)
        let rawProgress = min(1.0, max(0.0, Double(visitedStepsCount) / Double(max(totalStepsForFlow, 1))))

        // ✅ ACCÉLÉRER ÉNORMÉMENT la transition vers le bleu pétant
        // Utiliser une courbe beaucoup plus agressive pour que la lueur soit bleue pétante dès ~30% du parcours
        // À 30% de progression → ~95% de bleu pétant (presque complètement bleu)
        // À 40% de progression → 100% de bleu pétant (complètement bleu)
        let progress = pow(rawProgress, 0.3) // Racine cubique pour accélérer ENCORE PLUS la transition

        // ✅ Opacité légèrement augmentée pour les premières pages (0-4: genre, âge, taille/poids, prénom)
        let isEarlyStep: Bool = {
            guard let step = OnboardingStep(rawValue: currentStep) else { return false }
            switch step {
            case .genderSelection, .ageSelection, .height, .weight, .firstNameInput:
                return true
            default:
                return false
            }
        }()

        let shouldIncreaseOpacity = isEarlyStep

        // ✅ Opacités BEAUCOUP réduites pour rendre la lueur moins visible
        let centerOpacity = (shouldIncreaseOpacity ? 0.15 : 0.10) * glowOpacityScale
        let middleOpacity = (shouldIncreaseOpacity ? 0.12 : 0.08) * glowOpacityScale
        let outerOpacity = (shouldIncreaseOpacity ? 0.08 : 0.05) * glowOpacityScale
        let edgeOpacity = (shouldIncreaseOpacity ? 0.05 : 0.03) * glowOpacityScale

        // ✅ Interpoler les couleurs du BLEU (déjà bleu au début) vers le bleu PÉTANT en fonction de la progression
        // Bleu (début): RGB(0.3, 0.45, 0.95) -> Bleu PÉTANT (fin): RGB(0.2, 0.5, 1.0)
        // ✅ Couleurs de départ déjà bleues au lieu de violet
        let centerColor = interpolateColor(
            from: (r: 0.3, g: 0.45, b: 0.95), // ✅ Déjà bleu au début
            to: (r: 0.2, g: 0.5, b: 1.0), // ✅ Bleu pétant : bleu très vif et saturé
            progress: progress
        )
        let middleColor = interpolateColor(
            from: (r: 0.25, g: 0.4, b: 0.9), // ✅ Déjà bleu au début
            to: (r: 0.15, g: 0.4, b: 0.95), // ✅ Bleu pétant : bleu très vif
            progress: progress
        )
        let outerColor = interpolateColor(
            from: (r: 0.2, g: 0.35, b: 0.85), // ✅ Déjà bleu au début
            to: (r: 0.1, g: 0.35, b: 0.9), // ✅ Bleu pétant : bleu vif
            progress: progress
        )
        let edgeColor = interpolateColor(
            from: (r: 0.15, g: 0.3, b: 0.8), // ✅ Déjà bleu au début
            to: (r: 0.05, g: 0.25, b: 0.85), // ✅ Bleu pétant : bleu foncé vif
            progress: progress
        )

        RadialGradient(
            colors: [
                // ✅ Centre - couleur interpolée selon la progression
                Color(red: centerColor.r, green: centerColor.g, blue: centerColor.b).opacity(centerOpacity),
                // Milieu - couleur interpolée
                Color(red: middleColor.r, green: middleColor.g, blue: middleColor.b).opacity(middleOpacity),
                // Extérieur - couleur interpolée
                Color(red: outerColor.r, green: outerColor.g, blue: outerColor.b).opacity(outerOpacity),
                // Bords - couleur interpolée
                Color(red: edgeColor.r, green: edgeColor.g, blue: edgeColor.b).opacity(edgeOpacity),
                // Bords extérieurs - presque transparent
                Color.clear
            ],
            center: Self.bottomGlowCenter,
            startRadius: 0,
            endRadius: animatedRadius
        )
        .onChange(of: visitedStepsCount) { _, newValue in
            updateGlowRadius(for: newValue)
        }
        .onAppear {
            updateGlowRadius(for: visitedStepsCount)
        }
    }

    private func updateGlowRadius(for progressCount: Int) {
        let targetRadius = calculateTargetRadius(for: progressCount)

        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            animatedRadius = targetRadius
        }
    }

    // ✅ Fonction pour interpoler les couleurs du violet vers le bleu PÉTANT
    private func interpolateColor(
        from: (r: Double, g: Double, b: Double),
        to: (r: Double, g: Double, b: Double),
        progress: Double
    ) -> (r: Double, g: Double, b: Double) {
        // ✅ Utiliser une courbe ULTRA agressive pour une transition TRÈS rapide vers le bleu pétant
        // Quartic ease-in (progress⁴) pour une transition ENCORE PLUS rapide
        // Cela fait que la lueur devient bleue pétante ÉNORMÉMENT plus rapidement
        let easedProgress = progress * progress * progress * progress

        return (
            r: from.r + (to.r - from.r) * easedProgress,
            g: from.g + (to.g - from.g) * easedProgress,
            b: from.b + (to.b - from.b) * easedProgress
        )
    }
}
