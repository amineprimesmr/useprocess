import Foundation

/// Catalogue paywall figé après l’A/B `paywall-pricing-ab` :
/// **9,99 € / mois** + **34,99 € / an**. L’essai 3 jours est géré à part (code parrainage).
@MainActor
@Observable
final class PaywallPricingExperiment {
    static let shared = PaywallPricingExperiment()

    static let featureFlagKey = "paywall-pricing-ab"

    enum Variant: String, CaseIterable, Identifiable {
        /// Catalogue unique expédié (plus d’A/B).
        case shipped

        var id: String { rawValue }

        var analyticsName: String { "monthly_999_annual_3499" }

        var displayLabel: String { "9,99€/mois + 34,99€/an" }

        var shortPlan: SubscriptionBillingPlan { .monthly }

        var plans: [SubscriptionBillingPlan] { [shortPlan, .annual] }

        var shortProductID: String { SubscriptionConfiguration.monthly999ProductID }

        var annualProductID: String { SubscriptionConfiguration.annualProductIDForCurrentTrialState }

        var offeringID: String { SubscriptionConfiguration.defaultOfferingID }

        var allProductIDs: [String] { SubscriptionConfiguration.paywallCatalogProductIDs }

        var fallbackShortPrice: String { "9,99€" }

        var fallbackAnnualPrice: String { "34,99€" }

        var fallbackAnnualMonthlyEquivalent: String { "2,92€" }

        /// 9,99 € × 12.
        var fallbackStrikethroughAnnual: String { "120€" }
    }

    private(set) var activeVariant: Variant = .shipped
    private(set) var didResolveFromPostHog = true

    var analyticsProperties: [String: Any] {
        [
            "pricing_variant": activeVariant.analyticsName,
            "pricing_variant_key": activeVariant.rawValue,
            "pricing_short_plan": activeVariant.shortPlan.rawValue,
            "referral_annual_trial": ProcessReferralTrialEligibility.isUnlocked
        ]
    }

    private init() {
        registerAnalytics()
    }

    func resolve(forceRefresh: Bool = false) {
        _ = forceRefresh
        activeVariant = .shipped
        registerAnalytics()
    }

    func resolveWhenFlagsReady() async {
        resolve()
    }

    func productID(for plan: SubscriptionBillingPlan) -> String {
        switch plan {
        case .weekly:
            return SubscriptionConfiguration.weekly899ProductID
        case .monthly:
            return activeVariant.shortProductID
        case .annual:
            return activeVariant.annualProductID
        }
    }

    private func registerAnalytics() {
        registerAnalytics(for: .shipped)
    }

    private func registerAnalytics(for variant: Variant) {
        ProcessAnalytics.setPersonProperties([
            "pricing_variant": variant.analyticsName,
            "pricing_variant_key": variant.rawValue
        ])
    }
}
