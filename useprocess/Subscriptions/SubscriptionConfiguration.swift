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

    /// Essai gratuit annuel — réservé à la quick action rétention (long-press icône).
    static let retentionQuickActionTrialDays = 3

    static func retentionTrialDays(for plan: SubscriptionBillingPlan) -> Int? {
        guard retentionQuickActionTrialDays > 0 else { return nil }
        switch plan {
        case .annual: return retentionQuickActionTrialDays
        case .monthly: return nil
        }
    }

    /// Le paywall standard n’expose jamais l’essai — uniquement le flux quick action.
    static func supportsFreeTrial(_ plan: SubscriptionBillingPlan) -> Bool {
        _ = plan
        return false
    }

    /// Prix affichés en secours tant que StoreKit n'a pas répondu (zone EUR).
    static let fallbackMonthlyPrice = "23€"
    static let fallbackAnnualPrice = "49€"
    static let fallbackAnnualMonthlyEquivalent = "4€"
    static let fallbackMonthlyStrikethroughAnnualPrice = "276€"
    static let annualCompareAtPrice: String? = nil

    static func paywallStrikethroughAnnualTotal(fromMonthlyPrice monthly: Decimal) -> String {
        formatPaywallEUR(decimal: monthly * 12)
    }

    static let paywallPriceLocale = Locale(identifier: "fr_FR")

    static func formatPaywallEUR(decimal: Decimal) -> String {
        var input = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 0, .plain)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = paywallPriceLocale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let numberPart = formatter.string(from: rounded as NSDecimalNumber) ?? "\(rounded)"
        return "\(numberPart)€"
    }

    /// Winback roue : accès à vie à 19 € (achat unique non consommable).
    static let lifetimeProductID = "com.useprocess.lifetime"
    static let winbackLifetimePrice = "19€"
    /// Prix barré (référence annuel) affiché à côté de l’offre lifetime.
    static let winbackCompareAtPrice = "49€"
    static let winbackOfferID = "lifetime_19"
    /// Label jackpot roue / hero offre.
    static let winbackJackpotTitle = "À VIE"
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
        case .monthly:
            return "\(SubscriptionConfiguration.fallbackMonthlyPrice)/mois"
        case .annual:
            return "\(SubscriptionConfiguration.fallbackAnnualMonthlyEquivalent)/mois"
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
    /// 12× le mensuel — prix barré sur l’onglet Annuel (ex. 276 €).
    let paywallStrikethroughAnnualTotal: String?
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
                displayName: "Process Premium — Mensuel",
                displayPrice: SubscriptionConfiguration.fallbackMonthlyPrice,
                periodLabel: "par mois",
                monthlyEquivalentPrice: nil,
                paywallStrikethroughAnnualTotal: SubscriptionConfiguration.fallbackMonthlyStrikethroughAnnualPrice,
                freeTrialDays: nil,
                isIntroOfferEligible: false
            )
        case .annual:
            return SubscriptionProductDisplay(
                productID: plan.productID,
                displayName: "Process Premium — Annuel",
                displayPrice: SubscriptionConfiguration.fallbackAnnualPrice,
                periodLabel: "par an",
                monthlyEquivalentPrice: SubscriptionConfiguration.fallbackAnnualMonthlyEquivalent,
                paywallStrikethroughAnnualTotal: nil,
                freeTrialDays: nil,
                isIntroOfferEligible: false
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
            paywallStrikethroughAnnualTotal: paywallStrikethroughAnnualTotal,
            freeTrialDays: freeTrialDays,
            isIntroOfferEligible: eligible
        )
    }

    /// Prix barré annuel (12× mensuel), ex. « 276€ ».
    var paywallAnnualStrikethroughComparePrice: String {
        paywallStrikethroughAnnualTotal ?? SubscriptionConfiguration.fallbackMonthlyStrikethroughAnnualPrice
    }

    /// Prix principal sur les cartes paywall (toujours en €/mois, sans coupure de ligne).
    var paywallPrimaryMonthlyPriceLabel: String {
        let amount = monthlyEquivalentPrice ?? displayPrice
        return Self.paywallPerMonthLabel(amount: amount)
    }

    private static func paywallPerMonthLabel(amount: String) -> String {
        "\(amount)/mois"
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
