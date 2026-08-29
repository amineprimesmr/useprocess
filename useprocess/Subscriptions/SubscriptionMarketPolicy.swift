import Foundation
import StoreKit

/// Hard paywall — plus aucun essai gratuit proposé.
enum SubscriptionMarketPolicy {
    private(set) static var cachedStorefrontCountryCode: String?

    static var resolvedStorefrontCountryCode: String? {
        cachedStorefrontCountryCode
    }

    /// Toujours faux — plus d'essai introductif.
    @MainActor
    static var allowsIntroductoryFreeTrial: Bool { false }

    @MainActor
    static func refreshStorefrontCountryCode() async {
        if let storefront = await Storefront.current {
            cachedStorefrontCountryCode = storefront.countryCode
        }
    }

    @MainActor
    static var analyticsProperties: [String: String] {
        var props: [String: String] = [
            "trial_market_allowed": allowsIntroductoryFreeTrial ? "true" : "false"
        ]
        if let code = resolvedStorefrontCountryCode {
            props["storefront_country"] = code
        }
        return props
    }
}
