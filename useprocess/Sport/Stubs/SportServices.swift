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

    private(set) var isLoadingData = false
    private(set) var currentRecoveryData: DailyRecoveryData?
    private(set) var currentEffortData: DailyEffortData?
    private(set) var currentSleepData: DailySleepData?
    private(set) var currentActivityData: DailyActivityData?
    private(set) var currentHealthMetricsData: DailyHealthMetricsData?
    private(set) var currentNutritionData: DailyNutritionData?

    private init() {}

    func getDataForDate(_ date: Date) async {
        objectWillChange.send()
        isLoadingData = true
        defer {
            objectWillChange.send()
            isLoadingData = false
        }
        await HealthManager.shared.syncHealthDataForDate(date)
        await updateCurrentDayData(with: HealthManager.shared)
    }

    func getCurrentRecoveryData() -> DailyRecoveryData? { currentRecoveryData }
    func getCurrentEffortData() -> DailyEffortData? { currentEffortData }
    func getCurrentSleepData() -> DailySleepData? { currentSleepData }

    func updateCurrentDayData(with healthManager: HealthManager) async {
        let snapshot = healthManager.todaySnapshot
        objectWillChange.send()
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
            return AppCopy.tSync("Aucune session active.", en: "No active session.")
        case .cancelled:
            return AppCopy.tSync("Suppression annulée.", en: "Deletion cancelled.")
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

        hasCompletedOnboarding = AppSession.shared.hasCompletedOnboarding
        // Ne pas publier / enregistrer le listener Auth pendant l'init :
        // le callback synchrone d'Auth invalidait SwiftUI au milieu du montage
        // de SportOnboardingView (@StateObject) → EXC_BAD_ACCESS.
        isAuthenticated = firebaseAuthReady && currentFirebaseUser != nil

        guard firebaseAuthReady else { return }

        DispatchQueue.main.async { [weak self] in
            self?.attachAuthStateListenerIfNeeded()
        }
    }

    private func attachAuthStateListenerIfNeeded() {
        guard firebaseAuthReady, authListenerHandle == nil else { return }

        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                guard !AppSession.shared.isAccountWipeInProgress else { return }
                guard !AppSession.shared.blocksAuthenticatedOnboardingRestore else {
                    self.isAuthenticated = user != nil
                    if user == nil {
                        UnifiedProfileService.shared.clearLocalProfile()
                    }
                    return
                }
                self.isAuthenticated = user != nil
                if user != nil {
                    await UnifiedProfileService.shared.loadProfile()
                    guard !AppSession.shared.isAccountWipeInProgress else { return }
                    guard !AppSession.shared.blocksAuthenticatedOnboardingRestore else { return }
                    AppSession.shared.reloadForCurrentUser()
                    guard !AppSession.shared.isAccountWipeInProgress else { return }
                    guard !AppSession.shared.blocksAuthenticatedOnboardingRestore else { return }
                    AppSession.shared.reconcileOnboardingFromProfileIfNeeded()
                    self.hasCompletedOnboarding = AppSession.shared.hasCompletedOnboarding
                    if AppSession.shared.hasCompletedOnboarding {
                        self.isInOnboarding = false
                    }
                } else {
                    UnifiedProfileService.shared.clearLocalProfile()
                }
            }
        }
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

    /// Suppression serveur best-effort — **jamais** de pop-up Sign in with Apple ici.
    /// La réauth Apple pendant la suppression renvoyait l'utilisateur dans l'app si annulée.
    func deleteRemoteAccountBestEffort() async -> String? {
        guard firebaseAuthReady else {
            return AppCopy.tSync("Firebase non configuré.", en: "Firebase not configured.")
        }

        guard currentFirebaseUser != nil else {
            return nil
        }

        do {
            try await AccountDeletionRemoteService.deleteViaCloudFunction(appleAuthorizationCode: nil)
            #if DEBUG
            print("[Auth] Compte supprimé via Cloud Function (sans pop-up Apple)")
            #endif
            return nil
        } catch {
            #if DEBUG
            print("[Auth] Cloud delete failed, trying client SDK: \(error.localizedDescription)")
            #endif
        }

        do {
            try await AccountDeletionRemoteService.deleteViaClientSDK()
            #if DEBUG
            print("[Auth] Compte supprimé via client SDK (sans pop-up Apple)")
            #endif
            return nil
        } catch let error as AccountDeletionError {
            return error.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    @available(*, deprecated, message: "Use deleteRemoteAccountBestEffort() — no Apple reauth prompt.")
    func deleteRemoteAccount() async throws {
        if let warning = await deleteRemoteAccountBestEffort() {
            throw AccountDeletionError.remoteDeletionFailed(warning)
        }
    }

    func deleteRemoteUserIfNeeded() async {
        try? await deleteRemoteAccount()
    }

    func applyPostAccountDeletion() {
        isAuthenticated = false
        isInOnboarding = true
        hasCompletedOnboarding = false
        isLoading = false
        if firebaseAuthReady {
            try? Auth.auth().signOut()
        }
        UnifiedProfileService.shared.clearAllPersistedProfiles(primaryUID: nil)
    }

    func signOut() {
        if firebaseAuthReady {
            try? Auth.auth().signOut()
        }
        UnifiedProfileService.shared.clearLocalProfile()
    }
}

// MARK: - Profile


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
        clearAllPersistedProfiles(primaryUID: currentProfile?.userId)
    }

    func clearAllPersistedProfiles(primaryUID: String?) {
        let primary = primaryUID ?? UserScopedStorage.currentUserId() ?? "local-user"
        for uid in UserScopedStorage.likelyUserIds(primary: primary) {
            let key = UserScopedStorage.key(Self.localProfileKey, userId: uid)
            UserDefaults.standard.removeObject(forKey: key)
        }
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
        guard !AppSession.shared.isAccountWipeInProgress else { return }
        guard !AppSession.shared.blocksAuthenticatedOnboardingRestore else { return }

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

        // Hydrate immédiatement l'interface depuis le cache, puis évite que les
        // listeners Auth et Session lancent deux requêtes identiques.
        if currentProfile?.userId != userId, let cached = loadLocalProfile(userId: userId) {
            currentProfile = cached
            isAuthenticated = true
            SocialProfileStore.shared.syncFromUnified(cached)
        }
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            if let profile = try await FirebaseProfileRepository.shared.loadProfile(userId: userId) {
                guard !AppSession.shared.isAccountWipeInProgress else { return }
                currentProfile = profile
            } else if currentProfile?.userId != userId {
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

    func requestNotificationPermission(analyticsSource: String = "unknown") async -> Bool {
        let center = UNUserNotificationCenter.current()
        let prior = await center.notificationSettings().authorizationStatus

        if prior == .notDetermined {
            ProcessAnalytics.trackNotificationsPromptShown(source: analyticsSource)
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            let status = await center.notificationSettings().authorizationStatus
            let statusName = Self.notificationStatusName(status)
            notificationsGranted = granted || status == .authorized || status == .provisional
            if notificationsGranted {
                ProcessAnalytics.trackNotificationsAuthorized(source: analyticsSource, status: statusName)
                ProcessCrispSupport.registerForRemoteNotificationsIfAllowed()
            } else {
                ProcessAnalytics.trackNotificationsDenied(source: analyticsSource, status: statusName)
            }
            return notificationsGranted
        } catch {
            notificationsGranted = false
            ProcessAnalytics.trackNotificationsDenied(source: analyticsSource, status: "error")
            return false
        }
    }

    func refreshNotificationAuthorizationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsGranted = status == .authorized || status == .provisional
        ProcessAnalytics.syncNotificationsStatus(
            Self.notificationStatusName(status),
            authorized: notificationsGranted
        )
        if notificationsGranted {
            ProcessCrispSupport.registerForRemoteNotificationsIfAllowed()
        }
    }

    func canScheduleNotifications() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
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

    private static func notificationStatusName(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "not_determined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Subscriptions → voir Subscriptions/SubscriptionService.swift

enum OnboardingError: Error, LocalizedError {
    case notAuthenticated
    case healthKitNotAvailable
    case dataCollectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return AppCopy.tSync("Utilisateur non authentifié", en: "User not authenticated")
        case .healthKitNotAvailable:
            return AppCopy.tSync("HealthKit non disponible", en: "HealthKit unavailable")
        case .dataCollectionFailed(let message):
            return AppCopy.tSync(
                "Erreur collecte données: \(message)",
                en: "Data collection error: \(message)"
            )
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
