import Combine
import SwiftUI
import HealthKit
import UserNotifications
import StoreKit
import FirebaseAuth
import AuthenticationServices

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

enum AccountDeletionError: LocalizedError {
    case notSignedIn
    case cancelled
    case remoteDeletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Aucune session active."
        case .cancelled:
            return "Suppression annulée."
        case .remoteDeletionFailed(let message):
            return message
        }
    }
}

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

    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    private var firebaseAuthReady: Bool {
        FirebaseBootstrap.isConfigured
    }

    private var currentFirebaseUser: User? {
        guard firebaseAuthReady else { return nil }
        return Auth.auth().currentUser
    }

    func startOnboarding() {
        isInOnboarding = true
        hasCompletedOnboarding = false
    }

    func completeOnboarding() {
        isInOnboarding = false
        hasCompletedOnboarding = true
        let user = currentFirebaseUser
        isAuthenticated = user != nil
        isLoading = false
        UserDefaults.standard.set(true, forKey: UserScopedStorage.key("onboarding.completed", userId: user?.uid))
    }

    func exitOnboarding() {
        isInOnboarding = false
    }

    override private init() {
        super.init()
        FirebaseBootstrap.configure()
        guard firebaseAuthReady else {
            hasCompletedOnboarding = UserDefaults.standard.bool(
                forKey: UserScopedStorage.key("onboarding.completed", userId: nil)
            )
            return
        }

        hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: UserScopedStorage.key("onboarding.completed", userId: currentFirebaseUser?.uid)
        )

        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                guard !AppSession.shared.isAccountWipeInProgress else { return }
                self.isAuthenticated = user != nil
                if user != nil {
                    await UnifiedProfileService.shared.loadProfile()
                } else {
                    UnifiedProfileService.shared.clearLocalProfile()
                }
            }
        }
        isAuthenticated = currentFirebaseUser != nil
    }

    func resetSession() {
        hasCompletedOnboarding = false
        isInOnboarding = false
        isAuthenticated = false
        let uid = currentFirebaseUser?.uid
        UserDefaults.standard.set(false, forKey: UserScopedStorage.key("onboarding.completed", userId: uid))
        if firebaseAuthReady {
            try? Auth.auth().signOut()
        }
        UnifiedProfileService.shared.clearLocalProfile()
    }

    func deleteRemoteAccount() async throws {
        guard firebaseAuthReady else { return }

        guard currentFirebaseUser != nil else {
            throw AccountDeletionError.notSignedIn
        }

        // La Cloud Function utilise l'Admin SDK : pas besoin de réauth Apple.
        // (La réauth échouait systématiquement avec ASAuthorizationError 1001.)
        do {
            try await AccountDeletionRemoteService.deleteViaCloudFunction()
            #if DEBUG
            print("[Auth] Compte supprimé via Cloud Function")
            #endif
            return
        } catch {
            #if DEBUG
            print("[Auth] Cloud delete failed, trying client SDK: \(error.localizedDescription)")
            #endif
        }

        if usesAppleProvider {
            try await reauthenticateWithApple()
        }
        try await AccountDeletionRemoteService.deleteViaClientSDK()
    }

    private var usesAppleProvider: Bool {
        currentFirebaseUser?.providerData.contains { $0.providerID == "apple.com" } == true
    }

    private func reauthenticateWithApple() async throws {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        AppleSignInManager.shared.startReauthenticationFlow { result in
                            continuation.resume(with: result)
                        }
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                    throw AccountDeletionError.remoteDeletionFailed(
                        "Confirmation Apple expirée. Ferme les fenêtres ouvertes et réessaie."
                    )
                }

                defer { group.cancelAll() }
                try await group.next()!
            }
        } catch let error as AccountDeletionError {
            throw error
        } catch {
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                throw AccountDeletionError.cancelled
            }
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                throw AccountDeletionError.cancelled
            }
            throw error
        }
    }

    func deleteRemoteUserIfNeeded() async {
        try? await deleteRemoteAccount()
    }

    func applyPostAccountDeletion() {
        isAuthenticated = false
        isInOnboarding = false
        hasCompletedOnboarding = false
        isLoading = false
        if firebaseAuthReady {
            try? Auth.auth().signOut()
        }
        UnifiedProfileService.shared.clearLocalProfile()
    }

    func signOut() {
        if firebaseAuthReady {
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

    private static let localProfileKey = "unified.profile"

    @Published var currentProfile: UnifiedUserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isAuthenticated = false

    private init() {}

    private var firebaseAuthReady: Bool {
        FirebaseBootstrap.isConfigured
    }

    private var currentFirebaseUser: User? {
        guard firebaseAuthReady else { return nil }
        return Auth.auth().currentUser
    }

    func clearLocalProfile() {
        currentProfile = nil
        isAuthenticated = false
        error = nil
    }

    func clearAllLocalData(userId: String) {
        UserScopedStorage.clearAllUserData(userId: userId)
        clearLocalProfile()
    }

    private func persistLocalProfile(_ profile: UnifiedUserProfile) {
        let key = UserScopedStorage.key(Self.localProfileKey, userId: profile.userId)
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadLocalProfile(userId: String) -> UnifiedUserProfile? {
        let key = UserScopedStorage.key(Self.localProfileKey, userId: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UnifiedUserProfile.self, from: data)
    }

    func loadProfile() async {
        guard let user = currentFirebaseUser else {
            let userId = "local-user"
            if let cached = loadLocalProfile(userId: userId) {
                currentProfile = cached
            } else if currentProfile == nil {
                currentProfile = UnifiedUserProfile(userId: userId, firstName: "")
            }
            isAuthenticated = currentProfile != nil
            if let currentProfile {
                SocialProfileStore.shared.syncFromUnified(currentProfile)
            }
            return
        }
        let userId = user.uid

        isLoading = true
        defer { isLoading = false }

        do {
            if let profile = try await FirebaseProfileRepository.shared.loadProfile(userId: userId) {
                currentProfile = profile
            } else if currentProfile == nil {
                currentProfile = UnifiedUserProfile(
                    userId: userId,
                    firstName: user.displayName ?? "",
                    email: user.email
                )
            }
            isAuthenticated = true
            error = nil
            if let currentProfile {
                persistLocalProfile(currentProfile)
                SocialProfileStore.shared.syncFromUnified(currentProfile)
                Task {
                    await ProcessUsernameProvisioner.ensureUsernameClaimed(
                        profile: currentProfile,
                        profileService: self
                    )
                }
            }
        } catch {
            self.error = error
            if currentProfile == nil {
                currentProfile = loadLocalProfile(userId: userId)
                    ?? UnifiedUserProfile(
                        userId: userId,
                        firstName: user.displayName ?? "",
                        email: user.email
                    )
            }
            isAuthenticated = true
            if let currentProfile {
                SocialProfileStore.shared.syncFromUnified(currentProfile)
                Task {
                    await ProcessUsernameProvisioner.ensureUsernameClaimed(
                        profile: currentProfile,
                        profileService: self
                    )
                }
            }
        }
    }

    func saveProfile(_ profile: UnifiedUserProfile) async throws {
        currentProfile = profile
        isAuthenticated = true
        error = nil
        persistLocalProfile(profile)
        SocialProfileStore.shared.syncFromUnified(profile)

        guard currentFirebaseUser != nil else {
            return
        }

        try await FirebaseProfileRepository.shared.saveProfile(profile)
    }

    func updatePreferences(_ preferences: UserPreferences) async throws {
        guard var profile = currentProfile else { return }
        profile.preferences = preferences
        try await saveProfile(profile)
    }

    func updateUsername(_ rawTag: String, displayName: String? = nil) async throws {
        guard var profile = currentProfile else {
            throw ProcessUsernameError.notAuthenticated
        }

        let normalized = ProcessUsernameTag.normalize(rawTag)
        try ProcessUsernameTag.validate(normalized)

        let trimmedDisplay = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedFirst = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = !trimmedDisplay.isEmpty ? trimmedDisplay : (!trimmedFirst.isEmpty ? trimmedFirst : normalized)

        if currentFirebaseUser != nil {
            try await ProcessUsernameRegistry.shared.claimUsername(
                tag: normalized,
                userId: profile.userId,
                displayName: label,
                previousTag: profile.username
            )
        }

        profile.username = normalized
        try await saveProfile(profile)
    }

    func lookupUser(byTag rawTag: String) async throws -> ProcessPublicUserTag {
        try await ProcessUsernameRegistry.shared.lookup(tag: rawTag)
    }
}

// MARK: - Permissions

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published private(set) var notificationsGranted = false

    private init() {}

    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            notificationsGranted = granted
            return granted
        } catch {
            return false
        }
    }

    func refreshNotificationAuthorizationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsGranted = status == .authorized
    }

    func canScheduleNotifications() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized
    }

    /// Remet la pastille à zéro sans effacer les notifications planifiées (check-ins, brief matin, scan…).
    func clearAppBadge() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        try? await center.setBadgeCount(0)
    }

    func requestMotionPermission() async -> Bool {
        // CoreMotion n'affiche pas de popup — Info.plist NSMotionUsageDescription suffit.
        true
    }
}

// MARK: - Subscriptions → voir Subscriptions/SubscriptionService.swift

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
