import Foundation
import RevenueCat
import StoreKit

/// Essai gratuit configuré côté App Store Connect / StoreKit (3 jours).
struct SubscriptionTrialInfo: Equatable {
    let days: Int
    let isEligible: Bool

    static var configured: SubscriptionTrialInfo {
        SubscriptionTrialInfo(
            days: SubscriptionConfiguration.freeTrialDays,
            isEligible: true
        )
    }

    var isActiveOffer: Bool {
        isEligible && days > 0
    }

    var shortLabel: String {
        "\(days) jours d'essai gratuits"
    }

    func ctaTitle(fallback: String = "Continuer") -> String {
        isActiveOffer ? "Démarrer mon essai gratuit" : fallback
    }

    func ctaSubtitle(
        for plan: SubscriptionBillingPlan,
        displayPrice: String
    ) -> String? {
        guard isActiveOffer else { return nil }
        let normalized = displayPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        switch plan {
        case .annual:
            return "Aucun paiement aujourd'hui, puis \(normalized)/an"
        case .monthly:
            return "Aucun paiement aujourd'hui, puis \(normalized)/mois"
        }
    }

    func cardSecondaryPrice(
        for plan: SubscriptionBillingPlan,
        annualMonthlyEquivalent: String
    ) -> String {
        switch plan {
        case .monthly:
            return "Annulable à tout moment."
        case .annual:
            if isActiveOffer {
                return "\(days) jours d'essai gratuits"
            }
            return ""
        }
    }
}

enum SubscriptionIntroOfferParser {
    static func trialDays(from product: Product?) -> Int? {
        guard let offer = product?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return days(in: offer.period)
    }

    static func trialDays(from storeProduct: StoreProduct?) -> Int? {
        trialDays(from: storeProduct?.sk2Product)
    }

    static func days(in period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day:
            return max(1, period.value)
        case .week:
            return max(1, period.value * 7)
        case .month:
            return max(1, period.value * 30)
        case .year:
            return max(1, period.value * 365)
        @unknown default:
            return SubscriptionConfiguration.freeTrialDays
        }
    }
}
