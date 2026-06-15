import Foundation
import FirebaseAuth

/// Recharge les caches locaux quand l'utilisateur Firebase change.
@MainActor
@Observable
final class UserSessionCoordinator {
    static let shared = UserSessionCoordinator()

    private(set) var activeUserId: String?
    private var authListener: AuthStateDidChangeListenerHandle?

    private init() {
        guard AppConfiguration.firebaseConfigured else {
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

        AppSession.shared.reloadForCurrentUser()
        BodyScanHistoryStore.shared.reloadForUser(userId: userId)
        CoachConversationStore.reloadForUser(userId: userId)
        SocialProfileStore.shared.bind(unified: UnifiedProfileService.shared.currentProfile)

        if userId != nil {
            Task {
                await SubscriptionService.shared.syncAppUserID(userId)
                await UnifiedProfileService.shared.loadProfile()
                SocialProfileStore.shared.bind(unified: UnifiedProfileService.shared.currentProfile)
            }
        } else {
            Task { await SubscriptionService.shared.syncAppUserID(nil) }
            UnifiedProfileService.shared.clearLocalProfile()
            SocialProfileStore.shared.bind(unified: nil)
        }
    }
}
