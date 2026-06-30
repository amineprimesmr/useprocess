import Foundation

/// Présentation unique du questionnaire Protocole Origine à la première ouverture du coach.
enum WelcomePlanCoachPresentation {
    private static func storageKey(userId: String?) -> String {
        UserScopedStorage.key(
            "welcome.plan.coach.auto_presented",
            userId: userId ?? UserScopedStorage.currentUserId()
        )
    }

    static var hasAutoPresentedConfiguration: Bool {
        let uid = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
        guard UserDefaults.standard.object(forKey: storageKey(userId: uid)) != nil else {
            return false
        }
        return UserDefaults.standard.bool(forKey: storageKey(userId: uid))
    }

    static func markConfigurationAutoPresented() {
        let uid = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
        UserDefaults.standard.set(true, forKey: storageKey(userId: uid))
    }

    static func resetForCurrentUser() {
        let uid = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
        UserDefaults.standard.removeObject(forKey: storageKey(userId: uid))
    }
}
