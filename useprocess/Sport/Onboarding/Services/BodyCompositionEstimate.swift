//
//  BodyCompositionEstimate.swift
//  Process
//
//  Estimation légère de la composition corporelle (sans body scan).
//

import Foundation

struct BodyComposition {
    var bodyFatPercentage: Double?
    var leanMass: Double?
}

enum BodyCompositionEstimate {
    static func calculate(height: Double, weight: Double, age: Int, gender: Gender) -> BodyComposition {
        let heightM = height / 100.0
        let bmi = weight / (heightM * heightM)
        let sexFactor = gender == .male ? 1.0 : 0.0
        let bodyFat = (1.20 * bmi) + (0.23 * Double(age)) - (10.8 * sexFactor) - 5.4
        let clampedFat = min(max(bodyFat, 8), 45)
        let lean = weight * (1.0 - clampedFat / 100.0)
        return BodyComposition(bodyFatPercentage: clampedFat, leanMass: lean)
    }
}
