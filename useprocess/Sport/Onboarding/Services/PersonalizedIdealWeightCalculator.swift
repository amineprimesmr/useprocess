//
//  PersonalizedIdealWeightCalculator.swift
//
//  Calculateur de poids idéal PERSONNALISÉ basé sur la composition corporelle
//  Solution au problème : deux personnes de même taille peuvent avoir des poids de forme très différents
//

import Foundation

@MainActor
class PersonalizedIdealWeightCalculator {

    /// Infère perdre / prendre quand l'utilisateur n'a pas encore choisi son poids idéal.
    static func inferredWeightGoal(
        currentWeight: Double,
        height: Double,
        age: Int,
        gender: Gender?
    ) -> WeightGoal? {
        guard currentWeight > 0, height >= 120 else { return nil }

        let heightM = height / 100.0
        let bmi = currentWeight / (heightM * heightM)
        let resolvedGender = gender ?? .preferNotToSay
        let anchor = leanAthleticAnchorWeight(
            height: height,
            gender: resolvedGender,
            age: age
        )
        let gapToAnchor = currentWeight - anchor

        let underweightThreshold = resolvedGender == .female ? 18.5 : 19.0
        if bmi < underweightThreshold {
            return .gain
        }

        let overweightThreshold = resolvedGender == .female ? 25.0 : 25.5
        let highNormalThreshold = resolvedGender == .female ? 24.2 : 24.6
        let meaningfulExcess = resolvedGender == .female ? 6.0 : 7.0

        if bmi >= overweightThreshold {
            return .lose
        }

        if bmi >= highNormalThreshold, gapToAnchor >= meaningfulExcess {
            return .lose
        }

        return nil
    }

