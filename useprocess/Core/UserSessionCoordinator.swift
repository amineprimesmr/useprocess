import Foundation
import FirebaseAuth

/// Recharge les caches locaux quand l'utilisateur Firebase change.
@MainActor
@Observable
final class UserSessionCoordinator {
    static let shared = UserSessionCoordinator()

    private(set) var activeUserId: String?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var bindWorkTask: Task<Void, Never>?

    func cancelPendingBindWork() {
        bindWorkTask?.cancel()
        bindWorkTask = nil
    }

    private init() {
        FirebaseBootstrap.configure()
        guard FirebaseBootstrap.isConfigured else {
            bind(userId: nil)
            return
        }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.bind(userId: user?.uid)
            }
        }
        bind(userId: Auth.auth().currentUser?.uid)
    }

    func bind(userId: String?) {
        guard activeUserId != userId else { return }
        activeUserId = userId

        if AppSession.shared.isAccountWipeInProgress {
            return
        }

        if let userId {
            FaceScanHistoryStore.shared.reloadForUser(userId: userId)
            PostOnboardingActivationService.migrateOnboardingFaceScanData()
            PostOnboardingActivationService.migrateOnboardingEngagementData(to: userId)
            ProcessEveningCheckInStore.shared.reload()
            ProcessHydrationLogStore.shared.reload()
            ProcessDebloatTrajectoryStore.shared.reload()
            ProcessStreakStore.shared.reload()
            if !AppSession.shared.isAccountWipeInProgress,
               !AppSession.shared.blocksAuthenticatedOnboardingRestore {
                AppSession.shared.reloadForCurrentUser()
            }
            ProcessPrivacyConsentStore.shared.reloadForUser(userId: userId)
            BodyScanHistoryStore.shared.reloadForUser(userId: userId)
            CoachConversationStore.reloadForUser(userId: userId)
            SocialProfileStore.shared.bind(unified: UnifiedProfileService.shared.currentProfile)

            bindWorkTask?.cancel()
            bindWorkTask = Task {
                guard !Task.isCancelled else { return }
                guard !AppSession.shared.isAccountWipeInProgress else { return }

                await SubscriptionService.shared.syncAppUserID(userId)
                guard !Task.isCancelled, !AppSession.shared.isAccountWipeInProgress else { return }

                await UnifiedProfileService.shared.loadProfile()
                guard !Task.isCancelled, !AppSession.shared.isAccountWipeInProgress else { return }

                SocialProfileStore.shared.bind(unified: UnifiedProfileService.shared.currentProfile)
                if let profile = UnifiedProfileService.shared.currentProfile {
                    ProcessReferralStore.shared.reload(
                        username: profile.username,
                        userId: profile.userId
                    )
                    await ProcessReferralStore.shared.syncRemote(
                        displayName: profile.firstName.isEmpty ? profile.username : profile.firstName
                    )
                    await AcquisitionCodeService.retryPendingRemoteRegistration(
                        displayName: profile.firstName.isEmpty ? profile.username : profile.firstName
                    )
                    await ProcessAffiliateStore.shared.reload()
                }
                guard !Task.isCancelled, !AppSession.shared.isAccountWipeInProgress else { return }

                await ReferralService.shared.confirmSubscriptionRewardsIfNeeded()
                ProcessCrispSupport.syncUser()
                if AppSession.shared.hasCompletedOnboarding,
                   !AuthenticationManager.shared.isInOnboarding {
                    await FaceScanHistoryStore.shared.syncFromRemote()
                    await HealthManager.shared.performFullSync()
                }
            }
        } else if AppSession.shared.isAccountWipeInProgress {
            return
        } else {
            handleSignedOut()
        }
    }

    func handleAccountDeleted() {
        cancelPendingBindWork()
        let deletedUID = activeUserId
        activeUserId = nil
        UnifiedProfileService.shared.clearAllPersistedProfiles(primaryUID: deletedUID)
        SocialProfileStore.shared.bind(unified: nil)
        BodyScanHistoryStore.shared.clearForUser(userId: nil)
        FaceScanHistoryStore.shared.clearForUser(userId: nil)
        ProcessCrispSupport.resetSession()
        Task { await SubscriptionService.shared.logOutAfterAccountDeletion() }
    }

    private func handleSignedOut() {
        activeUserId = nil
        UnifiedProfileService.shared.clearLocalProfile()
        SocialProfileStore.shared.bind(unified: nil)
        ProcessAffiliateStore.shared.clearForSignOut()
        ProcessCrispSupport.resetSession()
        Task { await SubscriptionService.shared.logOutAfterAccountDeletion() }
    }
}
