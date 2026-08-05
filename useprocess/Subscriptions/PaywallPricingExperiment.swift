import Foundation
import PostHog

/// A/B tarifs paywall (PostHog experiment `paywall-pricing-ab`).
///
/// - **control (A)** : 8,99 € / semaine + 34,99 € / an
/// - **test (B)** : 9,99 € / mois + 49,99 € / an
@MainActor
@Observable
final class PaywallPricingExperiment {
    static let shared = PaywallPricingExperiment()

    static let featureFlagKey = "paywall-pricing-ab"
    private static let persistenceKey = "process.paywall_pricing_variant"

    enum Variant: String, CaseIterable, Identifiable {
        /// A — hebdo 8,99 + annuel 34,99
        case control
        /// B — mensuel 9,99 + annuel 49,99
        case test

        var id: String { rawValue }

        var analyticsName: String {
            switch self {
            case .control: return "a_weekly_899_annual_3499"
            case .test: return "b_monthly_999_annual_4999"
            }
        }

        var displayLabel: String {
            switch self {
            case .control: return "A · 8,99€/sem + 34,99€/an"
            case .test: return "B · 9,99€/mois + 49,99€/an"
            }
        }

        /// Plan court (gauche/droite du picker hors annuel).
        var shortPlan: SubscriptionBillingPlan {
            switch self {
            case .control: return .weekly
            case .test: return .monthly
            }
        }

        var plans: [SubscriptionBillingPlan] { [shortPlan, .annual] }

        var shortProductID: String {
            switch self {
            case .control: return SubscriptionConfiguration.weekly899ProductID
            case .test: return SubscriptionConfiguration.monthly999ProductID
            }
        }

        var annualProductID: String {
            switch self {
            case .control: return SubscriptionConfiguration.annual3499ProductID
            case .test: return SubscriptionConfiguration.annual4999ProductID
            }
        }

        var offeringID: String {
            switch self {
            case .control: return SubscriptionConfiguration.offeringIDPricingA
            case .test: return SubscriptionConfiguration.offeringIDPricingB
            }
        }

        var allProductIDs: [String] { [shortProductID, annualProductID] }

        var fallbackShortPrice: String {
            switch self {
            case .control: return "8,99€"
            case .test: return "9,99€"
            }
        }

        var fallbackAnnualPrice: String {
            switch self {
            case .control: return "34,99€"
            case .test: return "49,99€"
            }
        }

        var fallbackAnnualMonthlyEquivalent: String {
            switch self {
            case .control: return "2,92€"
            case .test: return "4,17€"
            }
        }

        /// Prix barré annuel = short × 52 (hebdo) ou × 12 (mensuel).
        var fallbackStrikethroughAnnual: String {
            switch self {
            case .control: return "467€"
            case .test: return "120€"
            }
        }
    }

    private(set) var activeVariant: Variant = .control
    private(set) var didResolveFromPostHog = false

    /// Props à merger dans les events paywall / purchase.
    var analyticsProperties: [String: Any] {
        [
            "pricing_variant": activeVariant.analyticsName,
            "pricing_variant_key": activeVariant.rawValue,
            "pricing_short_plan": activeVariant.shortPlan.rawValue
        ]
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.persistenceKey),
           let variant = Variant(rawValue: stored) {
            activeVariant = variant
            // Déjà assigné lors d’une session précédente — sticky.
            didResolveFromPostHog = true
        }
    }

    /// Résout le flag PostHog (sticky). Appeler après `ProcessAnalytics.configure()`.
    func resolve(forceRefresh: Bool = false) {
        guard ProcessAnalytics.isReady else {
            #if DEBUG
            print("[PaywallPricing] PostHog not ready — using \(activeVariant.rawValue)")
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
        case .weekly, .monthly:
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

        // Première assignation → getFeatureFlag enregistre l’exposure expérience.
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
            print("[PaywallPricing] Flag \(Self.featureFlagKey) missing — keep \(activeVariant.rawValue)")
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
            "source": source
        ])
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