    /// Calcule le poids idéal personnalisé basé sur la morphologie réelle
    /// 
    /// - Parameters:
    ///   - currentWeight: Poids actuel (kg)
    ///   - height: Taille (cm)
    ///   - age: Âge
    ///   - gender: Genre
    ///   - weightGoal: Objectif (perdre, prendre, maintenir)
    ///   - bodyFatPercentage: % masse grasse actuel (si disponible depuis body scan ou HealthKit)
    ///   - leanBodyMass: Masse maigre actuelle (kg) - si disponible depuis HealthKit
    ///   - bodyComposition: Composition complète depuis body scan (optionnel)
    /// 
    /// - Returns: Poids idéal personnalisé (kg) basé sur la masse maigre et le % graisse cible
    static func calculatePersonalizedIdealWeight(
        currentWeight: Double,
        height: Double,
        age: Int,
        gender: Gender,
        weightGoal: WeightGoal?,
        bodyFatPercentage: Double? = nil,
        leanBodyMass: Double? = nil,
        bodyComposition: BodyComposition? = nil
    ) -> Double {
        let resolvedGoal = weightGoal
            ?? inferredWeightGoal(
                currentWeight: currentWeight,
                height: height,
                age: age,
                gender: gender
            )

        guard let resolvedGoal else {
            return (currentWeight * 2).rounded() / 2
        }

        // ✅ ÉTAPE 1 : Estimer ou récupérer la masse maigre actuelle
        let currentLeanMass: Double

        if let leanMass = leanBodyMass, leanMass > 0 {
            // Priorité 1 : Données HealthKit (le plus précis)
            currentLeanMass = leanMass
        } else if let bodyFatPct = bodyFatPercentage ?? bodyComposition?.bodyFatPercentage, bodyFatPct > 0 {
            // Priorité 2 : Calculer depuis % graisse (si disponible depuis body scan)
            currentLeanMass = currentWeight * (1.0 - bodyFatPct / 100.0)
        } else if let leanMassFromComposition = bodyComposition?.leanMass, leanMassFromComposition > 0 {
            // Priorité 3 : Masse maigre depuis body scan
            currentLeanMass = leanMassFromComposition
        } else {
            // Priorité 4 : Estimer via formule (si aucune donnée disponible)
            currentLeanMass = estimateLeanBodyMass(
                weight: currentWeight,
                height: height,
                age: age,
                gender: gender
            )
        }

        // ✅ ÉTAPE 2 : Déterminer le % de masse grasse cible selon l'objectif et la morphologie actuelle
        let targetBodyFatPercentage = calculateTargetBodyFatPercentage(
            currentBodyFatPct: bodyFatPercentage ?? bodyComposition?.bodyFatPercentage,
            currentLeanMass: currentLeanMass,
            currentWeight: currentWeight,
            height: height,
            gender: gender,
            age: age,
            weightGoal: resolvedGoal
        )

        // ✅ ÉTAPE 3 : Calculer le poids idéal basé sur la masse maigre et le % graisse cible
        let compositionIdeal = currentLeanMass / (1.0 - targetBodyFatPercentage / 100.0)
        let leanAnchor = leanAthleticAnchorWeight(height: height, gender: gender, age: age)
        let idealWeight = compositionIdeal * 0.65 + leanAnchor * 0.35

        // ✅ ÉTAPE 4 : Vérifier que le poids idéal est réaliste et dans la plage IMC saine
        let heightInMeters = height / 100.0
        let idealBMI = idealWeight / (heightInMeters * heightInMeters)

        var adjustedIdealWeight = idealWeight

        let minHealthyBMI = gender == .male ? 19.0 : 18.5
        if idealBMI < minHealthyBMI {
            adjustedIdealWeight = max(idealWeight, minHealthyBMI * heightInMeters * heightInMeters)
        }

        let maxReasonableBMI = gender == .male ? 26.0 : 25.5
        if idealBMI > maxReasonableBMI {
            adjustedIdealWeight = min(idealWeight, maxReasonableBMI * heightInMeters * heightInMeters)
        }

        if resolvedGoal == .lose {
            adjustedIdealWeight = min(adjustedIdealWeight, currentWeight - 0.5)

            let currentBMI = currentWeight / (heightInMeters * heightInMeters)
            if currentBMI >= 21.5, currentWeight - adjustedIdealWeight < 2.0 {
                let motivatedTarget = min(currentWeight - 1.0, max(leanAnchor, adjustedIdealWeight))
                adjustedIdealWeight = motivatedTarget
            }

            let absoluteMin = minHealthyBMI * heightInMeters * heightInMeters
            adjustedIdealWeight = max(adjustedIdealWeight, absoluteMin)
        } else if resolvedGoal == .gain {
            adjustedIdealWeight = max(adjustedIdealWeight, currentWeight + 0.5)
        }

        return (adjustedIdealWeight * 2).rounded() / 2
    }

    // MARK: - Calculs auxiliaires

    /// Poids de référence « fit & sec » selon la taille — pas un poids « normal » médical.
    static func leanAthleticAnchorWeight(height: Double, gender: Gender, age: Int) -> Double {
        let heightM = height / 100.0
        let baseBMI: Double

        switch gender {
        case .male:
            if age <= 25 {
                baseBMI = 21.8
            } else if age <= 35 {
                baseBMI = 22.2
            } else {
                baseBMI = 22.6
            }
        case .female:
            if age <= 25 {
                baseBMI = 20.8
            } else if age <= 35 {
                baseBMI = 21.2
            } else {
                baseBMI = 21.6
            }
        case .other, .preferNotToSay:
            if age <= 25 {
                baseBMI = 21.3
            } else if age <= 35 {
                baseBMI = 21.7
            } else {
                baseBMI = 22.1
            }
        }

        return baseBMI * heightM * heightM
    }

