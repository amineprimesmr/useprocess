import Foundation
import StoreKit

/// L’essai intro 3 jours : bras test A/B (`paywall-annual-trial-ab`) ou code parrainage.
enum SubscriptionMarketPolicy {
    private(set) static var cachedStorefrontCountryCode: String?

    static var resolvedStorefrontCountryCode: String? {
        cachedStorefrontCountryCode
    }

    /// Vrai si le bras test est actif **ou** un code parrainage / créateur est validé.
    @MainActor
    static var allowsIntroductoryFreeTrial: Bool {
        PaywallPricingExperiment.shared.grantsAnnualTrial
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
