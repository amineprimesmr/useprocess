//
//  PrimaryGoal.swift
//  Process
//

import Foundation

enum PrimaryGoal: String, Codable, CaseIterable {
    case improveSleep = "Améliorer la qualité de mon sommeil"
    case increaseRecovery = "Optimiser ma récupération"
    case boostPerformance = "Booster ma capacité de cardio"
    case optimizeEnergy = "Optimiser mon énergie"
    case manageWeight = "Perdre / prendre du poids"
    case reduceStress = "Avoir une meilleure nutrition"
    case improveFitness = "Meilleure condition physique"

    var icon: String {
        switch self {
        case .improveSleep: return "moon.fill"
        case .increaseRecovery: return "heart.fill"
        case .boostPerformance: return "figure.run"
        case .optimizeEnergy: return "bolt.fill"
        case .manageWeight: return "scalemass.fill"
        case .reduceStress: return "leaf.fill"
        case .improveFitness: return "figure.walk"
        }
    }

    var description: String {
        switch self {
        case .improveSleep: return "Améliorer la qualité et la durée de ton sommeil"
        case .increaseRecovery: return "Optimiser ta récupération entre les entraînements"
        case .boostPerformance: return "Progresser dans ton sport et battre tes records"
        case .optimizeEnergy: return "Augmenter ton niveau d'énergie au quotidien"
        case .manageWeight: return "Perdre, maintenir ou prendre du poids"
        case .reduceStress: return "Gérer et réduire ton niveau de stress"
        case .improveFitness: return "Améliorer ta condition physique générale"
        }
    }
}
