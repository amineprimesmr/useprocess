import Foundation

/// Action affichée au long-press sur l’icône (utilisateurs non abonnés).
enum ProcessHomeScreenQuickActionKind: String, Equatable {
    case trialOffer = "com.useprocess.quickaction.trial-offer"

    var analyticsSource: String {
        "quick_action_trial_offer"
    }
}
