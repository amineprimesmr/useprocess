//
//  BodyCompositionAssessment.swift
//  Process
//
//  Détermine si l'utilisateur a déjà un bon rapport taille/poids
//  et si la page « poids idéal » est pertinente (debloat vs recomposition).
//

import Foundation

enum BodyCompositionProfile: String, Equatable {
    /// IMC athlétique, proche du poids lean — debloat visage uniquement.
    case optimal
    /// Très proche de la cible — pas besoin de fixer un poids idéal.
    case nearOptimal
    /// Écart modéré — la page poids idéal aide à calibrer la trajectoire.
    case recomposition
    /// Surpoids / écart marqué — objectif poids nécessaire.
    case significantChange
    /// Sous-poids — objectif de prise à définir.
    case underweight

    var isFitForDebloatOnly: Bool {
        switch self {
        case .optimal, .nearOptimal:
            return true
        default:
            return false
        }
    }
}

struct BodyCompositionAssessment: Equatable {
    let bmi: Double
    let leanAnchorKg: Double
    let gapToLeanAnchorKg: Double
    let profile: BodyCompositionProfile
    let shouldAskIdealWeight: Bool
    let focusLabel: String

    static func evaluate(
        weight: Double,
        height: Double,
        age: Int,
        gender: Gender?
    ) -> BodyCompositionAssessment? {
        guard OnboardingViewModel.isPlausibleWeight(weight), height >= 120 else { return nil }

        let resolvedGender = gender ?? .male
        let heightM = height / 100.0
        let bmi = weight / (heightM * heightM)
        let anchor = PersonalizedIdealWeightCalculator.leanAthleticAnchorWeight(
            height: height,
            gender: resolvedGender,
            age: age
        )
        let gap = weight - anchor

        let profile = classifyProfile(
            bmi: bmi,
            gap: gap,
            age: age,
            gender: resolvedGender
        )

        let meaningfulChange = estimateMeaningfulWeightChange(
            currentWeight: weight,
            height: height,
            age: age,
            gender: resolvedGender,
            profile: profile
        )

        let shouldAsk = shouldAskIdealWeight(
            profile: profile,
            bmi: bmi,
            gap: gap,
            meaningfulChange: meaningfulChange,
            gender: resolvedGender
        )

        let focus = profile.isFitForDebloatOnly
            ? "Debloat visage — on se concentre sur le gonflement."
            : "Debloat visage — on affine rétention et ovale."

        return BodyCompositionAssessment(
            bmi: bmi,
            leanAnchorKg: anchor,
            gapToLeanAnchorKg: gap,
            profile: profile,
            shouldAskIdealWeight: shouldAsk,
            focusLabel: focus
        )
    }

    // MARK: - Classification

    private static func classifyProfile(
        bmi: Double,
        gap: Double,
        age: Int,
        gender: Gender
    ) -> BodyCompositionProfile {
        let underweightThreshold = gender == .female ? 18.5 : 19.0
        if bmi < underweightThreshold {
            return .underweight
        }

        let optimalBMI = gender == .female
            ? 19.0...23.0
            : 20.0...24.0

        let nearOptimalBMI = gender == .female
            ? 23.0...24.8
            : 24.0...25.8

        if optimalBMI.contains(bmi), gap <= 4 {
            return .optimal
        }

        if nearOptimalBMI.contains(bmi), gap <= 5, age <= 35 {
            return .nearOptimal
        }

        if bmi >= 27 || gap > 8 {
            return .significantChange
        }

        return .recomposition
    }

    private static func shouldAskIdealWeight(
        profile: BodyCompositionProfile,
        bmi: Double,
        gap: Double,
        meaningfulChange: Bool,
        gender: Gender
    ) -> Bool {
        switch profile {
        case .optimal, .nearOptimal:
            return false
        case .underweight:
            return true
        case .significantChange:
            return true
        case .recomposition:
            break
        }

        if !meaningfulChange { return false }

        let heavyThreshold = gender == .female ? 25.5 : 26.5
        if bmi >= heavyThreshold || gap > 6 {
            return true
        }

        return gap > 2.5
    }

    /// Poids idéal recommandé suffisamment différent pour justifier la question.
    private static func estimateMeaningfulWeightChange(
        currentWeight: Double,
        height: Double,
        age: Int,
        gender: Gender,
        profile: BodyCompositionProfile
    ) -> Bool {
        guard profile != .underweight else { return true }

        let inferredGoal = PersonalizedIdealWeightCalculator.inferredWeightGoal(
            currentWeight: currentWeight,
            height: height,
            age: age,
            gender: gender
        )

        let recommended = PersonalizedIdealWeightCalculator.calculatePersonalizedIdealWeight(
            currentWeight: currentWeight,
            height: height,
            age: age,
            gender: gender,
            weightGoal: inferredGoal
        )

        guard OnboardingViewModel.isPlausibleWeight(recommended) else {
            return meaningfulGapFromAnchor(
                currentWeight: currentWeight,
                height: height,
                age: age,
                gender: gender
            )
        }

        return abs(recommended - currentWeight) >= 2.5
    }

    private static func meaningfulGapFromAnchor(
        currentWeight: Double,
        height: Double,
        age: Int,
        gender: Gender
    ) -> Bool {
        let anchor = PersonalizedIdealWeightCalculator.leanAthleticAnchorWeight(
            height: height,
            gender: gender,
            age: age
        )
        return abs(currentWeight - anchor) >= 2.5
    }
}
