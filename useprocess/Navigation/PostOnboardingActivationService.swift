import Foundation

/// Prépare l'entrée dans l'app après l'onboarding sport : migration du scan + plan auto (sans questionnaire).
@MainActor
enum PostOnboardingActivationService {

    static func prepareFirstAppEntry(profile: UnifiedUserProfile?) {
        let targetUid = UserScopedStorage.currentUserId()
            ?? profile?.userId
            ?? "local-user"

        FaceScanHistoryStore.shared.reloadForUser(userId: targetUid)
        migrateOnboardingFaceScanData()
        // Plus de questionnaire de configuration : plan auto depuis l'onboarding.
        WelcomePlanStore.shared.autoCompleteWelcomePlanIfNeeded(profile: profile)
    }

    static func migrateOnboardingFaceScanData() {
        let targetUid = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
            ?? "local-user"

        OnboardingFaceMarkersStore.migrateFromLikelyUsers(to: targetUid)
        FaceScanHistoryStore.shared.migrateOnboardingDataFromLikelyUsers(to: targetUid)
    }
}
