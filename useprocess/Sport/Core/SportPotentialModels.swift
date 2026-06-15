//
//  SportPotentialModels.swift
//  Process
//
//  Modèles pour le système de potentiel sportif
//  Détermine le niveau actuel et les objectifs réalisables
//

import Foundation

// MARK: - Sport Potential Level

/// Niveau de potentiel sportif avec nom et objectif réalisable
struct SportPotentialLevel: Codable, Identifiable {
    let id: String
    let name: String                    // Ex: "Débutant", "Intermédiaire", "Avancé"
    let level: Int                      // 1-10 (1 = débutant, 10 = élite)
    let achievableGoal: String          // Ex: "Prêt pour un 5K", "Prêt pour un semi-marathon"
    let description: String             // Description du niveau
    let icon: String                    // Icône SF Symbol
    let color: String                   // Couleur du niveau

    init(name: String, level: Int, achievableGoal: String, description: String, icon: String, color: String) {
        self.id = UUID().uuidString
        self.name = name
        self.level = level
        self.achievableGoal = achievableGoal
        self.description = description
        self.icon = icon
        self.color = color
    }
}

// MARK: - Sport Potential Calculator

/// Calcule le potentiel sportif actuel de l'utilisateur
class SportPotentialCalculator {

    /// Calcule le niveau de potentiel basé sur les données
    static func calculatePotential(
        sport: SportDetail,
        baselines: FinalBaselines,
        vo2Max: Double?,
        recentStrain: [Double],
        recoveryScore: Double
    ) -> SportPotentialLevel {

        // Adapter selon le sport
        switch sport.sportCategory.lowercased() {
        case "cardio", "individual":
            return calculateRunningPotential(
                baselines: baselines,
                vo2Max: vo2Max,
                recentStrain: recentStrain,
                recoveryScore: recoveryScore
            )
        case "strength":
            return calculateStrengthPotential(
                baselines: baselines,
                recentStrain: recentStrain,
                recoveryScore: recoveryScore
            )
        case "combat":
            return calculateCombatPotential(
                baselines: baselines,
                recentStrain: recentStrain,
                recoveryScore: recoveryScore
            )
        default:
            return calculateGenericPotential(
                baselines: baselines,
                recentStrain: recentStrain,
                recoveryScore: recoveryScore
            )
        }
    }

    // MARK: - Running Potential (Course à pied)

    private static func calculateRunningPotential(
        baselines: FinalBaselines,
        vo2Max: Double?,
        recentStrain: [Double],
        recoveryScore: Double
    ) -> SportPotentialLevel {

        // Score composite basé sur plusieurs facteurs
        var score: Double = 0.0

        // 1. VO2 Max (0-40 points)
        if let vo2 = vo2Max {
            if vo2 >= 60 { score += 40 } else if vo2 >= 55 { score += 35 } else if vo2 >= 50 { score += 30 } else if vo2 >= 45 { score += 25 } else if vo2 >= 40 { score += 20 } else if vo2 >= 35 { score += 15 } else { score += 10 }
        } else {
            // Estimation basée sur effort capacity
            if baselines.effortCapacity >= 18 { score += 35 } else if baselines.effortCapacity >= 15 { score += 30 } else if baselines.effortCapacity >= 12 { score += 25 } else if baselines.effortCapacity >= 10 { score += 20 } else if baselines.effortCapacity >= 8 { score += 15 } else { score += 10 }
        }

        // 2. Effort Capacity (0-30 points)
        if baselines.effortCapacity >= 18 { score += 30 } else if baselines.effortCapacity >= 15 { score += 25 } else if baselines.effortCapacity >= 12 { score += 20 } else if baselines.effortCapacity >= 10 { score += 15 } else if baselines.effortCapacity >= 8 { score += 10 } else { score += 5 }

        // 3. Recovery Speed (0-20 points)
        if baselines.recoverySpeed <= 1 { score += 20 } else if baselines.recoverySpeed <= 2 { score += 15 } else if baselines.recoverySpeed <= 3 { score += 10 } else { score += 5 }

        // 4. HRV Baseline (0-10 points)
        if baselines.hrv >= 70 { score += 10 } else if baselines.hrv >= 60 { score += 8 } else if baselines.hrv >= 50 { score += 6 } else { score += 4 }

        // Déterminer le niveau
        if score >= 85 {
            return SportPotentialLevel(
                name: "Élite",
                level: 10,
                achievableGoal: "Prêt pour un ultra-marathon",
                description: "Niveau exceptionnel. Tu peux viser des distances extrêmes et des performances de haut niveau.",
                icon: "star.fill",
                color: "purple"
            )
        } else if score >= 75 {
            return SportPotentialLevel(
                name: "Expert",
                level: 8,
                achievableGoal: "Prêt pour un marathon",
                description: "Niveau très avancé. Tu as la capacité physique et mentale pour un marathon complet.",
                icon: "flame.fill",
                color: "red"
            )
        } else if score >= 65 {
            return SportPotentialLevel(
                name: "Avancé",
                level: 6,
                achievableGoal: "Prêt pour un semi-marathon",
                description: "Niveau solide. Tu peux viser un semi-marathon avec une préparation adaptée.",
                icon: "bolt.fill",
                color: "orange"
            )
        } else if score >= 50 {
            return SportPotentialLevel(
                name: "Intermédiaire",
                level: 4,
                achievableGoal: "Prêt pour un 10K",
                description: "Niveau intermédiaire. Tu as les bases pour viser un 10 kilomètres.",
                icon: "figure.run",
                color: "yellow"
            )
        } else if score >= 35 {
            return SportPotentialLevel(
                name: "Débutant Avancé",
                level: 3,
                achievableGoal: "Prêt pour un 5K",
                description: "Bon niveau débutant. Tu peux viser un 5 kilomètres avec confiance.",
                icon: "figure.walk",
                color: "green"
            )
        } else {
            return SportPotentialLevel(
                name: "Débutant",
                level: 2,
                achievableGoal: "Prêt pour commencer",
                description: "Niveau débutant. Continue à t'entraîner régulièrement pour progresser.",
                icon: "figure.walk.circle",
                color: "blue"
            )
        }
    }

