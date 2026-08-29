import Foundation
import PostHog

/// Pricing config — hard paywall, plus d'A/B sur un essai gratuit.
///
/// **control** : 9,99 € / mois + 34,99 € / an, sans essai (`annual3499`).
@MainActor
@Observable
final class PaywallPricingExperiment {
    static let shared = PaywallPricingExperiment()

    static let featureFlagKey = "paywall-annual-trial-ab"
    private static let persistenceKey = "process.paywall_annual_trial_variant"

    enum Variant: String, CaseIterable, Identifiable {
        /// Pas d'essai.
        case control

        var id: String { rawValue }

        var analyticsName: String {
            switch self {
            case .control: return "monthly_999_annual_3499"
            }
        }

        var displayLabel: String {
            switch self {
            case .control: return "9,99€/mois + 34,99€/an"
            }
        }

        var shortPlan: SubscriptionBillingPlan { .monthly }

        var plans: [SubscriptionBillingPlan] { [shortPlan, .annual] }

        var shortProductID: String { SubscriptionConfiguration.monthly999ProductID }

        /// SKU annuel du bras.
        var catalogAnnualProductID: String {
            switch self {
            case .control: return SubscriptionConfiguration.annual3499ProductID
            }
        }

        var annualProductID: String { SubscriptionConfiguration.annualProductIDForCurrentTrialState }

        var offeringID: String { SubscriptionConfiguration.defaultOfferingID }

        var allProductIDs: [String] { SubscriptionConfiguration.paywallCatalogProductIDs }

        var fallbackShortPrice: String { "9,99€" }

        var fallbackAnnualPrice: String { "34,99€" }

        var fallbackAnnualMonthlyEquivalent: String { "2,92€" }

        /// 9,99 € × 12.
        var fallbackStrikethroughAnnual: String { "120€" }
    }

    private(set) var activeVariant: Variant = .control
    private(set) var didResolveFromPostHog = false

    var analyticsProperties: [String: Any] {
        [
            "pricing_variant": activeVariant.analyticsName,
            "pricing_variant_key": activeVariant.rawValue,
            "pricing_short_plan": activeVariant.shortPlan.rawValue
        ]
    }

    private init() {}

    /// Résout le flag PostHog — conservé pour analytics, n'affecte plus le pricing (hard paywall).
    func resolve(forceRefresh: Bool = false) {
        guard ProcessAnalytics.isReady else { return }
        registerAnalytics(for: activeVariant)
    }

    /// Attend le reload des feature flags puis applique la variante (idéal avant le paywall).
    func resolveWhenFlagsReady() async {
        guard ProcessAnalytics.isReady else {
            resolve()
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            PostHogSDK.shared.reloadFeatureFlags { [weak self] in
                Task { @MainActor in
                    if let self {
                        self.registerAnalytics(for: self.activeVariant)
                    }
                    continuation.resume()
                }
            }
        }
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

    private func registerAnalytics(for variant: Variant) {
        PostHogSDK.shared.register([
            "pricing_variant": variant.analyticsName,
            "pricing_variant_key": variant.rawValue
        ])
        ProcessAnalytics.setPersonProperties([
            "pricing_variant": variant.analyticsName,
            "pricing_variant_key": variant.rawValue
        ])
    }
}
