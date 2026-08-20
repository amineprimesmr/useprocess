import Foundation

/// Identifiants alignés App Store Connect + RevenueCat (projet `com.useprocess`).
enum SubscriptionConfiguration {
    /// Entitlement RevenueCat — accès premium app.
    static let entitlementID = "premium"

    /// Offering RevenueCat par défaut (legacy).
    static let defaultOfferingID = "Premium"

    /// Offerings A/B tarifs.
    static let offeringIDPricingA = "Premium_A"
    static let offeringIDPricingB = "Premium_B"

    /// Package RevenueCat (si identifiants custom dans le dashboard).
    static let weeklyPackageID = "$rc_weekly"
    static let monthlyPackageID = "$rc_monthly"
    static let annualPackageID = "$rc_annual"

    /// Product IDs App Store Connect (groupe Premium) — legacy.
    static let monthlyProductID = "com.useprocess.monthly"
    static let annualProductID = "com.useprocess.annual"

    /// A/B pricing — variante A (control).
    static let weekly899ProductID = "com.useprocess.weekly899"
    static let annual3499ProductID = "com.useprocess.annual3499"

    /// A/B pricing — variante B (test).
    static let monthly999ProductID = "com.useprocess.monthly999"
    static let annual4999ProductID = "com.useprocess.annual4999"

    /// Tous les product IDs premium (entitlements / restore).
    static var allPremiumProductIDs: Set<String> {
        [
            monthlyProductID,
            annualProductID,
            weekly899ProductID,
            annual3499ProductID,
            monthly999ProductID,
            annual4999ProductID,
            lifetimeProductID
        ]
    }

    /// Groupe d'abonnements App Store (StoreKit + éligibilité intro).
    static let subscriptionGroupID = "21837790"

    /// App Store Connect → Informations sur l’app → Apple ID (formulaire Retention Messaging).
    static let appStoreAppleID = "6753808143"

    /// Copy prête à coller — RevenueCat Lifecycle → Retention (default message, fr-FR).
    enum RetentionMessagingCopy {
        static let defaultTitleFR = "Garde ton plan debloat actif"
        static let defaultSubtitleFR =
            "Scans visage, routine et coach restent débloqués tant que tu restes abonné."
        static let defaultTitleEN = "Keep your debloat plan going"
        static let defaultSubtitleEN =
            "Face scans, routine, and coach stay unlocked while you stay subscribed."

        static let trialTitleFR = "Ton essai t’aide déjà à debloat"
        static let trialSubtitleFR =
            "Continue maintenant pour garder tes scans, ta routine et ton coach."
        static let trialTitleEN = "Your trial is already helping you debloat"
        static let trialSubtitleEN =
            "Continue now to keep your scans, routine, and coach."
    }

    /// Quick action long-press icône : offre lifetime winback (pas d’essai gratuit).
    static let retentionQuickActionLifetimeOfferEnabled = true

    /// Quick action = lifetime 19 € uniquement (pas d’essai annuel rétention).
    static let retentionQuickActionTrialDays = 0

    /// Fallback UI — essai annuel marché FR tant que StoreKit n’a pas répondu.
    static let frenchMarketAnnualTrialDays = 3

    static func retentionTrialDays(for plan: SubscriptionBillingPlan) -> Int? {
        _ = plan
        return nil
    }

    /// Essai gratuit annuel — storefront FR uniquement (Apple facture selon le compte App Store).
    static func supportsFreeTrial(_ plan: SubscriptionBillingPlan) -> Bool {
        guard SubscriptionMarketPolicy.allowsIntroductoryFreeTrial else { return false }
        return plan == .annual
    }

    static func configuredFallbackTrialDays(for plan: SubscriptionBillingPlan) -> Int? {
        guard supportsFreeTrial(plan) else { return nil }
        return frenchMarketAnnualTrialDays
    }

    /// Prix affichés en secours tant que StoreKit n'a pas répondu (zone EUR) — legacy.
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

