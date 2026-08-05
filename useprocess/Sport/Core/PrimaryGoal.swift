//
//  PrimaryGoal.swift
//  Process
//

import Foundation

/// RawValues FR conservés pour la persistance.
/// L’UI Process parle uniquement debloat visage.
enum PrimaryGoal: String, Codable, CaseIterable {
    case improveSleep = "Améliorer la qualité de mon sommeil"
    case increaseRecovery = "Optimiser ma récupération"
    case boostPerformance = "Booster ma capacité de cardio"
    case optimizeEnergy = "Optimiser mon énergie"
    case manageWeight = "Perdre / prendre du poids"
    case reduceStress = "Avoir une meilleure nutrition"
    case improveFitness = "Meilleure condition physique"

    /// Libellé produit — jamais de framing perte de poids.
    @MainActor
    var title: String {
        switch self {
        case .improveSleep: return AppCopy.t("Mieux dormir pour dégonfler", en: "Sleep better to debloat")
        case .increaseRecovery: return AppCopy.t("Réduire cernes et fatigue", en: "Reduce under-eyes & fatigue")
        case .boostPerformance: return AppCopy.t("Activer drainage et définition", en: "Activate drainage & definition")
        case .optimizeEnergy: return AppCopy.t("Limiter le cortisol facial", en: "Limit facial cortisol")
        case .manageWeight: return AppCopy.t("Dégonfler mon visage", en: "Debloat my face")
        case .reduceStress: return AppCopy.t("Réduire rétention et inflammation", en: "Reduce retention & inflammation")
        case .improveFitness: return AppCopy.t("Affiner mâchoire et ovale", en: "Refine jawline & face oval")
        }
    }

    var icon: String {
        switch self {
        case .improveSleep: return "moon.fill"
        case .increaseRecovery: return "heart.fill"
        case .boostPerformance: return "figure.run"
        case .optimizeEnergy: return "bolt.fill"
        case .manageWeight: return "drop.fill"
        case .reduceStress: return "leaf.fill"
        case .improveFitness: return "face.smiling"
        }
    }

    @MainActor
    var description: String {
        switch self {
        case .improveSleep:
            return AppCopy.t(
                "Améliorer sommeil pour un visage moins gonflé",
                en: "Improve sleep for a less puffy face"
            )
        case .increaseRecovery:
            return AppCopy.t(
                "Mieux récupérer pour réduire cernes et fatigue visible",
                en: "Recover better to reduce visible under-eyes & fatigue"
            )
        case .boostPerformance:
            return AppCopy.t(
                "Bouger pour activer drainage et définition faciale",
                en: "Move to activate drainage and facial definition"
            )
        case .optimizeEnergy:
            return AppCopy.t(
                "Stabiliser l’énergie pour limiter le cortisol facial",
                en: "Stabilize energy to limit facial cortisol"
            )
        case .manageWeight:
            return AppCopy.t(
                "Réduire gonflement, rétention d’eau et visage marqué",
                en: "Reduce puffiness, water retention, and a marked face"
            )
        case .reduceStress:
            return AppCopy.t(
                "Baisser inflammation, sel et tension qui font gonfler",
                en: "Lower inflammation, salt, and tension that cause bloating"
            )
        case .improveFitness:
            return AppCopy.t(
                "Retrouver une mâchoire et un ovale plus nets",
                en: "Get a sharper jawline and face oval"
            )
        }
    }
}
