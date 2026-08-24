//
//  PersonalizedIdealWeightCalculator.swift
//
//  Inférence d’objectif poids (lose/gain) pour les projections onboarding.
//

import Foundation

@MainActor
enum PersonalizedIdealWeightCalculator {

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
}
