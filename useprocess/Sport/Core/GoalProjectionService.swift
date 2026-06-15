//
//  GoalProjectionService.swift
//  Process
//
//  Service pour calculer les projections d'objectifs et ajuster les dates
//

import Foundation

/// Service pour calculer les projections d'objectifs
class GoalProjectionService {
    static let shared = GoalProjectionService()

    // Stocker la date initiale pour l'animation progressive
    private var initialProjectedDate: Date?
    private var lastUpdateStep: String?

    private init() {}

    /// Stocke la date initiale projetée (première fois qu'on calcule)
    func storeInitialProjectedDate(_ date: Date, for step: String) {
        if initialProjectedDate == nil || lastUpdateStep != step {
            initialProjectedDate = date
            lastUpdateStep = step
        }
    }

    /// Récupère la date initiale pour l'animation
    func getInitialProjectedDate() -> Date? {
        return initialProjectedDate
    }

    /// Réinitialise la date initiale (quand on change d'objectif)
    func resetInitialDate() {
        initialProjectedDate = nil
        lastUpdateStep = nil
    }

    /// Calcule la date estimée d'atteinte de l'objectif selon les paramètres
    func calculateProjectedDate(
        primaryGoals: Set<PrimaryGoal>,
        currentWeight: Double?,
        idealWeight: Double?,
        weightGoal: WeightGoal?,
        experienceLevel: ExperienceLevel?,
        yearsOfExperience: Int,
        selectedSports: Set<String>,
        deadline: GoalDeadline?,
        trainingFrequency: String?,
        goalPace: GoalPace? = nil
    ) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        // Si deadline existe et n'est pas "noDeadline", l'utiliser comme base
        if let deadline = deadline, deadline.hasDeadline, let deadlineDate = deadline.date {
            // Ajuster selon les réponses pour rapprocher la date
            var adjustedDate = deadlineDate

            // Facteurs qui RAPPROCHENT la date (réduisent le temps nécessaire)
            var reductionDays = 0

            // 1. Expérience : plus d'expérience = progression plus rapide
            if let level = experienceLevel {
                switch level {
                case .debutant:
                    reductionDays += 0
                case .intermediaire:
                    reductionDays += 8
                case .amateur:
                    reductionDays += 15
                case .professionnel:
                    reductionDays += 25
                }
            }

            // 2. Années d'expérience : plus d'années = meilleure base
            if yearsOfExperience >= 5 {
                reductionDays += 10
            } else if yearsOfExperience >= 3 {
                reductionDays += 5
            } else if yearsOfExperience >= 1 {
                reductionDays += 2
            }

            // 3. Fréquence d'entraînement : plus fréquent = plus rapide
            if let frequency = trainingFrequency {
                switch frequency {
                case "6+":
                    reductionDays += 12
                case "3-5":
                    reductionDays += 6
                case "0-2":
                    reductionDays += 0
                default:
                    break
                }
            }

            // 4. Objectifs multiples : plus de motivation = meilleure progression
            if primaryGoals.count >= 3 {
                reductionDays += 8
            } else if primaryGoals.count == 2 {
                reductionDays += 4
            }

            // Appliquer la réduction (mais ne pas dépasser la date actuelle)
            if let reducedDate = calendar.date(byAdding: .day, value: -reductionDays, to: adjustedDate) {
                adjustedDate = max(now, reducedDate)
            }

            // ✨ NOUVEAU: Ajuster selon le rythme psychologique choisi
            if let pace = goalPace {
                let daysDifference = calendar.dateComponents([.day], from: now, to: adjustedDate).day ?? 0
                let adjustedDays = Int(Double(daysDifference) * pace.paceMultiplier)
                if let finalDate = calendar.date(byAdding: .day, value: adjustedDays, to: now) {
                    adjustedDate = finalDate
                }
            }

            return adjustedDate
        }

        // Si pas de deadline, calculer selon l'objectif principal
        if primaryGoals.contains(.manageWeight), let current = currentWeight, let ideal = idealWeight, let goal = weightGoal {
            return calculateWeightGoalDate(current: current, ideal: ideal, goal: goal, experienceLevel: experienceLevel, trainingFrequency: trainingFrequency)
        }