    static func paywallStrikethroughAnnualTotal(
        fromShortPlanPrice price: Decimal,
        shortPlan: SubscriptionBillingPlan,
        currencyCode: String? = nil
    ) -> String {
        let periods: Decimal = shortPlan == .weekly ? 52 : 12
        return formatPaywallPrice(decimal: price * periods, currencyCode: currencyCode)
    }

    /// Locale d’affichage prix — suit la langue produit.
    static var paywallPriceLocale: Locale { ProcessAppLanguage.currentLocale }

    /// FR produit → EUR à l’écran. EN → devise StoreKit (souvent USD).
    /// Évite d’afficher `$` sur un paywall FR quand le sandbox / compte App Store est US.
    nonisolated static func shouldUseEuroPaywallDisplay(storeCurrencyCode: String?) -> Bool {
        guard ProcessAppLanguage.usesFrenchCopy else { return false }
        let code = storeCurrencyCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        return code != "EUR"
    }

    /// Formate un prix paywall avec la devise StoreKit / RevenueCat.
    /// Conserve les centimes si le montant n’est pas entier (ex. 8,99€).
    static func formatPaywallPrice(decimal: Decimal, currencyCode: String? = nil) -> String {
        var input = decimal
        var roundedWhole = Decimal()
        NSDecimalRound(&roundedWhole, &input, 0, .plain)
        let fractionDigits = (roundedWhole == input) ? 0 : 2

        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, fractionDigits, .plain)
        let amount = NSDecimalNumber(decimal: rounded)

