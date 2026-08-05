import Foundation
import RevenueCat
import StoreKit

/// Essai gratuit configuré côté App Store Connect / StoreKit (désactivé).
struct SubscriptionTrialInfo: Equatable {
    let days: Int
    let isEligible: Bool

    static var configured: SubscriptionTrialInfo {
        SubscriptionTrialInfo(
            days: SubscriptionConfiguration.retentionQuickActionTrialDays,
            isEligible: SubscriptionConfiguration.retentionQuickActionTrialDays > 0
        )
    }

    var isActiveOffer: Bool {
        isEligible && days > 0
    }

    @MainActor
    var shortLabel: String {
        AppCopy.t(
            "\(days) jours d'essai gratuits",
            en: "\(days)-day free trial"
        )
    }

    @MainActor
    func ctaTitle(fallback: String? = nil) -> String {
        let resolvedFallback = fallback ?? AppCopy.continueCTA
        return isActiveOffer
            ? AppCopy.t("Démarrer mon essai gratuit", en: "Start my free trial")
            : resolvedFallback
    }

    @MainActor
    func ctaSubtitle(
        for plan: SubscriptionBillingPlan,
        displayPrice: String
    ) -> String? {
        guard isActiveOffer else { return nil }
        let normalized = displayPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        switch plan {
        case .annual:
            return AppCopy.t(
                "Aucun paiement aujourd'hui, puis \(normalized) /an",
                en: "No payment today, then \(normalized)/year"
            )
        case .monthly:
            return AppCopy.t(
                "Aucun paiement aujourd'hui, puis \(normalized)/mois",
                en: "No payment today, then \(normalized)/mo"
            )
        case .weekly:
            return AppCopy.t(
                "Aucun paiement aujourd'hui, puis \(normalized)/semaine",
                en: "No payment today, then \(normalized)/week"
            )
        }
    }

    func cardSecondaryPrice(
        for plan: SubscriptionBillingPlan,
        annualMonthlyEquivalent: String
    ) -> String {
        _ = plan
        _ = annualMonthlyEquivalent
        return ""
    }
}

enum SubscriptionIntroOfferParser {
    /// Essais gratuits désactivés — ne jamais parser une intro offer StoreKit / ASC.
    static func trialDays(from product: Product?) -> Int? {
        _ = product
        return nil
    }

    static func trialDays(from storeProduct: StoreProduct?) -> Int? {
        _ = storeProduct
        return nil
    }

    static func days(in period: Product.SubscriptionPeriod) -> Int {
        _ = period
        return 0
    }
}