        // Pour les autres objectifs, estimation par défaut
        if primaryGoals.contains(.boostPerformance) ||
           primaryGoals.contains(.increaseRecovery) ||
           primaryGoals.contains(.optimizeEnergy) ||
           primaryGoals.contains(.improveSleep) ||
           primaryGoals.contains(.reduceStress) ||
           primaryGoals.contains(.improveFitness) {
            return calculatePerformanceGoalDate(experienceLevel: experienceLevel, yearsOfExperience: yearsOfExperience, trainingFrequency: trainingFrequency)
        }

        // Date par défaut : 3 mois
        return calendar.date(byAdding: .month, value: 3, to: now)
    }

    /// Calcule la date pour un objectif de poids
    private func calculateWeightGoalDate(
        current: Double,
        ideal: Double,
        goal: WeightGoal,
        experienceLevel: ExperienceLevel?,
        trainingFrequency: String?
    ) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        let difference = abs(ideal - current)
        guard difference > 0 else { return calendar.date(byAdding: .month, value: 1, to: now) }

        // Taux de perte/prise de poids réaliste (kg par semaine)
        var weeklyRate: Double = 0.5 // Par défaut : 0.5 kg/semaine

        // Ajuster selon l'expérience
        if let level = experienceLevel {
            switch level {
            case .debutant:
                weeklyRate = 0.4
            case .intermediaire:
                weeklyRate = 0.6
            case .amateur:
                weeklyRate = 0.75
            case .professionnel:
                weeklyRate = 0.9
            }
        }

        // Ajuster selon la fréquence
        if let frequency = trainingFrequency {
            switch frequency {
            case "6+":
                weeklyRate *= 1.3
            case "3-5":
                weeklyRate *= 1.1
            case "0-2":
                weeklyRate *= 0.8
            default:
                break
            }
        }

        let weeksNeeded = Int(ceil(difference / weeklyRate))
        return calendar.date(byAdding: .weekOfYear, value: weeksNeeded, to: now)
    }

    /// Calcule la date pour un objectif de performance
    private func calculatePerformanceGoalDate(
        experienceLevel: ExperienceLevel?,
        yearsOfExperience: Int,
        trainingFrequency: String?
    ) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        var monthsNeeded = 3 // Par défaut

        // Ajuster selon l'expérience
        if let level = experienceLevel {
            switch level {
            case .debutant:
                monthsNeeded = 4
            case .intermediaire:
                monthsNeeded = 3
            case .amateur:
                monthsNeeded = 2
            case .professionnel:
                monthsNeeded = 1
            }
        }

        // Ajuster selon la fréquence
        if let frequency = trainingFrequency {
            switch frequency {
            case "6+":
                monthsNeeded = max(1, monthsNeeded - 1)
            case "3-5":
                break // Pas de changement
            case "0-2":
                monthsNeeded += 1
            default:
                break
            }
        }

        return calendar.date(byAdding: .month, value: monthsNeeded, to: now)
    }

    /// Génère le message de projection selon l'objectif clair
    func generateProjectionMessage(
        primaryGoals: Set<PrimaryGoal>,
        projectedDate: Date?,
        idealWeight: Double?,
        weightGoal: WeightGoal?
    ) -> String {
        guard let date = projectedDate else {
            return "Tu progresseras à ton rythme"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM"
        let dateString = formatter.string(from: date)

        // ✨ Utiliser la fonction pour déterminer l'objectif clair
        let clearGoal = determineClearMainGoal(
            primaryGoals: primaryGoals,
            idealWeight: idealWeight,
            weightGoal: weightGoal
        )

        return "\(clearGoal) le \(dateString)"
    }

    /// ✨ Détermine l'objectif principal clair de l'utilisateur
    /// - Si "gérer mon poids" est sélectionné (seul ou avec d'autres) → priorité absolue, objectif = poids
    /// - Si pas de poids mais plusieurs objectifs ou tous → "100% de ton potentiel"
    /// - Sinon → objectif spécifique (sport, récupération, énergie)
    func determineClearMainGoal(
        primaryGoals: Set<PrimaryGoal>,
        idealWeight: Double?,
        weightGoal: WeightGoal?
    ) -> String {
        if primaryGoals.contains(.manageWeight), let ideal = idealWeight {
            return "Tu feras \(String(format: "%.0f", ideal)) kg"
        }

        return "Tu auras atteint 100% de ton potentiel"
    }

    /// Calcule les données pour la courbe de progression avec irrégularités réalistes
    func generateProgressCurveData(
        startDate: Date,
        endDate: Date,
        currentValue: Double,
        targetValue: Double,
        isWeightGoal: Bool = false,
        weightGoal: WeightGoal? = nil
    ) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        let dataPoints = min(40, max(10, days)) // Plus de points pour une courbe plus fluide

        var curveData: [(date: Date, value: Double)] = []

        // Déterminer la direction de la courbe
        let isDescending = isWeightGoal && weightGoal == .lose

        for i in 0..<dataPoints {
            let progress = Double(i) / Double(dataPoints - 1)

            // Base : courbe avec accélération progressive
            var easedProgress: Double
            if isDescending {
                // Pour perdre du poids : ralentissement progressif (plus rapide au début)
                easedProgress = 1 - pow(1 - progress, 1.8)
            } else {
                // Pour gagner/améliorer : accélération progressive (plus rapide vers la fin)
                easedProgress = pow(progress, 1.5)
            }

            // Ajouter des irrégularités réalistes (plateaux, petites remontées/descentes)
            let irregularity = generateRealisticIrregularity(
                progress: progress,
                isDescending: isDescending,
                index: i,
                totalPoints: dataPoints
            )

            // Appliquer l'irrégularité
            easedProgress += irregularity

            // S'assurer que la progression reste dans les limites
            easedProgress = max(0, min(1, easedProgress))

            // Calculer la valeur avec l'irrégularité
            let baseValue = currentValue + (targetValue - currentValue) * easedProgress

            // Ajouter de petites variations aléatoires pour plus de réalisme
            let randomVariation = Double.random(in: -0.02...0.02) * abs(targetValue - currentValue)
            let value = baseValue + randomVariation

            // S'assurer que la valeur reste dans les limites logiques
            let minValue = min(currentValue, targetValue)
            let maxValue = max(currentValue, targetValue)
            let clampedValue = max(minValue, min(maxValue, value))

            if let date = calendar.date(byAdding: .day, value: Int(progress * Double(days)), to: startDate) {
                curveData.append((date: date, value: clampedValue))
            }
        }

        return curveData
    }

    /// Génère des irrégularités réalistes pour la courbe
    private func generateRealisticIrregularity(
        progress: Double,
        isDescending: Bool,
        index: Int,
        totalPoints: Int
    ) -> Double {
        // Créer des plateaux et des variations selon la progression
        var irregularity: Double = 0

        // Plateaux (périodes où la progression ralentit)
        if progress > 0.2 && progress < 0.4 {
            // Premier plateau autour de 20-40%
            irregularity -= 0.05 * sin(progress * 10)
        } else if progress > 0.6 && progress < 0.8 {
            // Deuxième plateau autour de 60-80%
            irregularity -= 0.03 * cos(progress * 8)
        }

        // Petites remontées/descentes selon la direction
        if isDescending {
            // Pour perdre du poids : parfois de petites remontées (rechutes légères)
            if index % 5 == 0 && progress > 0.1 && progress < 0.9 {
                irregularity += 0.02 * sin(Double(index) * 0.3)
            }
        } else {
            // Pour gagner/améliorer : parfois de petites descentes (plateaux)
            if index % 6 == 0 && progress > 0.2 && progress < 0.8 {
                irregularity -= 0.015 * cos(Double(index) * 0.4)
            }
        }

        // Variation générale pour plus de réalisme
        let generalVariation = 0.01 * sin(progress * 15) * cos(progress * 7)
        irregularity += generalVariation

        return irregularity
    }
}
