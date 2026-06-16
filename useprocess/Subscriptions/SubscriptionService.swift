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

    #if DEBUG
    private var usesSimulatedPurchases: Bool { !RevenueCatConfiguration.isConfigured }
    #else
    private var usesSimulatedPurchases: Bool { false }
    #endif

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
        hasLiveMonthlyProduct || hasLiveAnnualProduct || usesSimulatedPurchases
    }

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func configure() {
        guard !isConfigured else { return }
        guard RevenueCatConfiguration.isConfigured, let apiKey = RevenueCatConfiguration.apiKey else {
            applyFallbackProducts()
            subscriptionStatus = usesSimulatedPurchases ? .notSubscribed : .notSubscribed
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #endif

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
            print("[SubscriptionService] logIn: \(error.localizedDescription)")
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

            logCatalogDiagnostics(
                offering: offering,
                storeProducts: storeProducts
            )
        } catch {
            print("[SubscriptionService] offerings: \(error.localizedDescription)")
            applyFallbackProducts()
        }
    }

    func loadProducts() async {
        await loadSubscriptions()
    }

    // MARK: - Purchase

    func purchase(plan: SubscriptionBillingPlan = .annual) async throws {
        if usesSimulatedPurchases {
            subscriptionStatus = .subscribed
            return
        }

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
        if usesSimulatedPurchases {
            subscriptionStatus = .subscribed
            return
        }

        guard isConfigured else { throw SubscriptionError.notConfigured }

        let info = try await Purchases.shared.restorePurchases()
        applyCustomerInfo(info)
        guard subscriptionStatus.isActive else { throw SubscriptionError.noActiveSubscription }
    }

    func checkSubscriptionStatus() async {
        if usesSimulatedPurchases { return }

        guard isConfigured else {
            subscriptionStatus = .notSubscribed
            return
        }

        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            print("[SubscriptionService] customerInfo: \(error.localizedDescription)")
        }
    }

    #if DEBUG
    func forcePremiumForDevelopment() {
        subscriptionStatus = .subscribed
    }

    func disableDevMode() {
        subscriptionStatus = .notSubscribed
        Task { await checkSubscriptionStatus() }
    }
    #endif

    // MARK: - Private

    private func applyCustomerInfo(_ info: CustomerInfo) {
        guard let entitlement = info.entitlements[SubscriptionConfiguration.entitlementID] else {
            subscriptionStatus = .notSubscribed
            return
        }

        if entitlement.isActive {
            if entitlement.billingIssueDetectedAt != nil {
                subscriptionStatus = .inBillingRetryPeriod
            } else if entitlement.periodType == .trial || entitlement.willRenew {
                subscriptionStatus = .subscribed
            } else {
                subscriptionStatus = .subscribed
            }
        } else if entitlement.expirationDate != nil {
            subscriptionStatus = .expired
        } else {
            subscriptionStatus = .notSubscribed
        }
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
                print("[SubscriptionService] Produits manquants (tentative \(attempt + 1)/\(attempts)) — nouvel essai dans 3 s…")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        return lastProducts
    }

    private func applyFallbackProducts() {
        monthlyDisplay = .fallback(for: .monthly)
        annualDisplay = .fallback(for: .annual)
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

    private func logCatalogDiagnostics(offering: Offering?, storeProducts: [StoreProduct]) {
        let foundIDs = Set(storeProducts.map(\.productIdentifier))
        let expected = [
            SubscriptionConfiguration.monthlyProductID,
            SubscriptionConfiguration.annualProductID
        ]

        for id in expected where !foundIDs.contains(id) {
            print("[SubscriptionService] ⚠️ StoreKit n'a pas renvoyé le produit « \(id) » — vérifie App Store Connect (Ready to Submit + lié à la version) et la propagation (jusqu'à 24 h).")
        }

        if let offering {
            let packageIDs = offering.availablePackages.map(\.storeProduct.productIdentifier)
            print("[SubscriptionService] Offering « \(offering.identifier) » packages: \(packageIDs.joined(separator: ", "))")
        }

        for package in offering?.availablePackages ?? [] where package.storeProduct.productIdentifier != SubscriptionConfiguration.monthlyProductID
            && package.identifier == SubscriptionConfiguration.monthlyPackageID {
            print("[SubscriptionService] ⚠️ Package mensuel RC pointe vers « \(package.storeProduct.productIdentifier) » au lieu de « \(SubscriptionConfiguration.monthlyProductID) » — corrige dans RevenueCat.")
        }
    }

    private func makeDisplay(from product: StoreProduct, plan: SubscriptionBillingPlan) -> SubscriptionProductDisplay {
        let price = product.localizedPriceString
        let name = product.localizedTitle.isEmpty ? plan.title : product.localizedTitle

        switch plan {
        case .monthly:
            return SubscriptionProductDisplay(
                productID: product.productIdentifier,
                displayName: name,
                displayPrice: price,
                periodLabel: "par mois",
                monthlyEquivalentPrice: nil
            )
        case .annual:
            let monthly = monthlyEquivalent(from: product)
            return SubscriptionProductDisplay(
                productID: product.productIdentifier,
                displayName: name,
                displayPrice: price,
                periodLabel: "par an",
                monthlyEquivalentPrice: monthly
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
