//
//  WeightGoal.swift
//  Process
//

import Foundation

enum WeightGoal: String, CaseIterable, Codable {
    case lose = "Perdre du poids"
    case gain = "Prendre du poids"

    var icon: String {
        switch self {
        case .lose: return "arrow.down.circle.fill"
        case .gain: return "arrow.up.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .lose: return "Réduire ton poids de manière saine"
        case .gain: return "Augmenter ton poids (masse musculaire)"
        }
    }
}