    /// Estime la masse maigre actuelle si aucune donnée n'est disponible
    private static func estimateLeanBodyMass(
        weight: Double,
        height: Double,
        age: Int,
        gender: Gender
    ) -> Double {
        // Estimation Deurenberg simplifiée
        let composition = BodyCompositionEstimate.calculate(
            height: height,
            weight: weight,
            age: age,
            gender: gender
        )

        // Utiliser la masse maigre calculée, ou estimer depuis le % graisse
        if let leanMass = composition.leanMass, leanMass > 0 {
            return leanMass
        }

        // Fallback : estimation basique par genre
        let estimatedBodyFatPct = composition.bodyFatPercentage ?? (gender == .male ? 20.0 : 25.0)
        return weight * (1.0 - estimatedBodyFatPct / 100.0)
    }

    /// Détermine le % de masse grasse cible selon l'objectif et la morphologie actuelle
    private static func calculateTargetBodyFatPercentage(
        currentBodyFatPct: Double?,
        currentLeanMass: Double,
        currentWeight: Double,
        height: Double,
        gender: Gender,
        age: Int,
        weightGoal: WeightGoal?
    ) -> Double {

        let heightInMeters = height / 100.0
        let currentBMI = currentWeight / (heightInMeters * heightInMeters)

        // ✅ Déterminer le % graisse actuel (si non fourni, estimer)
        let estimatedCurrentBodyFatPct: Double
        if let currentPct = currentBodyFatPct, currentPct > 0 {
            estimatedCurrentBodyFatPct = currentPct
        } else {
            // Estimer depuis IMC et morphologie
            let composition = BodyCompositionEstimate.calculate(
                height: height,
                weight: currentWeight,
                age: age,
                gender: gender
            )
            estimatedCurrentBodyFatPct = composition.bodyFatPercentage ?? (gender == .male ? 20.0 : 25.0)
        }

        // ✅ Calculer le ratio masse maigre/poids pour évaluer la morphologie
        let leanMassRatio = currentLeanMass / currentWeight

        // ✅ Déterminer si la personne a une morphologie "musclée" ou "normale"
        // Si ratio > 0.75 pour hommes ou > 0.70 pour femmes = morphologie musclée
        let isMuscularBuild = (gender == .male && leanMassRatio > 0.75) || (gender == .female && leanMassRatio > 0.70)

        // ✅ Calculer le % graisse cible selon l'objectif
        guard let goal = weightGoal else {
            return gender == .male
                ? (age <= 30 ? 12.5 : 14.0)
                : (age <= 30 ? 20.0 : 22.0)
        }

        switch goal {
        case .lose:
            if isMuscularBuild {
                if currentBMI >= 30.0 {
                    return gender == .male ? 12.0 : 18.0
                } else if currentBMI >= 25.0 {
                    return gender == .male ? 13.0 : 19.0
                } else if age <= 30 {
                    return gender == .male ? 12.0 : 19.5
                } else {
                    return gender == .male ? 14.0 : 21.0
                }
            } else {
                if currentBMI >= 30.0 {
                    return gender == .male ? 11.0 : 19.0
                } else if currentBMI >= 25.0 {
                    return gender == .male ? 12.0 : 20.0
                } else if age <= 30 {
                    return gender == .male ? 12.5 : 20.5
                } else {
                    return gender == .male ? 14.5 : 22.5
                }
            }

        case .gain:
            // ✅ OBJECTIF : Prendre du poids

            // Si morphologie musclée : objectif de prise de masse musculaire
            if isMuscularBuild {
                // Pour personnes déjà musclées : maintenir % graisse actuel ou légère augmentation
                // (prise de masse = muscle + un peu de graisse)
                let targetPct = min(estimatedCurrentBodyFatPct + 2.0, gender == .male ? 18.0 : 25.0)
                return targetPct
            } else {
                // Morphologie normale : viser % graisse optimal avec prise de masse musculaire
                if currentBMI < 18.5 {
                    // Maigreur : viser 15-18% (hommes) ou 22-25% (femmes)
                    return gender == .male ? 16.0 : 23.0
                } else {
                    // IMC normal : maintenir % graisse actuel avec prise de masse
                    return min(estimatedCurrentBodyFatPct + 1.0, gender == .male ? 17.0 : 24.0)
                }
            }
        }
    }

