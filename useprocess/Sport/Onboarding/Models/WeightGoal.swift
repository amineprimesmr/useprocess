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
    @MainActor
    var title: String {
        switch self {
        case .lose: return OnboardingCopy.t("Réduire la rétention", en: "Reduce retention")
        case .gain: return OnboardingCopy.t("Consolider mon ovale", en: "Strengthen my face shape")
        }
    }

    var icon: String {
        switch self {
        case .lose: return "drop.fill"
        case .gain: return "face.smiling"
        }
    }

    @MainActor
    var description: String {
        switch self {
        case .lose:
            return OnboardingCopy.t(
                "Diminuer gonflement et rétention d’eau du visage",
                en: "Reduce facial puffiness and water retention"
            )
        case .gain:
            return OnboardingCopy.t(
                "Renforcer définition et structure faciale",
                en: "Strengthen facial definition and structure"
            )
        }
    }
}
