import Combine
import Foundation
import RevenueCat
import StoreKit

@MainActor
final class SubscriptionService: NSObject, ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var subscriptionStatus: SubscriptionStatus = .unknown
    @Published private(set) var isLoading = false
    @Published private(set) var monthlyDisplay: SubscriptionProductDisplay?
    @Published private(set) var annualDisplay: SubscriptionProductDisplay?
    @Published private(set) var monthlyStoreProduct: Product?
    @Published private(set) var annualStoreProduct: Product?
    @Published private(set) var isInFreeTrial = false
    @Published private(set) var trialExpirationDate: Date?
    @Published private(set) var isIntroOfferEligible = true
    @Published private(set) var isRetentionTrialOfferActive = false

    /// Compat paywall existant.
    var annualProduct: Product? { annualStoreProduct }
    var monthlyProduct: Product? { monthlyStoreProduct }

    private var isConfigured = false
    private var monthlyPackage: Package?
    private var annualPackage: Package?
    private var monthlyStoreProductRC: StoreProduct?
    private var annualStoreProductRC: StoreProduct?

    var hasLiveMonthlyProduct: Bool {
        monthlyPackage != nil || monthlyStoreProductRC != nil || monthlyStoreProduct != nil
    }

    var hasLiveAnnualProduct: Bool {
        annualPackage != nil || annualStoreProductRC != nil || annualStoreProduct != nil
    }

    var hasLiveLifetimeProduct: Bool {
        true
    }

    enum SubscriptionStatus: Equatable {
        case unknown, notSubscribed, subscribed, expired, inGracePeriod, inBillingRetryPeriod

        var isActive: Bool {
            switch self {
            case .subscribed, .inGracePeriod, .inBillingRetryPeriod: return true
            default: return false
            }
        }
    }

    var canPurchase: Bool {
        hasLiveMonthlyProduct || hasLiveAnnualProduct
    }

    #if DEBUG
    func activateDeveloperPremiumAccess() {
        subscriptionStatus = .subscribed
        isInFreeTrial = false
        trialExpirationDate = nil
    }
    #endif

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func configure() {
        guard !isConfigured else { return }
        RevenueCatConfiguration.logConfigurationStatus()

        guard RevenueCatConfiguration.isConfigured, let apiKey = RevenueCatConfiguration.apiKey else {
            // DEBUG only: StoreKit local pour itérer sans dashboard.
            // Release sans clé = zéro tracking RevenueCat (bug prod historique).
            applyFallbackProducts()
            Task {
                await loadSubscriptions()
                await checkSubscriptionStatus()
            }
            return
        }

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        isConfigured = true

        if let uid = AuthUser.current?.uid {
            Task { await syncAppUserID(uid) }
        }

        Task {
            await loadSubscriptions()
            await checkSubscriptionStatus()
        }
    }

    func syncAppUserID(_ userID: String?) async {
        guard isConfigured else { return }

        guard let userID, !userID.isEmpty else {
            await logOutAfterAccountDeletion()
            return
        }

        ProcessAnalytics.identify(userId: userID)
        do {
            _ = try await Purchases.shared.logIn(userID)
            await checkSubscriptionStatus()
        } catch {
            return
        }
    }

    /// Délie RevenueCat après suppression de compte (utilisateur anonyme).
    func logOutAfterAccountDeletion() async {
        ProcessAnalytics.reset()
        guard isConfigured else {
            subscriptionStatus = .notSubscribed
            isInFreeTrial = false
            trialExpirationDate = nil
            return
        }

        do {
            _ = try await Purchases.shared.logOut()
        } catch {
            // Compte déjà anonyme ou session expirée — on continue le wipe local.
        }

        subscriptionStatus = .notSubscribed
        isInFreeTrial = false
        trialExpirationDate = nil
    }

    func displayProduct(for plan: SubscriptionBillingPlan) -> SubscriptionProductDisplay {
        switch plan {
        case .monthly:
            return monthlyDisplay ?? .fallback(for: .monthly)
        case .annual:
            return annualDisplay ?? .fallback(for: .annual)
        }
    }

    func trialInfo(for plan: SubscriptionBillingPlan) -> SubscriptionTrialInfo {
        _ = plan
        return SubscriptionTrialInfo(days: 0, isEligible: false)
    }

    func setRetentionTrialOfferActive(_ active: Bool) {
        // Essais gratuits désactivés — ignorer toute activation.
        _ = active
        isRetentionTrialOfferActive = false
        applyRetentionTrialDisplayState()
    }

    /// Compat — redirige vers l’offre lifetime 19 € (plus d’essai annuel).
    func purchaseRetentionTrialAnnual() async throws {
        try await purchaseWinbackLifetime()
    }

    // MARK: - Catalog

    func loadSubscriptions() async {
        isLoading = true
        defer { isLoading = false }

        let ids = [
            SubscriptionConfiguration.monthlyProductID,
            SubscriptionConfiguration.annualProductID
        ]

        guard isConfigured else {
            let storeKitProducts = await fetchDirectStoreKitProducts(ids: ids)
            if storeKitProducts.isEmpty {
                applyFallbackProducts()
            } else {
                applyDirectStoreKitProducts(storeKitProducts)
                await refreshIntroOfferEligibility()
            }
            return
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            let storeProducts = await fetchStoreProductsWithRetry(ids: ids)

            applyDirectStoreProducts(storeProducts)

            let offering = offerings.offering(identifier: SubscriptionConfiguration.defaultOfferingID)
                ?? offerings.current

            monthlyPackage = resolvePackage(
                in: offering,
                productID: SubscriptionConfiguration.monthlyProductID,
                packageID: SubscriptionConfiguration.monthlyPackageID,
                fallbackType: .monthly
            )

            annualPackage = resolvePackage(
                in: offering,
                productID: SubscriptionConfiguration.annualProductID,
                packageID: SubscriptionConfiguration.annualPackageID,
                fallbackType: .annual
            )

            applyPackageDisplay(monthlyPackage, plan: .monthly)
            applyPackageDisplay(annualPackage, plan: .annual)
            await refreshIntroOfferEligibility()
        } catch {
            applyFallbackProducts()
        }
    }

    func loadProducts() async {
        await loadSubscriptions()
    }

    // MARK: - Purchase

    func purchase(plan: SubscriptionBillingPlan = .annual) async throws {
        guard isConfigured else {
            try await purchaseWithStoreKit(plan: plan)
            return
        }

        let package: Package?
        let storeProduct: StoreProduct?

        switch plan {
        case .monthly:
            package = monthlyPackage
            storeProduct = monthlyStoreProductRC
        case .annual:
            package = annualPackage
            storeProduct = annualStoreProductRC
        }

        do {
            let customerInfo: CustomerInfo
            let userCancelled: Bool

            if let package {
                let result = try await Purchases.shared.purchase(package: package)
                customerInfo = result.customerInfo
                userCancelled = result.userCancelled
            } else if let storeProduct {
                let result = try await Purchases.shared.purchase(product: storeProduct)
                customerInfo = result.customerInfo
                userCancelled = result.userCancelled
            } else {
                throw SubscriptionError.productNotFound
            }

            if userCancelled { throw SubscriptionError.userCancelled }
            applyCustomerInfo(customerInfo)
            await scheduleTrialReminderIfNeeded(from: customerInfo)
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            throw SubscriptionError.userCancelled
        } catch let error as SubscriptionError {
            throw error
        } catch {
            throw SubscriptionError.unknown
        }
    }

    func purchase() async throws {
        try await purchase(plan: .annual)
    }

    func purchaseAnnual() async throws {
        try await purchase(plan: .annual)
    }

    func purchaseMonthly() async throws {
        try await purchase(plan: .monthly)
    }

    func purchaseWithPromoOffer() async throws {
        try await purchaseWinbackLifetime()
    }

    /// Achat winback — accès à vie à 19 € (non consommable).
    func purchaseWinbackLifetime() async throws {
        if isConfigured {
            do {
                try await purchaseWinbackWithRevenueCat()
                return
            } catch SubscriptionError.productNotFound {
                // Produit absent du catalogue RC (souvent pas encore ajouté / pas lié) → StoreKit direct.
            } catch SubscriptionError.userCancelled {
                throw SubscriptionError.userCancelled
            }
        }
        try await purchaseWinbackWithStoreKit()
    }

    /// Compat — ancien nom (offre annuelle winback).
    func purchaseWinbackAnnual() async throws {
        try await purchaseWinbackLifetime()
    }

    private func purchaseWinbackWithRevenueCat() async throws {
        let products = (try? await Purchases.shared.products([SubscriptionConfiguration.lifetimeProductID])) ?? []
        guard let lifetime = products.first else {
            throw SubscriptionError.productNotFound
        }

        do {
            let result = try await Purchases.shared.purchase(product: lifetime)
            if result.userCancelled { throw SubscriptionError.userCancelled }
            applyCustomerInfo(result.customerInfo)
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            throw SubscriptionError.userCancelled
        }
    }

    private func purchaseWinbackWithStoreKit() async throws {
        if let lifetime = try? await Product.products(for: [SubscriptionConfiguration.lifetimeProductID]).first {
            let result = try await lifetime.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                if isConfigured {
                    // Remonte le non-consommable vers RC pour l’entitlement `premium`.
                    _ = try? await Purchases.shared.syncPurchases()
                    await checkSubscriptionStatus()
                } else {
                    await checkStoreKitSubscriptionStatus()
                }
                return
            case .userCancelled:
                throw SubscriptionError.userCancelled
            case .pending:
                throw SubscriptionError.pending
            @unknown default:
                throw SubscriptionError.unknown
            }
        }

        throw SubscriptionError.productNotFound
    }

    func restorePurchases() async throws {
        guard isConfigured else {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            guard subscriptionStatus.isActive else { throw SubscriptionError.noActiveSubscription }
            return
        }

        let info = try await Purchases.shared.restorePurchases()
        applyCustomerInfo(info)
        guard subscriptionStatus.isActive else { throw SubscriptionError.noActiveSubscription }
    }

    func checkSubscriptionStatus() async {
        guard isConfigured else {
            await checkStoreKitSubscriptionStatus()
            return
        }

        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            return
        }
    }

    // MARK: - Private

    private func applyCustomerInfo(_ info: CustomerInfo) {
        guard let entitlement = info.entitlements[SubscriptionConfiguration.entitlementID] else {
            subscriptionStatus = .notSubscribed
            isInFreeTrial = false
            trialExpirationDate = nil
            ProcessHomeScreenQuickActions.syncForCurrentUser()
            AppLaunchRouter.shared.flushPendingPresentation()
            return
        }

        if entitlement.isActive {
            isInFreeTrial = entitlement.periodType == .trial
            trialExpirationDate = entitlement.expirationDate

            if entitlement.billingIssueDetectedAt != nil {
                subscriptionStatus = .inBillingRetryPeriod
            } else {
                subscriptionStatus = .subscribed
            }
        } else if entitlement.expirationDate != nil {
            subscriptionStatus = .expired
            isInFreeTrial = false
            trialExpirationDate = nil
        } else {
            subscriptionStatus = .notSubscribed
            isInFreeTrial = false
            trialExpirationDate = nil
        }

        ProcessHomeScreenQuickActions.syncForCurrentUser()
        AppLaunchRouter.shared.flushPendingPresentation()
    }

    private func refreshIntroOfferEligibility() async {
        // Pas d’essai gratuit — ne jamais marquer les produits comme éligibles intro.
        _ = await Product.SubscriptionInfo.isEligibleForIntroOffer(
            for: SubscriptionConfiguration.subscriptionGroupID
        )
        isIntroOfferEligible = false
        isRetentionTrialOfferActive = false

        if let monthlyDisplay {
            self.monthlyDisplay = monthlyDisplay.updatingIntroEligibility(false)
        }
        if let annualDisplay {
            self.annualDisplay = annualDisplay.updatingIntroEligibility(false)
        }

        ProcessHomeScreenQuickActions.syncForCurrentUser()
    }

    private func applyRetentionTrialDisplayState() {
        guard let annualDisplay else { return }
        self.annualDisplay = annualDisplay.updatingIntroEligibility(false)
    }

    private func scheduleTrialReminderIfNeeded(from info: CustomerInfo) async {
        // Essais gratuits désactivés — aucun rappel d’essai.
        _ = info
        PaywallTrialNotificationService.shared.clearTrialNotifications()
    }

    private func fetchStoreProductsWithRetry(ids: [String], attempts: Int = 4) async -> [StoreProduct] {
        var lastProducts: [StoreProduct] = []

        for attempt in 0..<attempts {
            let products = await Purchases.shared.products(ids)
            lastProducts = products
            let found = Set(products.map(\.productIdentifier))

            if ids.allSatisfy({ found.contains($0) }) {
                return products
            }

            if attempt < attempts - 1 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        return lastProducts
    }

    private func fetchDirectStoreKitProducts(ids: [String]) async -> [Product] {
        do {
            return try await Product.products(for: ids)
        } catch {
            return []
        }
    }

    private func applyFallbackProducts() {
        monthlyDisplay = .fallback(for: .monthly)
        annualDisplay = .fallback(for: .annual)
        isIntroOfferEligible = false
        isRetentionTrialOfferActive = false
    }

    private func applyDirectStoreProducts(_ storeProducts: [StoreProduct]) {
        for product in storeProducts {
            switch product.productIdentifier {
            case SubscriptionConfiguration.monthlyProductID:
                monthlyStoreProductRC = product
                monthlyDisplay = makeDisplay(from: product, plan: .monthly)
                monthlyStoreProduct = product.sk2Product
            case SubscriptionConfiguration.annualProductID:
                annualStoreProductRC = product
                annualDisplay = makeDisplay(from: product, plan: .annual)
                annualStoreProduct = product.sk2Product
            default:
                break
            }
        }
    }

    private func applyDirectStoreKitProducts(_ products: [Product]) {
        for product in products {
            switch product.id {
            case SubscriptionConfiguration.monthlyProductID:
                monthlyStoreProduct = product
                monthlyDisplay = makeDisplay(from: product, plan: .monthly)
            case SubscriptionConfiguration.annualProductID:
                annualStoreProduct = product
                annualDisplay = makeDisplay(from: product, plan: .annual)
            default:
                break
            }
        }
    }

    private func resolvePackage(
        in offering: Offering?,
        productID: String,
        packageID: String,
        fallbackType: PackageType
    ) -> Package? {
        guard let offering else { return nil }

        if let match = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == productID }) {
            return match
        }

        if let typed = offering.package(identifier: packageID) {
            return typed
        }

        switch fallbackType {
        case .monthly: return offering.monthly
        case .annual: return offering.annual
        default: return nil
        }
    }

    private func applyPackageDisplay(_ package: Package?, plan: SubscriptionBillingPlan) {
        guard let package else { return }

        let display = makeDisplay(from: package.storeProduct, plan: plan)
        switch plan {
        case .monthly:
            monthlyDisplay = display
            monthlyStoreProductRC = package.storeProduct
            monthlyStoreProduct = package.storeProduct.sk2Product ?? monthlyStoreProduct
        case .annual:
            annualDisplay = display
            annualStoreProductRC = package.storeProduct
            annualStoreProduct = package.storeProduct.sk2Product ?? annualStoreProduct
        }
    }

    private func makeDisplay(from product: StoreProduct, plan: SubscriptionBillingPlan) -> SubscriptionProductDisplay {
        let currency = product.currencyCode
        let trialDays: Int?
        let introEligible: Bool

        switch plan {
        case .monthly:
            trialDays = configuredTrialDays(from: product, plan: .monthly)
            introEligible = trialDays != nil && isIntroOfferEligible
        case .annual:
            trialDays = configuredTrialDays(from: product, plan: .annual)
            introEligible = trialDays != nil && isIntroOfferEligible
        }

        // Paywall FR + storefront USD (sandbox / compte US) → prix marketing EUR, jamais $.
        if SubscriptionConfiguration.shouldUseEuroPaywallDisplay(storeCurrencyCode: currency) {
            return .fallback(
                for: plan,
                freeTrialDays: trialDays,
                isIntroOfferEligible: introEligible
            )
        }

        let price = SubscriptionConfiguration.formatPaywallPrice(
            decimal: product.price as Decimal,
            currencyCode: currency
        )
        let name = product.localizedTitle.isEmpty ? plan.title : product.localizedTitle

        switch plan {
        case .monthly:
            return SubscriptionProductDisplay(
                productID: product.productIdentifier,
                displayName: name,
                displayPrice: price,
                periodLabel: OnboardingCopy.t("par mois", en: "per month"),
                monthlyEquivalentPrice: nil,
                paywallStrikethroughAnnualTotal: SubscriptionConfiguration.paywallStrikethroughAnnualTotal(
                    fromMonthlyPrice: product.price as Decimal,
                    currencyCode: currency
                ),
                freeTrialDays: trialDays,
                isIntroOfferEligible: introEligible
            )
        case .annual:
            let monthly = monthlyEquivalent(from: product)
            return SubscriptionProductDisplay(
                productID: product.productIdentifier,
                displayName: name,
                displayPrice: price,
                periodLabel: OnboardingCopy.t("par an", en: "per year"),
                monthlyEquivalentPrice: monthly,
                paywallStrikethroughAnnualTotal: nil,
                freeTrialDays: trialDays,
                isIntroOfferEligible: introEligible
            )
        }
    }

    private func makeDisplay(from product: Product, plan: SubscriptionBillingPlan) -> SubscriptionProductDisplay {
        let trialDays = trialDays(from: product, plan: plan)
        let introEligible = trialDays != nil && isIntroOfferEligible
        let currency = storeKitCurrencyCode(from: product)

        if SubscriptionConfiguration.shouldUseEuroPaywallDisplay(storeCurrencyCode: currency) {
            return .fallback(
                for: plan,
                freeTrialDays: trialDays,
                isIntroOfferEligible: introEligible
            )
        }

        let price = SubscriptionConfiguration.formatPaywallPrice(
            decimal: product.price,
            currencyCode: currency
        )

        return SubscriptionProductDisplay(
            productID: product.id,
            displayName: product.displayName.isEmpty ? plan.title : product.displayName,
            displayPrice: price,
            periodLabel: plan == .monthly
                ? OnboardingCopy.t("par mois", en: "per month")
                : OnboardingCopy.t("par an", en: "per year"),
            monthlyEquivalentPrice: plan == .annual ? monthlyEquivalent(from: product) : nil,
            paywallStrikethroughAnnualTotal: plan == .monthly
                ? SubscriptionConfiguration.paywallStrikethroughAnnualTotal(
                    fromMonthlyPrice: product.price,
                    currencyCode: currency
                )
                : nil,
            freeTrialDays: trialDays,
            isIntroOfferEligible: introEligible
        )
    }

    private func monthlyEquivalent(from product: StoreProduct) -> String? {
        SubscriptionConfiguration.formatPaywallPrice(
            decimal: (product.price as Decimal) / 12,
            currencyCode: product.currencyCode
        )
    }

    private func monthlyEquivalent(from product: Product) -> String? {
        SubscriptionConfiguration.formatPaywallPrice(
            decimal: product.price / 12,
            currencyCode: storeKitCurrencyCode(from: product)
        )
    }

    private func storeKitCurrencyCode(from product: Product) -> String? {
        if #available(iOS 16.0, *) {
            return product.priceFormatStyle.currencyCode
        }
        return Locale.current.currency?.identifier
    }

    private func configuredTrialDays(from product: StoreProduct, plan: SubscriptionBillingPlan) -> Int? {
        _ = product
        _ = plan
        return nil
    }

    private func trialDays(from product: Product, plan: SubscriptionBillingPlan) -> Int? {
        _ = product
        _ = plan
        return nil
    }

    private func purchaseWithStoreKit(plan: SubscriptionBillingPlan) async throws {
        let product: Product?
        switch plan {
        case .monthly:
            product = monthlyStoreProduct
        case .annual:
            product = annualStoreProduct
        }

        guard let product else { throw SubscriptionError.productNotFound }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            await checkStoreKitSubscriptionStatus()
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    private func checkStoreKitSubscriptionStatus() async {
        let premiumProductIDs: Set<String> = [
            SubscriptionConfiguration.monthlyProductID,
            SubscriptionConfiguration.annualProductID,
            SubscriptionConfiguration.lifetimeProductID
        ]

        var activeExpirationDate: Date?
        var hasActiveEntitlement = false
        var isTrial = false

        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  premiumProductIDs.contains(transaction.productID) else {
                continue
            }

            hasActiveEntitlement = true
            activeExpirationDate = transaction.expirationDate
            isTrial = transaction.offer?.type == .introductory
        }

        isInFreeTrial = isTrial
        trialExpirationDate = isTrial ? activeExpirationDate : nil

        if hasActiveEntitlement {
            subscriptionStatus = .subscribed
        } else {
            subscriptionStatus = .notSubscribed
            trialExpirationDate = nil
        }

        ProcessHomeScreenQuickActions.syncForCurrentUser()
        AppLaunchRouter.shared.flushPendingPresentation()
    }

    private func verified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw SubscriptionError.verificationFailed
        }
    }
}

extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            applyCustomerInfo(customerInfo)
        }
    }
}