    /// Calcule la plage de poids idéal personnalisée pour le slider
    static func calculatePersonalizedWeightRange(
        idealWeight: Double,
        currentWeight: Double,
        height: Double,
        gender: Gender,
        age: Int,
        weightGoal: WeightGoal?,
        bodyFatPercentage: Double? = nil,
        leanBodyMass: Double? = nil
    ) -> ClosedRange<Double> {

        // Calculer les limites min/max autour du poids idéal
        let heightInMeters = height / 100.0

        guard let goal = weightGoal else {
            // Pas d'objectif : plage IMC standard
            let minBMI = 18.5
            let maxBMI = 24.9
            let minWeight = minBMI * heightInMeters * heightInMeters
            let maxWeight = maxBMI * heightInMeters * heightInMeters
            return minWeight...maxWeight
        }

        switch goal {
        case .lose:
            // ✅ PLAGE ÉLARGIE : Permettre une perte de poids plus importante
            // Minimum : permettre jusqu'à -15% du poids actuel (pour perte significative)
            // Maximum : poids actuel - 0.5kg (point de départ du slider)
            let percentageLoss = 0.15 // 15% de perte maximale (ex: 80kg → 68kg)
            let minWeightFromCurrent = currentWeight * (1.0 - percentageLoss)

            // Utiliser le minimum entre : poids idéal - 10% OU poids actuel - 15%
            let minWeightFromIdeal = idealWeight * 0.90 // 10% en dessous du poids idéal
            let minWeight = max(minWeightFromCurrent, minWeightFromIdeal, idealWeight * 0.85) // Au moins 85% du poids idéal
            let maxWeight = currentWeight - 0.5

            // S'assurer que le minimum ne descend pas en dessous d'IMC 18.5 (limite saine minimale)
            let minBMIThreshold = 18.5
            let absoluteMinWeight = minBMIThreshold * heightInMeters * heightInMeters
            let safeMinWeight = max(minWeight, absoluteMinWeight)

            // ✅ Garantir une plage minimale de 10kg pour la flexibilité
            let rangeSize = maxWeight - safeMinWeight
            if rangeSize < 10.0 {
                // Élargir vers le bas si la plage est trop petite
                let expandedMin = max(safeMinWeight - (10.0 - rangeSize), absoluteMinWeight)
                return expandedMin...maxWeight
            }

            return safeMinWeight...maxWeight

        case .gain:
            // ✅ PLAGE ÉLARGIE : Permettre une prise de poids plus importante
            // Minimum : poids actuel + 0.5kg (point de départ du slider)
            // Maximum : permettre jusqu'à +15% du poids actuel (pour prise significative)
            let percentageGain = 0.15 // 15% de prise maximale (ex: 80kg → 92kg)
            let maxWeightFromCurrent = currentWeight * (1.0 + percentageGain)

            // Utiliser le maximum entre : poids idéal + 10% OU poids actuel + 15%
            let maxWeightFromIdeal = idealWeight * 1.10 // 10% au-dessus du poids idéal
            let minWeight = currentWeight + 0.5
            let maxWeight = max(maxWeightFromCurrent, maxWeightFromIdeal, idealWeight * 1.15) // Au moins 115% du poids idéal

            // S'assurer que le maximum ne dépasse pas IMC 26.0 (acceptable pour sportifs musclés)
            let maxBMIThreshold = 26.0
            let absoluteMaxWeight = maxBMIThreshold * heightInMeters * heightInMeters
            let safeMaxWeight = min(maxWeight, absoluteMaxWeight)

            // ✅ Garantir une plage minimale de 10kg pour la flexibilité
            let rangeSize = safeMaxWeight - minWeight
            if rangeSize < 10.0 {
                // Élargir vers le haut si la plage est trop petite (dans les limites IMC)
                let expandedMax = min(safeMaxWeight + (10.0 - rangeSize), absoluteMaxWeight)
                return minWeight...expandedMax
            }

            return minWeight...safeMaxWeight
        }
    }
}
