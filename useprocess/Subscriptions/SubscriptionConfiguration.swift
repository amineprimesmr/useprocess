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

    /// Quick action long-press icône : offre lifetime winback (pas d’essai gratuit).
    static let retentionQuickActionLifetimeOfferEnabled = true

    /// Toujours 0 — aucun essai gratuit dans l’app (ni UI, ni StoreKit local).
    static let retentionQuickActionTrialDays = 0

    static func retentionTrialDays(for plan: SubscriptionBillingPlan) -> Int? {
        _ = plan
        return nil
    }

    /// Aucun essai gratuit — ni paywall, ni rétention, ni StoreKit.
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

    static func paywallStrikethroughAnnualTotal(
        fromMonthlyPrice monthly: Decimal,
        currencyCode: String? = nil
    ) -> String {
        formatPaywallPrice(decimal: monthly * 12, currencyCode: currencyCode)
    }

    /// Locale d’affichage prix — suit la langue produit.
    static var paywallPriceLocale: Locale { ProcessAppLanguage.currentLocale }

    /// FR produit → EUR à l’écran. EN → devise StoreKit (souvent USD).
    /// Évite d’afficher `$` sur un paywall FR quand le sandbox / compte App Store est US.
    nonisolated static func shouldUseEuroPaywallDisplay(storeCurrencyCode: String?) -> Bool {
        guard !ProcessAppLanguage.prefersEnglish else { return false }
        let code = storeCurrencyCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        return code != "EUR"
    }

    /// Formate un prix paywall avec la devise StoreKit / RevenueCat.
    static func formatPaywallPrice(decimal: Decimal, currencyCode: String? = nil) -> String {
        var input = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 0, .plain)
        let amount = NSDecimalNumber(decimal: rounded)

        let code = (currencyCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "EUR"

        // Formats compacts cohérents sur les cartes (ex. 23€ / $23).
        switch code {
        case "EUR":
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = paywallPriceLocale
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            let numberPart = formatter.string(from: amount) ?? "\(amount)"
            return "\(numberPart)€"
        case "USD":
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "en_US")
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            let numberPart = formatter.string(from: amount) ?? "\(amount)"
            return "$\(numberPart)"
        default:
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = code
            formatter.locale = paywallPriceLocale
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            return formatter.string(from: amount) ?? "\(amount) \(code)"
        }
    }

    /// Compat — anciens call sites EUR.
    static func formatPaywallEUR(decimal: Decimal) -> String {
        formatPaywallPrice(decimal: decimal, currencyCode: "EUR")
    }

    /// Winback roue : accès à vie à 19 € (achat unique non consommable).
    static let lifetimeProductID = "com.useprocess.lifetime"
    static let winbackLifetimePrice = "19€"
    /// Prix barré (référence annuel) affiché à côté de l’offre lifetime.
    static let winbackCompareAtPrice = "49€"
    static let winbackOfferID = "lifetime_19"
    /// Label jackpot roue / hero offre (FR — UI localise via OnboardingCopy).
    static let winbackJackpotTitle = "À VIE"
}

enum SubscriptionBillingPlan: String, CaseIterable, Identifiable {
    case monthly
    case annual

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .monthly: return OnboardingCopy.t("Mensuel", en: "Monthly")
        case .annual: return OnboardingCopy.t("Annuel", en: "Yearly")
        }
    }

    @MainActor
    var subtitle: String {
        let perMonth = OnboardingCopy.t("/mois", en: "/mo")
        switch self {
        case .monthly:
            return "\(SubscriptionConfiguration.fallbackMonthlyPrice)\(perMonth)"
        case .annual:
            return "\(SubscriptionConfiguration.fallbackAnnualMonthlyEquivalent)\(perMonth)"
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
        // Essais gratuits désactivés — jamais exposer un essai depuis le display produit.
        SubscriptionTrialInfo(days: 0, isEligible: false)
    }

    static func fallback(
        for plan: SubscriptionBillingPlan,
        freeTrialDays: Int? = nil,
        isIntroOfferEligible: Bool = false
    ) -> SubscriptionProductDisplay {
        switch plan {
        case .monthly:
            return SubscriptionProductDisplay(
                productID: plan.productID,
                displayName: "Process Premium — Mensuel",
                displayPrice: SubscriptionConfiguration.fallbackMonthlyPrice,
                periodLabel: AppCopy.tSync("par mois", en: "per month"),
                monthlyEquivalentPrice: nil,
                paywallStrikethroughAnnualTotal: SubscriptionConfiguration.fallbackMonthlyStrikethroughAnnualPrice,
                freeTrialDays: freeTrialDays,
                isIntroOfferEligible: isIntroOfferEligible
            )
        case .annual:
            return SubscriptionProductDisplay(
                productID: plan.productID,
                displayName: "Process Premium — Annuel",
                displayPrice: SubscriptionConfiguration.fallbackAnnualPrice,
                periodLabel: AppCopy.tSync("par an", en: "per year"),
                monthlyEquivalentPrice: SubscriptionConfiguration.fallbackAnnualMonthlyEquivalent,
                paywallStrikethroughAnnualTotal: nil,
                freeTrialDays: freeTrialDays,
                isIntroOfferEligible: isIntroOfferEligible
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

    /// Prix principal sur les cartes paywall (montant + /mois|/mo, sans coupure de ligne).
    var paywallPrimaryMonthlyPriceLabel: String {
        let amount = monthlyEquivalentPrice ?? displayPrice
        return Self.paywallPerMonthLabel(amount: amount)
    }

    private static func paywallPerMonthLabel(amount: String) -> String {
        "\(amount)\(AppCopy.tSync("/mois", en: "/mo"))"
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
        case .userNotAuthenticated:
            return AppCopy.tSync(
                "Connecte-toi pour acheter un abonnement.",
                en: "Sign in to purchase a subscription."
            )
        case .productNotFound:
            return AppCopy.tSync(
                "Offre introuvable. Réessaie dans quelques instants.",
                en: "Offer not found. Try again in a moment."
            )
        case .offerNotFound:
            return AppCopy.tSync(
                "Offres RevenueCat indisponibles.",
                en: "RevenueCat offers unavailable."
            )
        case .verificationFailed:
            return AppCopy.tSync(
                "Échec de vérification de l'achat.",
                en: "Purchase verification failed."
            )
        case .userCancelled:
            return AppCopy.tSync("Achat annulé.", en: "Purchase cancelled.")
        case .pending:
            return AppCopy.tSync(
                "Achat en attente de validation.",
                en: "Purchase pending validation."
            )
        case .noActiveSubscription:
            return AppCopy.tSync("Aucun abonnement actif.", en: "No active subscription.")
        case .notConfigured:
            return AppCopy.tSync(
                "Abonnements non configurés (clé RevenueCat manquante).",
                en: "Subscriptions not configured (missing RevenueCat key)."
            )
        case .unknown:
            return AppCopy.tSync("Erreur inconnue.", en: "Unknown error.")
        }
    }
}
