import Foundation

/// Action affichée au long-press sur l’icône (utilisateurs non abonnés) — offre lifetime winback.
enum ProcessHomeScreenQuickActionKind: String, Equatable {
    case lifetimeOffer = "com.useprocess.quickaction.lifetime-offer"

    /// Ancien identifiant quick action essai — toujours accepté au lancement.
    static let legacyTrialOfferType = "com.useprocess.quickaction.trial-offer"

    var analyticsSource: String {
        "quick_action_lifetime_offer"
    }

    static func resolve(shortcutType: String) -> ProcessHomeScreenQuickActionKind? {
        if let kind = Self(rawValue: shortcutType) { return kind }
        if shortcutType == legacyTrialOfferType { return .lifetimeOffer }
        return nil
    }
}
