import Foundation
import StoreKit

/// Règles marché pour les essais gratuits — storefront App Store (pas la langue produit).
enum SubscriptionMarketPolicy {
    /// Territoires où l’intro 3 jours annuel est autorisée (aligné App Store Connect).
    static let frenchTrialStorefrontCountryCodes: Set<String> = ["FRA"]

    /// Storefronts anglophones — paywall strict, jamais de copy / logique essai.
    static let strictNoTrialStorefrontCountryCodes: Set<String> = [
        "USA", "GBR", "CAN", "AUS", "NZL", "IRL",
    ]

    private(set) static var cachedStorefrontCountryCode: String?

    static var resolvedStorefrontCountryCode: String? {
        cachedStorefrontCountryCode
    }

    /// Vrai uniquement pour un storefront FR (billing Apple). Strict par défaut.
    static var allowsIntroductoryFreeTrial: Bool {
        guard let code = resolvedStorefrontCountryCode?.uppercased() else { return false }
        if strictNoTrialStorefrontCountryCodes.contains(code) { return false }
        return frenchTrialStorefrontCountryCodes.contains(code)
    }

    @MainActor
    static func refreshStorefrontCountryCode() async {
        if let storefront = await Storefront.current {
            cachedStorefrontCountryCode = storefront.countryCode
        }
    }

    static var analyticsProperties: [String: String] {
        var props: [String: String] = [
            "trial_market_allowed": allowsIntroductoryFreeTrial ? "true" : "false",
        ]
        if let code = resolvedStorefrontCountryCode {
            props["storefront_country"] = code
        }
        return props
    }
}
