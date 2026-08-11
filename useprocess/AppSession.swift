import SwiftUI

enum AccountDeletionPhase: Equatable {
    case idle
    case remote
    case local
    case finishing
}

/// État global de l'application.
@MainActor
@Observable
final class AppSession {
    static let shared = AppSession()

    var hasCompletedOnboarding: Bool
    var hasCompletedWelcomePlanChat: Bool
    var appearance: AppAppearance
    /// Empêche UserSessionCoordinator de recharger l'onboarding pendant une suppression.
    private(set) var isAccountWipeInProgress = false
    private(set) var accountDeletionPhase: AccountDeletionPhase = .idle
    var accountDeletionErrorMessage: String?

    var accountDeletionStatusMessage: String {
        switch accountDeletionPhase {
        case .idle:
            return AppCopy.t("Patiente quelques instants…", en: "Hang tight for a moment…")
        case .remote:
            return AppCopy.t("Suppression sur nos serveurs…", en: "Deleting from our servers…")
        case .local:
            return AppCopy.t("Effacement des données locales…", en: "Erasing local data…")
        case .finishing:
            return AppCopy.t("Finalisation…", en: "Finishing up…")
        }
    }

    func beginAccountDeletion() {
        isAccountWipeInProgress = true
        accountDeletionPhase = .remote
        accountDeletionErrorMessage = nil
    }

    func cancelAccountDeletion() {
        isAccountWipeInProgress = false
        accountDeletionPhase = .idle
    }

    /// Point d'entrée unique depuis les réglages — overlay immédiat + gestion d'erreur.
    func performAccountDeletionFromUI() async {
        if !isAccountWipeInProgress {
            beginAccountDeletion()
        }

        do {
            try await deleteAccount()
        } catch let error as AccountDeletionError {
            if case .cancelled = error {
                cancelAccountDeletion()
                return
            }
            cancelAccountDeletion()
            accountDeletionErrorMessage = error.localizedDescription
        } catch {
            cancelAccountDeletion()
            accountDeletionErrorMessage = error.localizedDescription
        }
    }

