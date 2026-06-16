//
//  OnboardingEstimationOpalTheme.swift
//  useprocess
//

import SwiftUI

enum OnboardingEstimationOpalTheme {
    static let accent = Color(red: 0.47, green: 0.98, blue: 0.74)
    static let accentSoft = Color(red: 0.47, green: 0.98, blue: 0.74).opacity(0.35)
    static let regularLine = Color.white.opacity(0.22)
    static let regularPill = Color.white.opacity(0.14)
    static let gridLine = Color.white.opacity(0.06)
    static let star = Color(red: 1.0, green: 0.82, blue: 0.2)

    struct Benefit: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
    }

    static let benefits: [Benefit] = [
        .init(
            icon: "shield.lefthalf.filled",
            title: "Atteins ton objectif.",
            subtitle: "Un plan calibré sur ton corps et ton rythme."
        ),
        .init(
            icon: "calendar",
            title: "Prends le contrôle de ta progression.",
            subtitle: "Chaque séance et chaque repas comptent."
        ),
        .init(
            icon: "person.2.fill",
            title: "Reste constant.",
            subtitle: "Process t'accompagne au quotidien."
        )
    ]

    static func headlineHighlight(for context: OnboardingEstimationContext) -> String {
        if context.phase == .optimized {
            return context.hasWeightGoal ? "3 semaines" : "+ 40 %"
        }
        return context.hasWeightGoal ? "2 semaines" : "+ 30 %"
    }

    static func headlinePrefix(for context: OnboardingEstimationContext) -> String {
        if context.hasWeightGoal {
            return "Démarre ton essai gratuit et atteins ton objectif "
        }
        return "Démarre ton essai gratuit et débloque "
    }

    static func headlineSuffix(for context: OnboardingEstimationContext) -> String {
        context.hasWeightGoal ? " plus tôt" : " de potentiel"
    }

    static func chartEndLabel(for context: OnboardingEstimationContext) -> String {
        if context.hasWeightGoal {
            return context.phase == .optimized
                ? "Objectif atteint plus vite"
                : "Progression après 2 semaines"
        }
        return "Potentiel débloqué"
    }
}
