import Combine
import SwiftUI
import HealthKit
import UserNotifications
import CoreLocation
import StoreKit
import FirebaseAuth

// MARK: - Data

typealias DataManager = DailyDataManager

@MainActor
final class DailyDataManager: ObservableObject {
    static let shared = DailyDataManager()

    @Published var isLoadingData = false
    @Published var currentRecoveryData: DailyRecoveryData?
    @Published var currentEffortData: DailyEffortData?
    @Published var currentSleepData: DailySleepData?
    @Published var currentActivityData: DailyActivityData?
    @Published var currentHealthMetricsData: DailyHealthMetricsData?
    @Published var currentNutritionData: DailyNutritionData?

    private init() {}

    func getDataForDate(_ date: Date) async {
        isLoadingData = true
        defer { isLoadingData = false }
        await HealthManager.shared.syncHealthDataForDate(date)
        await updateCurrentDayData(with: HealthManager.shared)
    }

    func getCurrentRecoveryData() -> DailyRecoveryData? { currentRecoveryData }
    func getCurrentEffortData() -> DailyEffortData? { currentEffortData }
    func getCurrentSleepData() -> DailySleepData? { currentSleepData }

    func updateCurrentDayData(with healthManager: HealthManager) async {
        let snapshot = healthManager.todaySnapshot
        currentRecoveryData = snapshot.recovery
        currentEffortData = snapshot.effort
        currentSleepData = snapshot.sleep
        currentActivityData = snapshot.activity
        currentHealthMetricsData = snapshot.vitals
        currentNutritionData = snapshot.nutrition
    }
}

// MARK: - Auth

private enum AuthKeys {
    private static let prefix = (Bundle.main.bundleIdentifier ?? "useprocess") + "."

    static var completed: String { prefix + "onboarding.completed" }
}

@MainActor
final class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()

    @Published var isAuthenticated = false
    @Published var isInOnboarding = false
    @Published var hasCompletedOnboarding = false
    @Published var isLoading = false
    @Published private(set) var isDemoSession = false

    static let demoUserID = OnboardingWelcomeAuth.demoUserID

    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    func activateDemoSession() {
        isDemoSession = true
        isAuthenticated = true
    }

    func clearDemoSession() {
        isDemoSession = false
    }

    func startOnboarding() {
        isInOnboarding = true
        hasCompletedOnboarding = false
    }

    func completeOnboarding() {
        isInOnboarding = false
        hasCompletedOnboarding = true
        isAuthenticated = Auth.auth().currentUser != nil || isDemoSession
        isLoading = false
        UserDefaults.standard.set(true, forKey: UserScopedStorage.key("onboarding.completed", userId: Auth.auth().currentUser?.uid))
    }

    func exitOnboarding() {
        isInOnboarding = false
    }

    override private init() {
        super.init()
        hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: UserScopedStorage.key("onboarding.completed", userId: Auth.auth().currentUser?.uid)
        )

        guard AppConfiguration.firebaseConfigured else { return }

        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                if self.isDemoSession {
                    self.isAuthenticated = true
                    return
                }
                self.isAuthenticated = user != nil
                if user != nil {
                    await UnifiedProfileService.shared.loadProfile()
                } else {
                    UnifiedProfileService.shared.clearLocalProfile()
                }
            }
        }
        isAuthenticated = Auth.auth().currentUser != nil || isDemoSession
    }

    func resetSession() {
        hasCompletedOnboarding = false
        isInOnboarding = false
        isAuthenticated = false
        isDemoSession = false
        UserDefaults.standard.set(false, forKey: UserScopedStorage.key("onboarding.completed", userId: Auth.auth().currentUser?.uid))
        if AppConfiguration.firebaseConfigured {
            try? Auth.auth().signOut()
        }
        UnifiedProfileService.shared.clearLocalProfile()
    }
}

// MARK: - Profile

enum UnifiedProfileError: Error {
    case notAuthenticated
}

@MainActor
final class UnifiedProfileService: ObservableObject {
    static let shared = UnifiedProfileService()

    @Published var currentProfile: UnifiedUserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isAuthenticated = false

    private init() {}

    func clearLocalProfile() {
        currentProfile = nil
        isAuthenticated = false
        error = nil
    }

    func loadProfile() async {
        if AuthenticationManager.shared.isDemoSession {
            if currentProfile == nil {
                currentProfile = UnifiedUserProfile(
                    userId: "demo-user",
                    firstName: "Demo"
                )
            }
            isAuthenticated = true
            return
        }

        guard AppConfiguration.firebaseConfigured,
              let userId = Auth.auth().currentUser?.uid else {
            if currentProfile == nil {
                currentProfile = UnifiedUserProfile(
                    userId: "local-user",
                    firstName: "Process"
                )
            }
            isAuthenticated = currentProfile != nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if let profile = try await FirebaseProfileRepository.shared.loadProfile(userId: userId) {
                currentProfile = profile
            } else if currentProfile == nil {
                currentProfile = UnifiedUserProfile(
                    userId: userId,
                    firstName: Auth.auth().currentUser?.displayName ?? "",
                    email: Auth.auth().currentUser?.email
                )
            }
            isAuthenticated = true
            error = nil
        } catch {
            self.error = error
            if currentProfile == nil {
                currentProfile = UnifiedUserProfile(
                    userId: userId,
                    firstName: Auth.auth().currentUser?.displayName ?? "Process",
                    email: Auth.auth().currentUser?.email
                )
            }
            isAuthenticated = true
        }
    }

