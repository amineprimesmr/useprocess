import Foundation
import PostHog

/// A/B essai annuel 3 jours (PostHog experiment `paywall-annual-trial-ab`).
///
/// - **control** : 9,99 € / mois + 34,99 € / an, **sans** essai (`annual3499`)
/// - **test** : mêmes prix, intro 3 jours sur l’annuel (`annual3499trial`)
///
/// Un code parrainage validé débloque l’essai **dans les deux bras**.
@MainActor
@Observable
final class PaywallPricingExperiment {
    static let shared = PaywallPricingExperiment()

    static let featureFlagKey = "paywall-annual-trial-ab"
    private static let persistenceKey = "process.paywall_annual_trial_variant"

    enum Variant: String, CaseIterable, Identifiable {
        /// Pas d’essai (sauf code parrainage).
        case control
        /// Essai 3 jours sur l’annuel pour tout le monde.
        case test

        var id: String { rawValue }

        var analyticsName: String {
            switch self {
            case .control: return "monthly_999_annual_3499"
            case .test: return "monthly_999_annual_3499_trial"
            }
        }

        var displayLabel: String {
            switch self {
            case .control: return "9,99€/mois + 34,99€/an"
            case .test: return "9,99€/mois + 34,99€/an · 3j essai"
            }
        }

        var shortPlan: SubscriptionBillingPlan { .monthly }

        var plans: [SubscriptionBillingPlan] { [shortPlan, .annual] }

        var shortProductID: String { SubscriptionConfiguration.monthly999ProductID }

        /// SKU annuel du bras, **sans** override parrainage.
        var catalogAnnualProductID: String {
            switch self {
            case .control: return SubscriptionConfiguration.annual3499ProductID
            case .test: return SubscriptionConfiguration.annual3499TrialProductID
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

    /// Essai annuel : bras test **ou** code parrainage.
    var grantsAnnualTrial: Bool {
        activeVariant == .test || ProcessReferralTrialEligibility.isUnlocked
    }

    var analyticsProperties: [String: Any] {
        [
            "pricing_variant": activeVariant.analyticsName,
            "pricing_variant_key": activeVariant.rawValue,
            "pricing_short_plan": activeVariant.shortPlan.rawValue,
            "referral_annual_trial": ProcessReferralTrialEligibility.isUnlocked,
            "annual_trial_offer": grantsAnnualTrial ? "trial" : "standard"
        ]
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.persistenceKey),
           let variant = Variant(rawValue: stored) {
            activeVariant = variant
            didResolveFromPostHog = true
        }
    }

    /// Résout le flag PostHog (sticky). Appeler après `ProcessAnalytics.configure()`.
    func resolve(forceRefresh: Bool = false) {
        guard ProcessAnalytics.isReady else {
            #if DEBUG
            print("[PaywallAnnualTrial] PostHog not ready — using \(activeVariant.rawValue)")
            #endif
            return
        }

        applyFlagFromSDK(source: forceRefresh ? "reload" : "boot", forceRefresh: forceRefresh)
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
                    self?.applyFlagFromSDK(source: "flags_ready", forceRefresh: false)
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

    private func applyFlagFromSDK(source: String, forceRefresh: Bool) {
        // Sticky déjà connu : ne pas re-appeler getFeatureFlag (évite une exposure
        // PostHog qui ne matcherait plus l’UI si le flag serveur a bougé).
        if didResolveFromPostHog, !forceRefresh {
            registerAnalytics(for: activeVariant)
            return
        }

        let flagValue = PostHogSDK.shared.getFeatureFlag(Self.featureFlagKey)

        let resolved: Variant?
        if let string = flagValue as? String, let variant = Variant(rawValue: string) {
            resolved = variant
        } else if let bool = flagValue as? Bool {
            resolved = bool ? .test : .control
        } else {
            resolved = nil
        }

        guard let resolved else {
            #if DEBUG
            print("[PaywallAnnualTrial] Flag \(Self.featureFlagKey) missing — keep \(activeVariant.rawValue)")
            #endif
            registerAnalytics(for: activeVariant)
            return
        }

        let previous = activeVariant
        activeVariant = resolved
        didResolveFromPostHog = true
        UserDefaults.standard.set(resolved.rawValue, forKey: Self.persistenceKey)
        registerAnalytics(for: resolved)

        ProcessAnalytics.capture("paywall_pricing_variant_assigned", properties: [
            "variant": resolved.rawValue,
            "variant_name": resolved.analyticsName,
            "previous": previous.rawValue,
            "source": source,
            "flag_key": Self.featureFlagKey
        ])
    }

    private func registerAnalytics(for variant: Variant) {
        PostHogSDK.shared.register([
            "pricing_variant": variant.analyticsName,
            "pricing_variant_key": variant.rawValue,
            "annual_trial_offer": grantsAnnualTrial ? "trial" : "standard"
        ])
        ProcessAnalytics.setPersonProperties([
            "pricing_variant": variant.analyticsName,
            "pricing_variant_key": variant.rawValue,
            "annual_trial_offer": grantsAnnualTrial ? "trial" : "standard"
        ])
    }
}
