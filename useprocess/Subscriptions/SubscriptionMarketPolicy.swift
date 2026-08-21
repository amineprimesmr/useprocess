import Foundation
import StoreKit

/// L’essai intro 3 jours n’est plus un droit marché FR : il est **débloqué par un code**.
enum SubscriptionMarketPolicy {
    private(set) static var cachedStorefrontCountryCode: String?

    static var resolvedStorefrontCountryCode: String? {
        cachedStorefrontCountryCode
    }

    /// Vrai seulement après un code parrainage / créateur validé.
    @MainActor
    static var allowsIntroductoryFreeTrial: Bool {
        ProcessReferralTrialEligibility.isUnlocked
    }

    @MainActor
    static func refreshStorefrontCountryCode() async {
        if let storefront = await Storefront.current {
            cachedStorefrontCountryCode = storefront.countryCode
        }
    }

    @MainActor
    static var analyticsProperties: [String: String] {
        var props: [String: String] = [
            "trial_market_allowed": allowsIntroductoryFreeTrial ? "true" : "false",
            "referral_annual_trial": ProcessReferralTrialEligibility.isUnlocked ? "true" : "false",
        ]
        if let code = resolvedStorefrontCountryCode {
            props["storefront_country"] = code
        }
        return props
    }
}
