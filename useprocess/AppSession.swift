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
    private var accountDeletionUITask: Task<Void, Never>?
    /// Après suppression : bloque reload profil / Auth qui remettraient hasCompletedOnboarding à true.
    private(set) var blocksAuthenticatedOnboardingRestore = false

    /// True une fois le wipe local terminé — évite de restaurer l'état si l'utilisateur annule avant.
    private var accountDeletionDidFinalizeLocally = false

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
        accountDeletionDidFinalizeLocally = false
        accountDeletionPhase = .remote
        accountDeletionErrorMessage = nil
        UserSessionCoordinator.shared.cancelPendingBindWork()
    }

    func cancelAccountDeletion() {
        accountDeletionUITask?.cancel()
        accountDeletionUITask = nil
        isAccountWipeInProgress = false
        accountDeletionPhase = .idle

        guard !accountDeletionDidFinalizeLocally else { return }

        persistBlocksAuthenticatedOnboardingRestore(false)
        reloadForCurrentUser()
        if !hasCompletedOnboarding {
            AuthenticationManager.shared.startOnboarding()
        }
    }

    /// Point d'entrée unique depuis les réglages — overlay immédiat + gestion d'erreur.
    /// Tâche détachée du cycle de vie SwiftUI (survit au dismiss des réglages).
    func enqueueAccountDeletionFromUI(afterDismiss dismiss: (@MainActor () -> Void)? = nil) {
        accountDeletionUITask?.cancel()
        accountDeletionUITask = Task.detached(priority: .userInitiated) { @MainActor [self] in
            self.beginAccountDeletion()
            dismiss?()
            if dismiss != nil {
                try? await Task.sleep(for: .milliseconds(320))
            }

            await self.performAccountDeletionFromUI()
            self.accountDeletionUITask = nil
        }
    }

    func performAccountDeletionFromUI() async {
        if !isAccountWipeInProgress {
            beginAccountDeletion()
        }

        defer {
            if isAccountWipeInProgress {
                isAccountWipeInProgress = false
                accountDeletionPhase = .idle
            }
        }

        do {
            try await deleteAccount()
        } catch {
            if !accountDeletionDidFinalizeLocally {
                accountDeletionErrorMessage = error.localizedDescription
            }
        }
    }

    private init() {
        let uid = UserScopedStorage.currentUserId()
        let blocksRestore = UserDefaults.standard.bool(
            forKey: Keys.blocksAuthenticatedOnboardingRestore
        )

        let completedOnboarding = blocksRestore
            ? false
            : Self.resolveOnboardingCompleted(userId: uid)
        hasCompletedOnboarding = completedOnboarding

        hasCompletedWelcomePlanChat = Self.resolveWelcomePlanChatCompleted(
            completedOnboarding: completedOnboarding,
            userId: uid ?? Self.cachedProfileUserId()
        )

        let rawAppearance = UserDefaults.standard.string(forKey: Keys.appearance) ?? AppAppearance.system.rawValue
        appearance = AppAppearance(rawValue: rawAppearance) ?? .system

        blocksAuthenticatedOnboardingRestore = blocksRestore
    }

    func completeOnboarding() {
        allowAppleSignInDuringOnboarding()
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingStorageKey)
        AuthenticationManager.shared.completeOnboarding()
        ProcessHomeScreenQuickActions.syncForCurrentUser()

        // Le plan auto exige `hasCompletedOnboarding` — le poser avant, sinon le
        // tutoriel accueil ne démarre jamais (plan nil) et l’UI restait verrouillée.
        PlanHomeTutorialStore.shared.suppressPresentationForPreview(false)
        PostOnboardingActivationService.prepareFirstAppEntry(
            profile: UnifiedProfileService.shared.currentProfile
        )
        PlanHomeTutorialStore.shared.activateImmediatelyIfNeeded()
    }

    func completeWelcomePlanChat() {
        hasCompletedWelcomePlanChat = true
        UserDefaults.standard.set(true, forKey: welcomePlanChatStorageKey)
    }

    func setWelcomePlanChatCompleted(_ completed: Bool) {
        hasCompletedWelcomePlanChat = completed
        UserDefaults.standard.set(completed, forKey: welcomePlanChatStorageKey)
    }

    /// Sign in with Apple explicite pendant l'onboarding — lève le blocage post-suppression.
    func allowAppleSignInDuringOnboarding() {
        guard !isAccountWipeInProgress else { return }
        persistBlocksAuthenticatedOnboardingRestore(false)
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
        persistBlocksAuthenticatedOnboardingRestore(true)
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

        clearLegacyOnboardingFlags()
        OnboardingProgressService.shared.resetProgressForAccountDeletion(primaryUID: primary)
        WelcomePlanStore.shared.resetForCurrentUser()
        ProcessAnalytics.reset()
        ProcessCrispSupport.resetSession()

        AuthenticationManager.shared.applyPostAccountDeletion()
        AuthenticationManager.shared.startOnboarding()
    }

    /// Suppression complète : tente Firebase, efface **toujours** les données locales, retour onboarding.
    func deleteAccount() async throws {
        accountDeletionErrorMessage = nil
        if !isAccountWipeInProgress {
            beginAccountDeletion()
        }

        let primaryUID = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
            ?? "local-user"

        accountDeletionPhase = .remote
        let remoteDeletionWarning = await AuthenticationManager.shared.deleteRemoteAccountBestEffort()

        await finalizeAccountDeletionLocally(
            primaryUID: primaryUID,
            remoteDeletionWarning: remoteDeletionWarning
        )
    }

    /// Wipe local garanti + retour onboarding — appelé même si Firebase échoue.
    @MainActor
    private func finalizeAccountDeletionLocally(
        primaryUID: String,
        remoteDeletionWarning: String?
    ) async {
        accountDeletionPhase = .local
        persistBlocksAuthenticatedOnboardingRestore(true)
        hasCompletedOnboarding = false
        hasCompletedWelcomePlanChat = false
        AuthenticationManager.shared.hasCompletedOnboarding = false
        AuthenticationManager.shared.isInOnboarding = true

        wipeAllLocalAccountData(primaryUID: primaryUID)
        OnboardingProgressService.shared.resetProgressForAccountDeletion(primaryUID: primaryUID)

        accountDeletionPhase = .finishing
        UnifiedProfileService.shared.clearAllPersistedProfiles(primaryUID: primaryUID)
        AuthenticationManager.shared.applyPostAccountDeletion()
        AuthenticationManager.shared.startOnboarding()
        clearAllOnboardingCompletionFlags(primaryUID: primaryUID)

        accountDeletionDidFinalizeLocally = true
        UserDefaults.standard.synchronize()

        Task {
            await SubscriptionService.shared.logOutAfterAccountDeletion()
        }
        UserSessionCoordinator.shared.handleAccountDeleted()

        isAccountWipeInProgress = false
        accountDeletionPhase = .idle

        if let remoteDeletionWarning {
            accountDeletionErrorMessage = AppCopy.t(
                "\(remoteDeletionWarning) Tes données sur cet appareil ont été effacées.",
                en: "\(remoteDeletionWarning) Your data on this device has been erased."
            )
        }
    }

    private func clearAllOnboardingCompletionFlags(primaryUID: String) {
        for uid in UserScopedStorage.likelyUserIds(primary: primaryUID) {
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("onboarding.completed", userId: uid))
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("welcome.plan.chat.completed", userId: uid))
        }
        clearLegacyOnboardingFlags()
        purgeUserDefaults(matching: "onboarding.completed")
        purgeUserDefaults(matching: "unified.profile")
    }

    private func purgeUserDefaults(matching fragment: String) {
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.contains(fragment) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func wipeAllLocalAccountData(primaryUID: String) {
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

        clearLegacyOnboardingFlags()
    }

    private func clearLegacyOnboardingFlags() {
        let bundlePrefix = AppConfiguration.bundleIdentifier + "."
        let legacyPrefix = (Bundle.main.bundleIdentifier ?? "useprocess") + "."
        for prefix in [bundlePrefix, legacyPrefix] {
            UserDefaults.standard.removeObject(forKey: prefix + "onboarding.completed")
            UserDefaults.standard.removeObject(forKey: prefix + "onboarding_current_step")
            UserDefaults.standard.removeObject(forKey: prefix + "onboarding_last_completed_step")
            UserDefaults.standard.removeObject(forKey: prefix + "onboarding_visited_steps")
            UserDefaults.standard.removeObject(forKey: prefix + "onboarding_answers_cache")
            UserDefaults.standard.removeObject(forKey: prefix + "onboarding_flow_progress")
        }
    }

    func reloadForCurrentUser() {
        guard !isAccountWipeInProgress else { return }
        guard !blocksAuthenticatedOnboardingRestore else {
            hasCompletedOnboarding = false
            hasCompletedWelcomePlanChat = false
            AuthenticationManager.shared.hasCompletedOnboarding = false
            AuthenticationManager.shared.isInOnboarding = true
            return
        }

        guard AuthUser.current != nil else { return }

        let resolved = Self.resolveOnboardingCompleted(
            userId: UserScopedStorage.currentUserId() ?? UnifiedProfileService.shared.currentProfile?.userId
        )
        if resolved {
            hasCompletedOnboarding = true
            UserDefaults.standard.set(true, forKey: onboardingStorageKey)
        } else {
            hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingStorageKey)
        }

        reconcileOnboardingFromProfileIfNeeded()

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

    /// Firestore / cache profil — filet de sécurité si UserDefaults a raté le cold start.
    func reconcileOnboardingFromProfileIfNeeded() {
        guard !isAccountWipeInProgress else { return }
        guard !blocksAuthenticatedOnboardingRestore else { return }
        guard !hasCompletedOnboarding else { return }
        guard let profile = UnifiedProfileService.shared.currentProfile,
              profile.hasCompletedOnboarding else { return }
        completeOnboarding()
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

    /// Cold start : Auth peut être nil → lit les clés user connues + cache profil avant de conclure « pas onboardé ».
    private static func resolveOnboardingCompleted(userId: String?) -> Bool {
        let defaults = UserDefaults.standard
        let primary = userId ?? cachedProfileUserId()
        let candidates = onboardingCandidateUserIds(primary: primary)

        for candidate in candidates {
            let key = UserScopedStorage.key("onboarding.completed", userId: candidate)
            if defaults.bool(forKey: key) {
                migrateOnboardingCompletedFlag(from: candidate, to: userId)
                return true
            }

            if let profile = loadCachedProfile(userId: candidate), profile.hasCompletedOnboarding {
                defaults.set(true, forKey: key)
                migrateOnboardingCompletedFlag(from: candidate, to: userId)
                return true
            }
        }

        return false
    }

    private static func onboardingCandidateUserIds(primary: String?) -> [String] {
        var ids = Set(UserScopedStorage.likelyUserIds(primary: primary ?? "local-user"))
        if let primary { ids.insert(primary) }
        if let cached = cachedProfileUserId() { ids.insert(cached) }
        if let current = UserScopedStorage.currentUserId() { ids.insert(current) }
        return Array(ids)
    }

    private static func cachedProfileUserId() -> String? {
        for uid in UserScopedStorage.likelyUserIds(primary: "local-user") {
            if loadCachedProfile(userId: uid) != nil {
                return uid
            }
        }
        return nil
    }

    private static func loadCachedProfile(userId: String) -> UnifiedUserProfile? {
        let key = UserScopedStorage.key("unified.profile", userId: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UnifiedUserProfile.self, from: data)
    }

    private static func migrateOnboardingCompletedFlag(from sourceUID: String, to targetUID: String?) {
        guard let targetUID, targetUID != sourceUID else { return }
        guard UserDefaults.standard.bool(
            forKey: UserScopedStorage.key("onboarding.completed", userId: sourceUID)
        ) else { return }

        let targetKey = UserScopedStorage.key("onboarding.completed", userId: targetUID)
        if !UserDefaults.standard.bool(forKey: targetKey) {
            UserDefaults.standard.set(true, forKey: targetKey)
        }
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

    private func persistBlocksAuthenticatedOnboardingRestore(_ enabled: Bool) {
        blocksAuthenticatedOnboardingRestore = enabled
        if enabled {
            UserDefaults.standard.set(true, forKey: Keys.blocksAuthenticatedOnboardingRestore)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.blocksAuthenticatedOnboardingRestore)
        }
    }

    private enum Keys {
        static var appearance: String { UserScopedStorage.globalKey("appearance") }
        static var blocksAuthenticatedOnboardingRestore: String {
            UserScopedStorage.globalKey("account.deletion.blocks_onboarding_restore")
        }
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
