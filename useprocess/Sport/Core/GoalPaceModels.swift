//
//  GoalPaceModels.swift
//  Process
//
//  Modèles pour la vitesse d'atteinte d'objectif (psychologique)
//

import Foundation

/// Vitesse à laquelle l'utilisateur souhaite atteindre son objectif
enum GoalPace: String, Codable, CaseIterable, Identifiable {
    case asFastAsPossible = "Le plus vite possible"
    case aggressive = "Rapidement"
    case moderate = "Progressivement"
    case relaxed = "À mon rythme"
    case noRush = "Sans pression"

    var id: String { rawValue }

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .asFastAsPossible: return AppCopy.t("Le plus vite possible", en: "As fast as possible")
        case .aggressive: return AppCopy.t("Rapidement", en: "Quickly")
        case .moderate: return AppCopy.t("Progressivement", en: "Gradually")
        case .relaxed: return AppCopy.t("À mon rythme", en: "At my own pace")
        case .noRush: return AppCopy.t("Sans pression", en: "No pressure")
        }
    }

    var icon: String {
        switch self {
        case .asFastAsPossible:
            return "bolt.fill"
        case .aggressive:
            return "flame.fill"
        case .moderate:
            return "chart.line.uptrend.xyaxis"
        case .relaxed:
            return "tortoise.fill"
        case .noRush:
            return "leaf.fill"
        }
    }

    @MainActor
    var description: String {
        switch self {
        case .asFastAsPossible:
            return AppCopy.t(
                "Je veux des résultats rapides, je suis prêt à m'investir à fond",
                en: "I want fast results and I'm ready to go all in"
            )
        case .aggressive:
            return AppCopy.t(
                "Je veux progresser rapidement avec un plan intensif",
                en: "I want to progress quickly with an intensive plan"
            )
        case .moderate:
            return AppCopy.t(
                "Je préfère une progression régulière et équilibrée",
                en: "I prefer steady, balanced progress"
            )
        case .relaxed:
            return AppCopy.t(
                "Je veux prendre mon temps et profiter du processus",
                en: "I want to take my time and enjoy the process"
            )
        case .noRush:
            return AppCopy.t(
                "Pas de stress, je veux juste progresser naturellement",
                en: "No stress — I just want to progress naturally"
            )
        }
    }

    var color: String {
        switch self {
        case .asFastAsPossible:
            return "red"
        case .aggressive:
            return "orange"
        case .moderate:
            return "blue"
        case .relaxed:
            return "green"
        case .noRush:
            return "mint"
        }
    }

    /// Multiplicateur pour ajuster les projections (psychologique)
    var paceMultiplier: Double {
        switch self {
        case .asFastAsPossible:
            return 0.85  // Réduit la date de 15%
        case .aggressive:
            return 0.90  // Réduit la date de 10%
        case .moderate:
            return 1.0   // Pas de changement
        case .relaxed:
            return 1.10  // Augmente la date de 10%
        case .noRush:
            return 1.15  // Augmente la date de 15%
        }
    }
}

extension GoalPace {
    /// Taux hebdomadaire (kg/semaine) pour l'estimation de poids dans l'onboarding.
    var weightEstimationWeeklyRate: Double {
        switch self {
        case .asFastAsPossible: return 1.2
        case .aggressive: return 0.7
        case .moderate: return 0.5
        case .relaxed: return 0.3
        case .noRush: return 0.2
        }
    }
}
