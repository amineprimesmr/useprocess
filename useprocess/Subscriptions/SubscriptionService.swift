import Combine
import Foundation
import RevenueCat
import StoreKit

@MainActor
final class SubscriptionService: NSObject, ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var subscriptionStatus: SubscriptionStatus = .unknown
    @Published private(set) var activeProductIdentifier: String?
    @Published private(set) var isLoading = false
    @Published private(set) var weeklyDisplay: SubscriptionProductDisplay?
    @Published private(set) var monthlyDisplay: SubscriptionProductDisplay?
    @Published private(set) var annualDisplay: SubscriptionProductDisplay?
    @Published private(set) var weeklyStoreProduct: Product?
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
    private var syncedRevenueCatUserID: String?
    private var weeklyPackage: Package?
    private var monthlyPackage: Package?
    private var annualPackage: Package?
    private var weeklyStoreProductRC: StoreProduct?
    private var monthlyStoreProductRC: StoreProduct?
    private var annualStoreProductRC: StoreProduct?

    var pricingVariant: PaywallPricingExperiment.Variant {
        PaywallPricingExperiment.shared.activeVariant
    }

    var shortBillingPlan: SubscriptionBillingPlan {
        pricingVariant.shortPlan
    }

    var hasLiveWeeklyProduct: Bool {
        weeklyPackage != nil || weeklyStoreProductRC != nil || weeklyStoreProduct != nil
    }

    var hasLiveMonthlyProduct: Bool {
        monthlyPackage != nil || monthlyStoreProductRC != nil || monthlyStoreProduct != nil
    }

    var hasLiveAnnualProduct: Bool {
        annualPackage != nil || annualStoreProductRC != nil || annualStoreProduct != nil
    }

    var hasLiveShortPlanProduct: Bool {
        switch shortBillingPlan {
        case .weekly: return hasLiveWeeklyProduct
        case .monthly: return hasLiveMonthlyProduct
        case .annual: return hasLiveAnnualProduct
        }
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

    /// `false` tant que le 1er `checkSubscriptionStatus` / `applyCustomerInfo` n’a pas fini.
    @Published private(set) var hasResolvedInitialSubscriptionStatus = false

    var canPurchase: Bool {
        hasLiveShortPlanProduct || hasLiveAnnualProduct
    }

    func hasLiveProduct(for plan: SubscriptionBillingPlan) -> Bool {
        switch plan {
        case .weekly: return hasLiveWeeklyProduct
        case .monthly: return hasLiveMonthlyProduct
        case .annual: return hasLiveAnnualProduct
        }
    }

    #if DEBUG
    private static let developerPremiumKey = "process.debug.developerPremium.active"

    func activateDeveloperPremiumAccess() {
        UserDefaults.standard.set(true, forKey: Self.developerPremiumKey)
        applyPersistedDeveloperPremiumAccessIfNeeded()
    }

    private func applyPersistedDeveloperPremiumAccessIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Self.developerPremiumKey) else { return }
        subscriptionStatus = .subscribed
        isInFreeTrial = false
        trialExpirationDate = nil
        ProcessMarketingNotificationService.shared.cancelAll()
        AppLaunchRouter.shared.clearSpinPresentation()
        // Defer — syncForCurrentUser reads SubscriptionService.shared (deadlock during init).
        Task { @MainActor in
            ProcessHomeScreenQuickActions.syncForCurrentUser()
        }
    }

    private func clearPersistedDeveloperPremiumAccess() {
        UserDefaults.standard.removeObject(forKey: Self.developerPremiumKey)
    }
    #endif

    private override init() {
        super.init()
        #if DEBUG
        applyPersistedDeveloperPremiumAccessIfNeeded()
        #endif
    }

    // MARK: - Setup

    func configure() {
        guard !isConfigured else { return }
        RevenueCatConfiguration.logConfigurationStatus()

        guard RevenueCatConfiguration.isConfigured, let apiKey = RevenueCatConfiguration.apiKey else {
            // DEBUG only: StoreKit local pour itérer sans dashboard.
            // Release sans clé = zéro tracking RevenueCat (bug prod historique).
            PaywallPricingExperiment.shared.resolve()
            applyFallbackProducts()
            Task {
                await SubscriptionMarketPolicy.refreshStorefrontCountryCode()
                await loadSubscriptions()
                await checkSubscriptionStatus()
            }
            return
        }

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        isConfigured = true
        Task {
            await syncAcquisitionAttributesIfPossible()
        }

        Task {
            PaywallPricingExperiment.shared.resolve()
            await SubscriptionMarketPolicy.refreshStorefrontCountryCode()
            if let uid = AuthUser.current?.uid {
                await syncAppUserID(uid)
            } else {
                await loadSubscriptions()
                await checkSubscriptionStatus()
            }
        }
    }

    /// Attributs RevenueCat pour savoir d’où viennent les ventes (referral / ASA / UTM).
    func syncAcquisitionAttributesIfPossible() async {
        guard isConfigured else { return }
        let attrs = ProcessAcquisitionAttribution.revenueCatAttributes()
        guard !attrs.isEmpty else { return }
        Purchases.shared.attribution.setAttributes(attrs)
    }

    func syncAppUserID(_ userID: String?) async {
        guard isConfigured else { return }

        guard let userID, !userID.isEmpty else {
            syncedRevenueCatUserID = nil
            await logOutAfterAccountDeletion()
            return
        }

        ProcessAnalytics.identify(userId: userID)

        if syncedRevenueCatUserID == userID {
            await checkSubscriptionStatus()
            return
        }

        do {
            _ = try await Purchases.shared.logIn(userID)
            syncedRevenueCatUserID = userID
            await syncAcquisitionAttributesIfPossible()
            await checkSubscriptionStatus()
            await loadSubscriptions()
        } catch {
            return
        }
    }

    /// Délie RevenueCat après suppression de compte (utilisateur anonyme).
    func logOutAfterAccountDeletion() async {
        ProcessAnalytics.reset()
        guard isConfigured else {
            subscriptionStatus = .notSubscribed
            activeProductIdentifier = nil
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
        activeProductIdentifier = nil
        isInFreeTrial = false
        trialExpirationDate = nil
        syncedRevenueCatUserID = nil
        #if DEBUG
        clearPersistedDeveloperPremiumAccess()
        #endif
    }

    /// Prix de l’abonnement actuel — sinon le plan court de la variante A/B.
    var referralRewardDisplayPrice: String {
        if subscriptionStatus.isActive, let id = activeProductIdentifier {
            return displayPrice(forProductID: id)
        }
        return displayProduct(for: shortBillingPlan).displayPrice
    }

    func displayPrice(forProductID id: String) -> String {
        if weeklyDisplay?.productID == id { return weeklyDisplay?.displayPrice ?? fallbackPrice(forProductID: id) }
        if monthlyDisplay?.productID == id { return monthlyDisplay?.displayPrice ?? fallbackPrice(forProductID: id) }
        if annualDisplay?.productID == id { return annualDisplay?.displayPrice ?? fallbackPrice(forProductID: id) }
        return fallbackPrice(forProductID: id)
    }

    private func fallbackPrice(forProductID id: String) -> String {
        switch id {
        case SubscriptionConfiguration.weekly899ProductID:
            return PaywallPricingExperiment.Variant.control.fallbackShortPrice
        case SubscriptionConfiguration.monthly999ProductID, SubscriptionConfiguration.monthlyProductID:
            return PaywallPricingExperiment.Variant.test.fallbackShortPrice
        case SubscriptionConfiguration.annual3499ProductID:
            return PaywallPricingExperiment.Variant.control.fallbackAnnualPrice
        case SubscriptionConfiguration.annual4999ProductID, SubscriptionConfiguration.annualProductID:
            return PaywallPricingExperiment.Variant.test.fallbackAnnualPrice
        case SubscriptionConfiguration.lifetimeProductID:
            return SubscriptionConfiguration.winbackLifetimePrice
        default:
            return displayProduct(for: shortBillingPlan).displayPrice
        }
    }

    func displayProduct(for plan: SubscriptionBillingPlan) -> SubscriptionProductDisplay {
        switch plan {
        case .weekly:
            return weeklyDisplay ?? .fallback(for: .weekly)
        case .monthly:
            return monthlyDisplay ?? .fallback(for: .monthly)
        case .annual:
            return annualDisplay ?? .fallback(for: .annual)
        }
    }

    func trialInfo(for plan: SubscriptionBillingPlan) -> SubscriptionTrialInfo {
        let fromDisplay = displayProduct(for: plan).trialInfo
        if fromDisplay.isActiveOffer { return fromDisplay }

        if SubscriptionConfiguration.supportsFreeTrial(plan),
           isIntroOfferEligible,
           let days = SubscriptionConfiguration.configuredFallbackTrialDays(for: plan) {
            return SubscriptionTrialInfo(days: days, isEligible: true)
        }
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

        await SubscriptionMarketPolicy.refreshStorefrontCountryCode()

        // Prefer async flag load when called from paywall; sync resolve is a no-op if sticky.
        PaywallPricingExperiment.shared.resolve()
        let variant = pricingVariant
        let shortPlan = variant.shortPlan
        let ids = variant.allProductIDs

        // Reset packages hors variante active.
        weeklyPackage = nil
        monthlyPackage = nil
        if shortPlan != .weekly {
            weeklyDisplay = nil
            weeklyStoreProduct = nil
            weeklyStoreProductRC = nil
        }
        if shortPlan != .monthly {
            monthlyDisplay = nil
            monthlyStoreProduct = nil
            monthlyStoreProductRC = nil
        }

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

            let offering = offerings.offering(identifier: variant.offeringID)
                ?? offerings.offering(identifier: SubscriptionConfiguration.defaultOfferingID)
                ?? offerings.current

            switch shortPlan {
            case .weekly:
                weeklyPackage = resolvePackage(
                    in: offering,
                    productID: variant.shortProductID,
                    packageID: SubscriptionConfiguration.weeklyPackageID,
                    fallbackType: .weekly
                )
                applyPackageDisplay(weeklyPackage, plan: .weekly)
            case .monthly:
                monthlyPackage = resolvePackage(
                    in: offering,
                    productID: variant.shortProductID,
                    packageID: SubscriptionConfiguration.monthlyPackageID,
                    fallbackType: .monthly
                )
                applyPackageDisplay(monthlyPackage, plan: .monthly)
            case .annual:
                break
            }

            annualPackage = resolvePackage(
                in: offering,
                productID: variant.annualProductID,
                packageID: SubscriptionConfiguration.annualPackageID,
                fallbackType: .annual
            )
            applyPackageDisplay(annualPackage, plan: .annual)
            await refreshIntroOfferEligibility()

            if !hasLiveShortPlanProduct || !hasLiveAnnualProduct {
                let storeKitProducts = await fetchDirectStoreKitProducts(ids: ids)
                if !storeKitProducts.isEmpty {
                    applyDirectStoreKitProducts(storeKitProducts)
                    await refreshIntroOfferEligibility()
                } else if !hasLiveShortPlanProduct && !hasLiveAnnualProduct {
                    applyFallbackProducts()
                }
            }
        } catch {
            let storeKitProducts = await fetchDirectStoreKitProducts(ids: ids)
            if storeKitProducts.isEmpty {
                applyFallbackProducts()
            } else {
                applyDirectStoreKitProducts(storeKitProducts)
                await refreshIntroOfferEligibility()
            }
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
        case .weekly:
            package = weeklyPackage
            storeProduct = weeklyStoreProductRC
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
            await ReferralService.shared.confirmSubscriptionRewardsIfNeeded()
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
            let purchasedWithRevenueCat = try await attemptRevenueCatWinbackPurchase()
            if purchasedWithRevenueCat { return }
        }
        try await purchaseWinbackWithStoreKit()
    }

    /// `true` si l’achat RC a réussi, `false` si le produit lifetime est absent du catalogue RC.
    private func attemptRevenueCatWinbackPurchase() async throws -> Bool {
        let products = await Purchases.shared.products([SubscriptionConfiguration.lifetimeProductID])
        guard let lifetime = products.first else { return false }

        do {
            let result = try await Purchases.shared.purchase(product: lifetime)
            if result.userCancelled { throw SubscriptionError.userCancelled }
            applyCustomerInfo(result.customerInfo)
            await ReferralService.shared.confirmSubscriptionRewardsIfNeeded()
            return true
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            throw SubscriptionError.userCancelled
        } catch let error as SubscriptionError {
            throw error
        } catch {
            throw SubscriptionError.unknown
        }
    }

    /// Compat — ancien nom (offre annuelle winback).
    func purchaseWinbackAnnual() async throws {
        try await purchaseWinbackLifetime()
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
                await ReferralService.shared.confirmSubscriptionRewardsIfNeeded()
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
        await ReferralService.shared.confirmSubscriptionRewardsIfNeeded()
    }

    func checkSubscriptionStatus() async {
        guard isConfigured else {
            await checkStoreKitSubscriptionStatus()
            #if DEBUG
            applyPersistedDeveloperPremiumAccessIfNeeded()
            #endif
            markSubscriptionStatusResolvedAndFlushRetention()
            return
        }

        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            #if DEBUG
            applyPersistedDeveloperPremiumAccessIfNeeded()
            #endif
            markSubscriptionStatusResolvedAndFlushRetention()
        }
    }

    private func markSubscriptionStatusResolvedAndFlushRetention() {
        hasResolvedInitialSubscriptionStatus = true
        AppLaunchRouter.shared.flushPendingPresentationIfReady()
    }

    // MARK: - Private

    private func applyCustomerInfo(_ info: CustomerInfo) {
        guard let entitlement = info.entitlements[SubscriptionConfiguration.entitlementID] else {
            subscriptionStatus = .notSubscribed
            activeProductIdentifier = nil
            isInFreeTrial = false
            trialExpirationDate = nil
            ProcessHomeScreenQuickActions.syncForCurrentUser()
            #if DEBUG
            applyPersistedDeveloperPremiumAccessIfNeeded()
            #endif
            markSubscriptionStatusResolvedAndFlushRetention()
            return
        }

        if entitlement.isActive {
            isInFreeTrial = entitlement.periodType == .trial
            trialExpirationDate = entitlement.expirationDate
            activeProductIdentifier = entitlement.productIdentifier

            if entitlement.billingIssueDetectedAt != nil {
                subscriptionStatus = .inBillingRetryPeriod
            } else {
                subscriptionStatus = .subscribed
            }
            #if DEBUG
            clearPersistedDeveloperPremiumAccess()
            #endif
            ProcessMarketingNotificationService.shared.cancelAll()
            AppLaunchRouter.shared.clearSpinPresentation()
        } else if entitlement.expirationDate != nil {
            subscriptionStatus = .expired
            activeProductIdentifier = nil
            isInFreeTrial = false
            trialExpirationDate = nil
        } else {
            subscriptionStatus = .notSubscribed
            activeProductIdentifier = nil
            isInFreeTrial = false
            trialExpirationDate = nil
        }

        #if DEBUG
        if !subscriptionStatus.isActive {
            applyPersistedDeveloperPremiumAccessIfNeeded()
        }
        #endif

        ProcessHomeScreenQuickActions.syncForCurrentUser()
        markSubscriptionStatusResolvedAndFlushRetention()
    }

    private func refreshIntroOfferEligibility() async {
        await SubscriptionMarketPolicy.refreshStorefrontCountryCode()

        let groupID = SubscriptionConfiguration.subscriptionGroupID
        let storeEligible = await Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupID)
        let marketAllows = SubscriptionMarketPolicy.allowsIntroductoryFreeTrial
        isIntroOfferEligible = storeEligible && marketAllows
        isRetentionTrialOfferActive = false

        if let weeklyDisplay {
            self.weeklyDisplay = weeklyDisplay.updatingIntroEligibility(false)
        }
        if let monthlyDisplay {
            self.monthlyDisplay = monthlyDisplay.updatingIntroEligibility(false)
        }
        if var annualDisplay {
            let trialAllowed = SubscriptionConfiguration.supportsFreeTrial(.annual)
            let eligible = isIntroOfferEligible && trialAllowed
            if eligible, annualDisplay.freeTrialDays == nil,
               let fallbackDays = SubscriptionConfiguration.configuredFallbackTrialDays(for: .annual) {
                annualDisplay = annualDisplay.updatingTrial(days: fallbackDays, eligible: true)
            } else {
                annualDisplay = annualDisplay.updatingIntroEligibility(eligible)
            }
            self.annualDisplay = annualDisplay
        }

        ProcessHomeScreenQuickActions.syncForCurrentUser()
    }

    private func applyRetentionTrialDisplayState() {
        guard var annualDisplay else { return }
        let eligible = isIntroOfferEligible && SubscriptionConfiguration.supportsFreeTrial(.annual)
        if eligible, annualDisplay.freeTrialDays == nil,
           let fallbackDays = SubscriptionConfiguration.configuredFallbackTrialDays(for: .annual) {
            annualDisplay = annualDisplay.updatingTrial(days: fallbackDays, eligible: true)
        } else {
            annualDisplay = annualDisplay.updatingIntroEligibility(eligible)
        }
        self.annualDisplay = annualDisplay
    }

    private func scheduleTrialReminderIfNeeded(from info: CustomerInfo) async {
        guard SubscriptionMarketPolicy.allowsIntroductoryFreeTrial,
              let entitlement = info.entitlements[SubscriptionConfiguration.entitlementID],
              entitlement.isActive,
              entitlement.periodType == .trial,
              let expiration = entitlement.expirationDate else { return }
        await PaywallTrialNotificationService.shared.scheduleTrialEndingReminder(trialEndDate: expiration)
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
        let short = shortBillingPlan
        switch short {
        case .weekly:
            weeklyDisplay = .fallback(for: .weekly)
            monthlyDisplay = nil
        case .monthly:
            monthlyDisplay = .fallback(for: .monthly)
            weeklyDisplay = nil
        case .annual:
            break
        }

        let annualTrialDays = SubscriptionConfiguration.configuredFallbackTrialDays(for: .annual)
        let annualIntroEligible = SubscriptionMarketPolicy.allowsIntroductoryFreeTrial && annualTrialDays != nil
        annualDisplay = .fallback(
            for: .annual,
            freeTrialDays: annualTrialDays,
            isIntroOfferEligible: annualIntroEligible
        )
        isIntroOfferEligible = annualIntroEligible
        isRetentionTrialOfferActive = false
    }

    private func applyDirectStoreProducts(_ storeProducts: [StoreProduct]) {
        let variant = pricingVariant
        for product in storeProducts {
            let id = product.productIdentifier
            if id == variant.shortProductID {
                switch variant.shortPlan {
                case .weekly:
                    weeklyStoreProductRC = product
                    weeklyDisplay = makeDisplay(from: product, plan: .weekly)
                    weeklyStoreProduct = product.sk2Product
                case .monthly:
                    monthlyStoreProductRC = product
                    monthlyDisplay = makeDisplay(from: product, plan: .monthly)
                    monthlyStoreProduct = product.sk2Product
                case .annual:
                    break
                }
            } else if id == variant.annualProductID {
                annualStoreProductRC = product
                annualDisplay = makeDisplay(from: product, plan: .annual)
                annualStoreProduct = product.sk2Product
            }
        }
    }

    private func applyDirectStoreKitProducts(_ products: [Product]) {
        let variant = pricingVariant
        for product in products {
            if product.id == variant.shortProductID {
                switch variant.shortPlan {
                case .weekly:
                    weeklyStoreProduct = product
                    weeklyDisplay = makeDisplay(from: product, plan: .weekly)
                case .monthly:
                    monthlyStoreProduct = product
                    monthlyDisplay = makeDisplay(from: product, plan: .monthly)
                case .annual:
                    break
                }
            } else if product.id == variant.annualProductID {
                annualStoreProduct = product
                annualDisplay = makeDisplay(from: product, plan: .annual)
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
        case .weekly: return offering.weekly
        case .monthly: return offering.monthly
        case .annual: return offering.annual
        default: return nil
        }
    }

    private func applyPackageDisplay(_ package: Package?, plan: SubscriptionBillingPlan) {
        guard let package else { return }

        let display = makeDisplay(from: package.storeProduct, plan: plan)
        switch plan {
        case .weekly:
            weeklyDisplay = display
            weeklyStoreProductRC = package.storeProduct
            weeklyStoreProduct = package.storeProduct.sk2Product ?? weeklyStoreProduct
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

        trialDays = configuredTrialDays(from: product, plan: plan)
        introEligible = trialDays != nil && isIntroOfferEligible

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
        case .weekly:
            return SubscriptionProductDisplay(
                productID: product.productIdentifier,
                displayName: name,
                displayPrice: price,
                periodLabel: OnboardingCopy.t("par semaine", en: "per week"),
                monthlyEquivalentPrice: nil,
                paywallStrikethroughAnnualTotal: SubscriptionConfiguration.paywallStrikethroughAnnualTotal(
                    fromShortPlanPrice: product.price as Decimal,
                    shortPlan: .weekly,
                    currencyCode: currency
                ),
                freeTrialDays: trialDays,
                isIntroOfferEligible: introEligible
            )
        case .monthly:
            return SubscriptionProductDisplay(
                productID: product.productIdentifier,
                displayName: name,
                displayPrice: price,
                periodLabel: OnboardingCopy.t("par mois", en: "per month"),
                monthlyEquivalentPrice: nil,
                paywallStrikethroughAnnualTotal: SubscriptionConfiguration.paywallStrikethroughAnnualTotal(
                    fromShortPlanPrice: product.price as Decimal,
                    shortPlan: .monthly,
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

        let periodLabel: String
        switch plan {
        case .weekly: periodLabel = OnboardingCopy.t("par semaine", en: "per week")
        case .monthly: periodLabel = OnboardingCopy.t("par mois", en: "per month")
        case .annual: periodLabel = OnboardingCopy.t("par an", en: "per year")
        }

        return SubscriptionProductDisplay(
            productID: product.id,
            displayName: product.displayName.isEmpty ? plan.title : product.displayName,
            displayPrice: price,
            periodLabel: periodLabel,
            monthlyEquivalentPrice: plan == .annual ? monthlyEquivalent(from: product) : nil,
            paywallStrikethroughAnnualTotal: (plan == .weekly || plan == .monthly)
                ? SubscriptionConfiguration.paywallStrikethroughAnnualTotal(
                    fromShortPlanPrice: product.price,
                    shortPlan: plan,
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
        guard SubscriptionConfiguration.supportsFreeTrial(plan) else { return nil }
        return SubscriptionIntroOfferParser.trialDays(from: product)
            ?? SubscriptionConfiguration.configuredFallbackTrialDays(for: plan)
    }

    private func trialDays(from product: Product, plan: SubscriptionBillingPlan) -> Int? {
        guard SubscriptionConfiguration.supportsFreeTrial(plan) else { return nil }
        return SubscriptionIntroOfferParser.trialDays(from: product)
            ?? SubscriptionConfiguration.configuredFallbackTrialDays(for: plan)
    }

    private func purchaseWithStoreKit(plan: SubscriptionBillingPlan) async throws {
        let product: Product?
        switch plan {
        case .weekly:
            product = weeklyStoreProduct
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
            await ReferralService.shared.confirmSubscriptionRewardsIfNeeded()
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    private func checkStoreKitSubscriptionStatus() async {
        let premiumProductIDs = SubscriptionConfiguration.allPremiumProductIDs

        var activeExpirationDate: Date?
        var hasActiveEntitlement = false
        var isTrial = false
        var activeProductID: String?

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  premiumProductIDs.contains(transaction.productID) else {
                continue
            }

            hasActiveEntitlement = true
            activeExpirationDate = transaction.expirationDate
            isTrial = transaction.offer?.type == .introductory
            activeProductID = transaction.productID
        }

        isInFreeTrial = isTrial
        trialExpirationDate = isTrial ? activeExpirationDate : nil
        activeProductIdentifier = hasActiveEntitlement ? activeProductID : nil

        if hasActiveEntitlement {
            subscriptionStatus = .subscribed
            #if DEBUG
            clearPersistedDeveloperPremiumAccess()
            #endif
            AppLaunchRouter.shared.clearSpinPresentation()
        } else {
            subscriptionStatus = .notSubscribed
            trialExpirationDate = nil
            #if DEBUG
            applyPersistedDeveloperPremiumAccessIfNeeded()
            #endif
        }

        ProcessHomeScreenQuickActions.syncForCurrentUser()
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