        let code = (currencyCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "EUR"

        switch code {
        case "EUR":
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = paywallPriceLocale
            formatter.minimumFractionDigits = fractionDigits
            formatter.maximumFractionDigits = fractionDigits
            let numberPart = formatter.string(from: amount) ?? "\(amount)"
            return "\(numberPart)€"
        case "USD":
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "en_US")
            formatter.minimumFractionDigits = fractionDigits
            formatter.maximumFractionDigits = fractionDigits
            let numberPart = formatter.string(from: amount) ?? "\(amount)"
            return "$\(numberPart)"
        default:
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = code
            formatter.locale = paywallPriceLocale
            formatter.minimumFractionDigits = fractionDigits
            formatter.maximumFractionDigits = fractionDigits
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
    case weekly
    case monthly
    case annual

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .weekly: return OnboardingCopy.t("Hebdomadaire", en: "Weekly")
        case .monthly: return OnboardingCopy.t("Mensuel", en: "Monthly")
        case .annual: return OnboardingCopy.t("Annuel", en: "Yearly")
        }
    }

    /// Titre court pour le segment picker.
    @MainActor
    var shortPickerTitle: String {
        switch self {
        case .weekly: return OnboardingCopy.t("Hebdo", en: "Weekly")
        case .monthly: return OnboardingCopy.t("Mensuel", en: "Monthly")
        case .annual: return OnboardingCopy.t("Annuel", en: "Yearly")
        }
    }

    @MainActor
    var subtitle: String {
        let variant = PaywallPricingExperiment.shared.activeVariant
        let perMonth = OnboardingCopy.t("/mois", en: "/mo")
        let perWeek = OnboardingCopy.t("/sem.", en: "/wk")
        switch self {
        case .weekly:
            return "\(variant.fallbackShortPrice)\(perWeek)"
        case .monthly:
            return "\(variant.fallbackShortPrice)\(perMonth)"
        case .annual:
            let perYear = OnboardingCopy.t("/an", en: "/yr")
            return "\(variant.fallbackAnnualPrice)\(perYear)"
        }
    }

    var productID: String {
        PaywallPricingExperiment.shared.productID(for: self)
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

    static func fallback(
        for plan: SubscriptionBillingPlan,
        freeTrialDays: Int? = nil,
        isIntroOfferEligible: Bool = false
    ) -> SubscriptionProductDisplay {
        let variant = PaywallPricingExperiment.shared.activeVariant
        switch plan {
        case .weekly:
            return SubscriptionProductDisplay(
                productID: plan.productID,
                displayName: "Process Premium — Hebdomadaire",
                displayPrice: variant.fallbackShortPrice,
                periodLabel: AppCopy.tSync("par semaine", en: "per week"),
                monthlyEquivalentPrice: nil,
                paywallStrikethroughAnnualTotal: variant.fallbackStrikethroughAnnual,
                freeTrialDays: freeTrialDays,
                isIntroOfferEligible: isIntroOfferEligible
            )
        case .monthly:
            return SubscriptionProductDisplay(
                productID: plan.productID,
                displayName: "Process Premium — Mensuel",
                displayPrice: variant.fallbackShortPrice,
                periodLabel: AppCopy.tSync("par mois", en: "per month"),
                monthlyEquivalentPrice: nil,
                paywallStrikethroughAnnualTotal: variant.fallbackStrikethroughAnnual,
                freeTrialDays: freeTrialDays,
                isIntroOfferEligible: isIntroOfferEligible
            )
        case .annual:
            return SubscriptionProductDisplay(
                productID: plan.productID,
                displayName: "Process Premium — Annuel",
                displayPrice: variant.fallbackAnnualPrice,
                periodLabel: AppCopy.tSync("par an", en: "per year"),
                monthlyEquivalentPrice: variant.fallbackAnnualMonthlyEquivalent,
                paywallStrikethroughAnnualTotal: nil,
                freeTrialDays: freeTrialDays,
                isIntroOfferEligible: isIntroOfferEligible
            )
        }
    }

    func updatingIntroEligibility(_ eligible: Bool) -> SubscriptionProductDisplay {
        updatingTrial(days: freeTrialDays, eligible: eligible)
    }

    func updatingTrial(days: Int?, eligible: Bool) -> SubscriptionProductDisplay {
        SubscriptionProductDisplay(
            productID: productID,
            displayName: displayName,
            displayPrice: displayPrice,
            periodLabel: periodLabel,
            monthlyEquivalentPrice: monthlyEquivalentPrice,
            paywallStrikethroughAnnualTotal: paywallStrikethroughAnnualTotal,
            freeTrialDays: days,
            isIntroOfferEligible: eligible
        )
    }

    /// Prix barré annuel (short × 12 ou × 52), ex. « 120€ » / « 467€ ».
    var paywallAnnualStrikethroughComparePrice: String {
        paywallStrikethroughAnnualTotal
            ?? PaywallPricingExperiment.shared.activeVariant.fallbackStrikethroughAnnual
    }

    /// Prix principal sur les cartes paywall (montant + /mois|/mo, sans coupure de ligne).
    var paywallPrimaryMonthlyPriceLabel: String {
        let amount = monthlyEquivalentPrice ?? displayPrice
        return Self.paywallPerMonthLabel(amount: amount)
    }

    /// Prix annuel affiché sur le segment Annuel (ex. « 34,99€/an »), pas l’équivalent mensuel.
    var paywallPrimaryAnnualPriceLabel: String {
        "\(displayPrice)\(AppCopy.tSync("/an", en: "/yr"))"
    }

    /// Label segment plan court (hebdo ou mensuel).
    func paywallShortPlanPriceLabel(for plan: SubscriptionBillingPlan) -> String {
        switch plan {
        case .weekly:
            return "\(displayPrice)\(AppCopy.tSync("/sem.", en: "/wk"))"
        case .monthly:
            return paywallPrimaryMonthlyPriceLabel
        case .annual:
            return paywallPrimaryAnnualPriceLabel
        }
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
    case manageSubscriptionsUnavailable
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
        case .manageSubscriptionsUnavailable:
            return AppCopy.tSync(
                "Impossible d’ouvrir la gestion d’abonnement sur cet appareil.",
                en: "Couldn't open subscription management on this device."
            )
        case .unknown:
            return AppCopy.tSync("Erreur inconnue.", en: "Unknown error.")
        }
    }
}
