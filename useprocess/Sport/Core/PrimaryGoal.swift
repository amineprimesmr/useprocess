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
    var title: String {
        switch self {
        case .improveSleep: return "Mieux dormir pour dégonfler"
        case .increaseRecovery: return "Réduire cernes et fatigue"
        case .boostPerformance: return "Activer drainage et définition"
        case .optimizeEnergy: return "Limiter le cortisol facial"
        case .manageWeight: return "Dégonfler mon visage"
        case .reduceStress: return "Réduire rétention et inflammation"
        case .improveFitness: return "Affiner mâchoire et ovale"
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

    var description: String {
        switch self {
        case .improveSleep: return "Améliorer sommeil pour un visage moins gonflé"
        case .increaseRecovery: return "Mieux récupérer pour réduire cernes et fatigue visible"
        case .boostPerformance: return "Bouger pour activer drainage et définition faciale"
        case .optimizeEnergy: return "Stabiliser l’énergie pour limiter le cortisol facial"
        case .manageWeight: return "Réduire gonflement, rétention d’eau et visage marqué"
        case .reduceStress: return "Baisser inflammation, sel et tension qui font gonfler"
        case .improveFitness: return "Retrouver une mâchoire et un ovale plus nets"
        }
    }
}
