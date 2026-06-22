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

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func configure() {
        guard !isConfigured else { return }
        guard RevenueCatConfiguration.isConfigured, let apiKey = RevenueCatConfiguration.apiKey else {
            applyFallbackProducts()
            subscriptionStatus = .notSubscribed
            return
        }

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
        guard isConfigured, let userID, !userID.isEmpty else { return }
        do {
            _ = try await Purchases.shared.logIn(userID)
            await checkSubscriptionStatus()
        } catch {
            return
        }
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
        displayProduct(for: plan).trialInfo
    }

    // MARK: - Catalog

    func loadSubscriptions() async {
        isLoading = true
        defer { isLoading = false }

        guard isConfigured else {
            applyFallbackProducts()
            return
        }

        let ids = [
            SubscriptionConfiguration.monthlyProductID,
            SubscriptionConfiguration.annualProductID
        ]

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
        guard isConfigured else { throw SubscriptionError.notConfigured }

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
        try await purchase(plan: .annual)
    }

    func restorePurchases() async throws {
        guard isConfigured else { throw SubscriptionError.notConfigured }

        let info = try await Purchases.shared.restorePurchases()
        applyCustomerInfo(info)
        guard subscriptionStatus.isActive else { throw SubscriptionError.noActiveSubscription }
    }

    func checkSubscriptionStatus() async {
        guard isConfigured else {
            subscriptionStatus = .notSubscribed
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
    }

    private func refreshIntroOfferEligibility() async {
        let groupID = SubscriptionConfiguration.subscriptionGroupID
        let eligible = await Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupID)
        isIntroOfferEligible = eligible

        if let monthlyDisplay {
            self.monthlyDisplay = monthlyDisplay.updatingIntroEligibility(false)
        }
        if let annualDisplay {
            self.annualDisplay = annualDisplay.updatingIntroEligibility(eligible)
        }
    }

    private func scheduleTrialReminderIfNeeded(from info: CustomerInfo) async {
        guard let entitlement = info.entitlements[SubscriptionConfiguration.entitlementID],
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

    private func applyFallbackProducts() {
        monthlyDisplay = .fallback(for: .monthly)
        annualDisplay = .fallback(for: .annual)
        isIntroOfferEligible = true
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
        let price = product.localizedPriceString
        let name = product.localizedTitle.isEmpty ? plan.title : product.localizedTitle
        let trialDays: Int?
        let introEligible: Bool

        switch plan {
        case .monthly:
            trialDays = SubscriptionIntroOfferParser.trialDays(from: product)
            introEligible = trialDays != nil && isIntroOfferEligible
        case .annual:
            trialDays = SubscriptionIntroOfferParser.trialDays(from: product)
                ?? SubscriptionConfiguration.freeTrialDays
            introEligible = isIntroOfferEligible
        }

        switch plan {
        case .monthly:
            return SubscriptionProductDisplay(
                productID: product.productIdentifier,
                displayName: name,
                displayPrice: price,
                periodLabel: "par mois",
                monthlyEquivalentPrice: nil,
                freeTrialDays: trialDays,
                isIntroOfferEligible: introEligible
            )
        case .annual:
            let monthly = monthlyEquivalent(from: product)
            return SubscriptionProductDisplay(
                productID: product.productIdentifier,
                displayName: name,
                displayPrice: price,
                periodLabel: "par an",
                monthlyEquivalentPrice: monthly,
                freeTrialDays: trialDays,
                isIntroOfferEligible: introEligible
            )
        }
    }

    private func monthlyEquivalent(from product: StoreProduct) -> String? {
        let monthly = product.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatter?.locale ?? Locale(identifier: "fr_FR")
        return formatter.string(from: monthly as NSDecimalNumber)
    }
}

extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            applyCustomerInfo(customerInfo)
        }
    }
}
