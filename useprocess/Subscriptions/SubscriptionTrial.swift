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
        "\(days) jours gratuits"
    }

    func ctaTitle(fallback: String = "Continuer") -> String {
        isActiveOffer ? "Essayer \(days) jours gratuits" : fallback
    }

    func cardSecondaryPrice(
        for plan: SubscriptionBillingPlan,
        annualMonthlyEquivalent: String
    ) -> String {
        switch plan {
        case .monthly: return "Facturé mensuellement"
        case .annual: return "Équivalent à \(annualMonthlyEquivalent) /mois"
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