    private init() {
        let uid = UserScopedStorage.currentUserId()
        let onboardingKey = UserScopedStorage.key("onboarding.completed", userId: uid)
        let completedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
        hasCompletedOnboarding = completedOnboarding

        hasCompletedWelcomePlanChat = Self.resolveWelcomePlanChatCompleted(
            completedOnboarding: completedOnboarding,
            userId: uid
        )

        let rawAppearance = UserDefaults.standard.string(forKey: Keys.appearance) ?? AppAppearance.system.rawValue
        appearance = AppAppearance(rawValue: rawAppearance) ?? .system
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingStorageKey)
        AuthenticationManager.shared.completeOnboarding()
        ProcessHomeScreenQuickActions.syncForCurrentUser()
        // Plus de questionnaire post-onboarding : accès direct à l'app.
    }

    func completeWelcomePlanChat() {
        hasCompletedWelcomePlanChat = true
        UserDefaults.standard.set(true, forKey: welcomePlanChatStorageKey)
    }

    func setWelcomePlanChatCompleted(_ completed: Bool) {
        hasCompletedWelcomePlanChat = completed
        UserDefaults.standard.set(completed, forKey: welcomePlanChatStorageKey)
    }

    func resetOnboarding() {
        let uid = UnifiedProfileService.shared.currentProfile?.userId
            ?? UserScopedStorage.currentUserId()
            ?? "local-user"

        hasCompletedOnboarding = false
        hasCompletedWelcomePlanChat = false

        for id in UserScopedStorage.likelyUserIds(primary: uid) {
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("onboarding.completed", userId: id))
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("welcome.plan.chat.completed", userId: id))
        }

        OnboardingProgressService.shared.resetProgress()
        WelcomePlanStore.shared.resetForCurrentUser()
        AuthenticationManager.shared.hasCompletedOnboarding = false
    }

    /// Remet l'app au parcours d'accueil (onboarding) après suppression de compte.
    func resetAfterAccountDeletion(primaryUID: String? = nil) {
        hasCompletedOnboarding = false
        hasCompletedWelcomePlanChat = false

        let primary = primaryUID
            ?? UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
            ?? "local-user"

        for uid in UserScopedStorage.likelyUserIds(primary: primary) {
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("onboarding.completed", userId: uid))
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("welcome.plan.chat.completed", userId: uid))
        }

        OnboardingProgressService.shared.resetProgress()
        WelcomePlanStore.shared.resetForCurrentUser()
        ProcessAnalytics.reset()

        AuthenticationManager.shared.applyPostAccountDeletion()
        AuthenticationManager.shared.startOnboarding()
    }

    /// Suppression complète du compte : Firebase d'abord, puis données locales + retour onboarding.
    func deleteAccount() async throws {
        accountDeletionErrorMessage = nil
        if !isAccountWipeInProgress {
            beginAccountDeletion()
        }
        defer {
            isAccountWipeInProgress = false
            accountDeletionPhase = .idle
        }

        accountDeletionPhase = .remote
        try await AuthenticationManager.shared.deleteRemoteAccount()

        accountDeletionPhase = .local

        let primaryUID = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
            ?? "local-user"

        let userIds = UserScopedStorage.likelyUserIds(primary: primaryUID)

        CoachConversationStore.resetThread()
        CoachConversationLibraryStore.shared.clearStoredData(userId: primaryUID)
        CoachMemoryStore.shared.clearForUser(userId: primaryUID)
        CoachIntelligenceSettingsStore.shared.deleteAllCoachFiles(userId: primaryUID)
        CoachMyMemoryStore.shared.deleteAll()
        CoachProcessFilesStore.shared.deleteAll()
        CoachCheckInStore.shared.reload()
        SocialProfileStore.shared.resetForUser(userId: primaryUID)
        BodyScanHistoryStore.shared.clearForUser(userId: primaryUID)
        FaceScanHistoryStore.shared.clearForUser(userId: primaryUID)
        FaceScanImageStore.deleteAllStoredMedia()
        BodyScanImageStore.deleteAllStoredMedia()
        CoachChatAttachmentImageStore.deleteAllStoredMedia()
        OnboardingFaceMarkersStore.clear()
        ProcessHydrationLogStore.shared.clearAllData()
        ProcessHydrationTimerStore.shared.clearAllData()
        ProcessCreatorModeStore.shared.syncFromCurrentProfile()

        for uid in userIds {
            UserScopedStorage.clearAllUserData(userId: uid)
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("onboarding.completed", userId: uid))
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("welcome.plan.chat.completed", userId: uid))
            ProcessPrivacyConsentStore.shared.clearForUser(userId: uid)
        }

        accountDeletionPhase = .finishing

        UnifiedProfileService.shared.clearLocalProfile()
        resetAfterAccountDeletion(primaryUID: primaryUID)
        await SubscriptionService.shared.logOutAfterAccountDeletion()
        UserSessionCoordinator.shared.handleAccountDeleted()
    }

    func reloadForCurrentUser() {
        guard !isAccountWipeInProgress else { return }

        guard AuthUser.current != nil else {
            hasCompletedOnboarding = false
            hasCompletedWelcomePlanChat = false
            return
        }

        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingStorageKey)
        WelcomePlanStore.shared.reloadForCurrentUser(force: true)
        if hasCompletedOnboarding {
            WelcomePlanStore.shared.autoCompleteWelcomePlanIfNeeded(
                profile: UnifiedProfileService.shared.currentProfile
            )
        }
        hasCompletedWelcomePlanChat = Self.resolveWelcomePlanChatCompleted(
            completedOnboarding: hasCompletedOnboarding,
            userId: UserScopedStorage.currentUserId() ?? UnifiedProfileService.shared.currentProfile?.userId
        )
    }

    /// Flag welcome plan : si onboarding fait, le plan auto suffit (plus de questionnaire).
    private static func resolveWelcomePlanChatCompleted(completedOnboarding: Bool, userId: String?) -> Bool {
        guard completedOnboarding else { return false }

        let uid = userId ?? "local-user"
        let welcomeKey = UserScopedStorage.key("welcome.plan.chat.completed", userId: uid)
        let hasSavedPlan = UserDefaults.standard.data(
            forKey: UserScopedStorage.key("welcome.plan", userId: uid)
        ) != nil

        if UserDefaults.standard.bool(forKey: welcomeKey), hasSavedPlan {
            return true
        }

        // Compte onboarding terminé + plan présent → considéré complété.
        if hasSavedPlan {
            UserDefaults.standard.set(true, forKey: welcomeKey)
            return true
        }

        return UserDefaults.standard.bool(forKey: welcomeKey)
    }

    func setAppearance(_ mode: AppAppearance) {
        appearance = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Keys.appearance)
    }

    private var onboardingStorageKey: String {
        UserScopedStorage.key(
            "onboarding.completed",
            userId: UserScopedStorage.currentUserId() ?? UnifiedProfileService.shared.currentProfile?.userId
        )
    }

    private var welcomePlanChatStorageKey: String {
        UserScopedStorage.key(
            "welcome.plan.chat.completed",
            userId: UserScopedStorage.currentUserId() ?? UnifiedProfileService.shared.currentProfile?.userId
        )
    }

    private enum Keys {
        static var appearance: String { UserScopedStorage.globalKey("appearance") }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return AppCopy.tSync("Automatique", en: "Automatic")
        case .dark: return AppCopy.tSync("Sombre", en: "Dark")
        case .light: return AppCopy.tSync("Clair", en: "Light")
        }
    }

    /// `nil` = suit le réglage iPhone.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    func resolved(with system: ColorScheme) -> AppAppearance {
        switch self {
        case .system: return system == .dark ? .dark : .light
        case .dark: return .dark
        case .light: return .light
        }
    }
}
