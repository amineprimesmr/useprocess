import Foundation

/// Identifiants alignés App Store Connect + RevenueCat (projet `com.useprocess`).
enum SubscriptionConfiguration {
    /// Entitlement RevenueCat — accès premium app.
    static let entitlementID = "premium"

    /// Offering RevenueCat par défaut.
    static let defaultOfferingID = "Premium"

    /// Package RevenueCat (si identifiants custom dans le dashboard).
    static let monthlyPackageID = "$rc_monthly"
    static let annualPackageID = "$rc_annual"

    /// Product IDs App Store Connect (groupe Premium).
    static let monthlyProductID = "com.useprocess.monthly"
    static let annualProductID = "com.useprocess.annual"

    /// Groupe d'abonnements App Store (StoreKit + éligibilité intro).
    static let subscriptionGroupID = "21482999"

    /// Essai gratuit — doit correspondre à l'offre intro App Store Connect (P3D).
    static let freeTrialDays = 3

    /// Prix affichés en secours tant que StoreKit n'a pas répondu (zone EUR).
    static let fallbackMonthlyPrice = "5,99 €"
    static let fallbackAnnualPrice = "29,99 €"
    static let fallbackAnnualMonthlyEquivalent = "2,50 €"
}

enum SubscriptionBillingPlan: String, CaseIterable, Identifiable {
    case monthly
    case annual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: return "Mensuel"
        case .annual: return "Annuel"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly: return "5,99 € / mois"
        case .annual: return "29,99 € / an"
        }
    }

    var productID: String {
        switch self {
        case .monthly: return SubscriptionConfiguration.monthlyProductID
        case .annual: return SubscriptionConfiguration.annualProductID
        }
    }
}

struct SubscriptionProductDisplay: Equatable {
    let productID: String
    let displayName: String
    let displayPrice: String
    let periodLabel: String
    let monthlyEquivalentPrice: String?
    let freeTrialDays: Int?
    let isIntroOfferEligible: Bool

    var trialInfo: SubscriptionTrialInfo {
        if isIntroOfferEligible, let freeTrialDays, freeTrialDays > 0 {
            return SubscriptionTrialInfo(days: freeTrialDays, isEligible: true)
        }
        return SubscriptionTrialInfo(days: 0, isEligible: false)
    }

    static func fallback(for plan: SubscriptionBillingPlan) -> SubscriptionProductDisplay {
        switch plan {
        case .monthly:
            return SubscriptionProductDisplay(
                productID: plan.productID,
                displayName: "Process AI Premium — Mensuel",
                displayPrice: SubscriptionConfiguration.fallbackMonthlyPrice,
                periodLabel: "par mois",
                monthlyEquivalentPrice: nil,
                freeTrialDays: SubscriptionConfiguration.freeTrialDays,
                isIntroOfferEligible: true
            )
        case .annual:
            return SubscriptionProductDisplay(
                productID: plan.productID,
                displayName: "Process AI Premium — Annuel",
                displayPrice: SubscriptionConfiguration.fallbackAnnualPrice,
                periodLabel: "par an",
                monthlyEquivalentPrice: SubscriptionConfiguration.fallbackAnnualMonthlyEquivalent,
                freeTrialDays: SubscriptionConfiguration.freeTrialDays,
                isIntroOfferEligible: true
            )
        }
    }

    func updatingIntroEligibility(_ eligible: Bool) -> SubscriptionProductDisplay {
        SubscriptionProductDisplay(
            productID: productID,
            displayName: displayName,
            displayPrice: displayPrice,
            periodLabel: periodLabel,
            monthlyEquivalentPrice: monthlyEquivalentPrice,
            freeTrialDays: freeTrialDays,
            isIntroOfferEligible: eligible
        )
    }
}

enum SubscriptionError: LocalizedError {
    case userNotAuthenticated
    case productNotFound
    case offerNotFound
    case verificationFailed
    case userCancelled
    case pending
    case noActiveSubscription
    case notConfigured
    case unknown

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated: return "Connecte-toi pour acheter un abonnement."
        case .productNotFound: return "Offre introuvable. Réessaie dans quelques instants."
        case .offerNotFound: return "Offres RevenueCat indisponibles."
        case .verificationFailed: return "Échec de vérification de l'achat."
        case .userCancelled: return "Achat annulé."
        case .pending: return "Achat en attente de validation."
        case .noActiveSubscription: return "Aucun abonnement actif."
        case .notConfigured: return "Abonnements non configurés (clé RevenueCat manquante)."
        case .unknown: return "Erreur inconnue."
        }
    }
}
