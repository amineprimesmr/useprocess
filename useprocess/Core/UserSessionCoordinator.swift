import Foundation
import FirebaseAuth
import FirebaseCore

/// Recharge les caches locaux quand l'utilisateur Firebase change.
@MainActor
@Observable
final class UserSessionCoordinator {
    static let shared = UserSessionCoordinator()

    private(set) var activeUserId: String?
    private var authListener: AuthStateDidChangeListenerHandle?

    private init() {
        FirebaseBootstrap.configure()
        guard AppConfiguration.firebaseConfigured, FirebaseApp.app() != nil else {
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
            AppSession.shared.reloadForCurrentUser()
            ProcessPrivacyConsentStore.shared.reloadForUser(userId: userId)
            BodyScanHistoryStore.shared.reloadForUser(userId: userId)
            FaceScanHistoryStore.shared.reloadForUser(userId: userId)
            CoachConversationStore.reloadForUser(userId: userId)
            SocialProfileStore.shared.bind(unified: UnifiedProfileService.shared.currentProfile)

            Task {
                await SubscriptionService.shared.syncAppUserID(userId)
                await UnifiedProfileService.shared.loadProfile()
                SocialProfileStore.shared.bind(unified: UnifiedProfileService.shared.currentProfile)
                await FaceScanHistoryStore.shared.syncFromRemote()
                await HealthManager.shared.performFullSync()
            }
        } else if AppSession.shared.isAccountWipeInProgress {
            return
        } else {
            handleSignedOut()
        }
    }

    func handleAccountDeleted() {
        activeUserId = nil
        UnifiedProfileService.shared.clearLocalProfile()
        SocialProfileStore.shared.bind(unified: nil)
        BodyScanHistoryStore.shared.clearForUser(userId: nil)
        FaceScanHistoryStore.shared.clearForUser(userId: nil)
        Task { await SubscriptionService.shared.syncAppUserID(nil) }
    }

    private func handleSignedOut() {
        activeUserId = nil
        UnifiedProfileService.shared.clearLocalProfile()
        SocialProfileStore.shared.bind(unified: nil)
        Task { await SubscriptionService.shared.syncAppUserID(nil) }
    }
}