    func saveProfile(_ profile: UnifiedUserProfile) async throws {
        currentProfile = profile
        isAuthenticated = true
        error = nil

        guard AppConfiguration.firebaseConfigured,
              !AuthenticationManager.shared.isDemoSession,
              Auth.auth().currentUser != nil else {
            return
        }

        try await FirebaseProfileRepository.shared.saveProfile(profile)
    }

    func updatePreferences(_ preferences: UserPreferences) async throws {
        guard var profile = currentProfile else { return }
        profile.preferences = preferences
        try await saveProfile(profile)
    }
}

// MARK: - Permissions

@MainActor
final class PermissionsManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = PermissionsManager()

    @Published private(set) var notificationsGranted = false
    @Published private(set) var locationGranted = false

    private let locationManager = CLLocationManager()

    override private init() {
        super.init()
        locationManager.delegate = self
    }

    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            notificationsGranted = granted
            return granted
        } catch {
            return false
        }
    }

    func requestLocationPermission() async -> Bool {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationGranted = true
            return true
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            try? await Task.sleep(for: .milliseconds(500))
            let updated = locationManager.authorizationStatus
            locationGranted = updated == .authorizedWhenInUse || updated == .authorizedAlways
            return locationGranted
        default:
            return false
        }
    }

    func requestMotionPermission() async -> Bool {
        // CoreMotion n'affiche pas de popup — Info.plist NSMotionUsageDescription suffit.
        true
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            locationGranted = status == .authorizedWhenInUse || status == .authorizedAlways
        }
    }
}

// MARK: - Subscriptions (visuel)

enum SubscriptionError: LocalizedError {
    case userNotAuthenticated
    case productNotFound
    case offerNotFound
    case verificationFailed
    case userCancelled
    case pending
    case noActiveSubscription
    case unknown

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated: return "Vous devez être connecté pour acheter un abonnement"
        case .productNotFound: return "Produit d'abonnement non trouvé"
        case .offerNotFound: return "Offre promotionnelle non disponible"
        case .verificationFailed: return "Échec de vérification de la transaction"
        case .userCancelled: return "Achat annulé"
        case .pending: return "Achat en attente de validation"
        case .noActiveSubscription: return "Aucun abonnement actif"
        case .unknown: return "Erreur inconnue"
        }
    }
}

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var isLoading = false
    @Published var annualProduct: Product?
    /// Achats simulés tant que StoreKit n'est pas branché.
    private let usesSimulatedPurchases = true

    enum SubscriptionStatus: Equatable {
        case unknown, notSubscribed, subscribed, expired, inGracePeriod, inBillingRetryPeriod
        var isActive: Bool {
            switch self {
            case .subscribed, .inGracePeriod, .inBillingRetryPeriod: return true
            default: return false
            }
        }
    }

    var canPurchase: Bool { annualProduct != nil || usesSimulatedPurchases }

    func loadSubscriptions() async { isLoading = false }
    func loadProducts() async { await loadSubscriptions() }
    func checkSubscriptionStatus() async {}
    func purchase() async throws {
        subscriptionStatus = .subscribed
    }
    func purchaseWithPromoOffer() async throws {
        subscriptionStatus = .subscribed
    }
    func purchaseAnnual() async throws { try await purchase() }
    func restorePurchases() async throws {
        subscriptionStatus = .subscribed
    }
    func forcePremiumForDevelopment() {
        subscriptionStatus = .subscribed
    }
    func disableDevMode() {
        subscriptionStatus = .notSubscribed
    }
}

@MainActor
final class PaywallExitNotificationService {
    static let shared = PaywallExitNotificationService()
    func scheduleExitNotification(hasPurchased: Bool) async {}
}

enum OnboardingError: Error, LocalizedError {
    case notAuthenticated
    case healthKitNotAvailable
    case dataCollectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Utilisateur non authentifié"
        case .healthKitNotAvailable: return "HealthKit non disponible"
        case .dataCollectionFailed(let message): return "Erreur collecte données: \(message)"
        }
    }
}

@MainActor
final class OnboardingService: ObservableObject {
    static let shared = OnboardingService()
    @Published var isOnboardingComplete = false
    @Published var isLoading = false

    func completeOnboarding() async throws {
        isOnboardingComplete = true
    }
}

@MainActor
final class ReferralService {
    static let shared = ReferralService()
    func registerReferral(referralCode: String, referredUserId: String) async throws {}
}

// MARK: - Watch (visuel)

@MainActor
final class AppleWatchService: ObservableObject {
    static let shared = AppleWatchService()

    @Published var isPaired = false
    @Published var isReachable = false
    @Published var isWatchPaired = false
    @Published var isWatchConnected = false

    func refreshWatchConnectionStatus() {
        Task { await HealthManager.shared.refreshConnectedSources() }
    }

    func updateFromHealthSources(_ sources: [String]) {
        let hasWatch = sources.contains { $0.localizedCaseInsensitiveContains("watch") }
        isWatchPaired = hasWatch
        isWatchConnected = hasWatch
        isPaired = hasWatch
        isReachable = hasWatch
        WatchAvailabilityManager.shared.isWatchAvailable = hasWatch
    }
}

@MainActor
final class WatchAvailabilityManager: ObservableObject {
    static let shared = WatchAvailabilityManager()
    @Published var isWatchAvailable = false
}

// MARK: - Plan models (minimal)

struct UserPattern: Codable, Identifiable {
    let id: String
    var name: String = ""
}