    // MARK: - Strength Potential (Musculation)

    private static func calculateStrengthPotential(
        baselines: FinalBaselines,
        recentStrain: [Double],
        recoveryScore: Double
    ) -> SportPotentialLevel {

        var score: Double = 0.0

        // Effort Capacity
        if baselines.effortCapacity >= 15 { score += 40 } else if baselines.effortCapacity >= 12 { score += 30 } else if baselines.effortCapacity >= 10 { score += 20 } else { score += 10 }

        // Recovery Speed
        if baselines.recoverySpeed <= 2 { score += 30 } else if baselines.recoverySpeed <= 3 { score += 20 } else { score += 10 }

        // Stress Tolerance
        if baselines.stressTolerance >= 70 { score += 30 } else if baselines.stressTolerance >= 50 { score += 20 } else { score += 10 }

        if score >= 80 {
            return SportPotentialLevel(
                name: "Expert",
                level: 8,
                achievableGoal: "Prêt pour compétition",
                description: "Niveau très avancé. Tu peux viser des compétitions de force.",
                icon: "dumbbell.fill",
                color: "red"
            )
        } else if score >= 65 {
            return SportPotentialLevel(
                name: "Avancé",
                level: 6,
                achievableGoal: "Prêt pour charges lourdes",
                description: "Niveau solide. Tu peux travailler avec des charges importantes.",
                icon: "figure.strengthtraining.traditional",
                color: "orange"
            )
        } else if score >= 50 {
            return SportPotentialLevel(
                name: "Intermédiaire",
                level: 4,
                achievableGoal: "Prêt pour progression",
                description: "Niveau intermédiaire. Tu peux augmenter progressivement les charges.",
                icon: "figure.strengthtraining.functional",
                color: "yellow"
            )
        } else {
            return SportPotentialLevel(
                name: "Débutant",
                level: 2,
                achievableGoal: "Prêt pour les bases",
                description: "Niveau débutant. Continue à apprendre les mouvements fondamentaux.",
                icon: "figure.flexibility",
                color: "green"
            )
        }
    }

    // MARK: - Combat Potential

    private static func calculateCombatPotential(
        baselines: FinalBaselines,
        recentStrain: [Double],
        recoveryScore: Double
    ) -> SportPotentialLevel {

        var score: Double = 0.0

        // Effort Capacity + Recovery
        if baselines.effortCapacity >= 15 && baselines.recoverySpeed <= 2 {
            score = 80
        } else if baselines.effortCapacity >= 12 {
            score = 60
        } else if baselines.effortCapacity >= 10 {
            score = 45
        } else {
            score = 30
        }

        if score >= 75 {
            return SportPotentialLevel(
                name: "Expert",
                level: 8,
                achievableGoal: "Prêt pour compétition",
                description: "Niveau très avancé. Tu peux viser des compétitions.",
                icon: "figure.boxing",
                color: "red"
            )
        } else if score >= 55 {
            return SportPotentialLevel(
                name: "Avancé",
                level: 6,
                achievableGoal: "Prêt pour sparring",
                description: "Niveau solide. Tu peux faire du sparring régulier.",
                icon: "figure.martial.arts",
                color: "orange"
            )
        } else if score >= 40 {
            return SportPotentialLevel(
                name: "Intermédiaire",
                level: 4,
                achievableGoal: "Prêt pour intensité",
                description: "Niveau intermédiaire. Tu peux augmenter l'intensité.",
                icon: "figure.combat",
                color: "yellow"
            )
        } else {
            return SportPotentialLevel(
                name: "Débutant",
                level: 2,
                achievableGoal: "Prêt pour les bases",
                description: "Niveau débutant. Continue à apprendre les techniques.",
                icon: "figure.mind.and.body",
                color: "green"
            )
        }
    }

    // MARK: - Generic Potential (Autres sports)

    private static func calculateGenericPotential(
        baselines: FinalBaselines,
        recentStrain: [Double],
        recoveryScore: Double
    ) -> SportPotentialLevel {

        var score: Double = 0.0

        // Basé sur effort capacity principalement
        if baselines.effortCapacity >= 15 { score = 70 } else if baselines.effortCapacity >= 12 { score = 55 } else if baselines.effortCapacity >= 10 { score = 40 } else if baselines.effortCapacity >= 8 { score = 30 } else { score = 20 }

        if score >= 65 {
            return SportPotentialLevel(
                name: "Avancé",
                level: 6,
                achievableGoal: "Prêt pour performance",
                description: "Niveau solide. Tu peux viser des performances élevées.",
                icon: "star.fill",
                color: "orange"
            )
        } else if score >= 50 {
            return SportPotentialLevel(
                name: "Intermédiaire",
                level: 4,
                achievableGoal: "Prêt pour progression",
                description: "Niveau intermédiaire. Tu peux continuer à progresser.",
                icon: "arrow.up.circle.fill",
                color: "yellow"
            )
        } else {
            return SportPotentialLevel(
                name: "Débutant",
                level: 2,
                achievableGoal: "Prêt pour les bases",
                description: "Niveau débutant. Continue à t'entraîner régulièrement.",
                icon: "figure.walk",
                color: "green"
            )
        }
}
}
