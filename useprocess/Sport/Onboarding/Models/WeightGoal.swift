//
//  WeightGoal.swift
//  Process
//

import Foundation

/// Historique : rawValues FR conservés pour la persistance.
/// L’UI n’affiche plus de langage « perte de poids » — Process = debloat visage.
enum WeightGoal: String, CaseIterable, Codable {
    case lose = "Perdre du poids"
    case gain = "Prendre du poids"

    /// Libellé produit (debloat), jamais de framing poids.
    var title: String {
        switch self {
        case .lose: return "Réduire la rétention"
        case .gain: return "Consolider mon ovale"
        }
    }

    var icon: String {
        switch self {
        case .lose: return "drop.fill"
        case .gain: return "face.smiling"
        }
    }

    var description: String {
        switch self {
        case .lose: return "Diminuer gonflement et rétention d’eau du visage"
        case .gain: return "Renforcer définition et structure faciale"
        }
    }
}
