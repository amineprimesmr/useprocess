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
        migrateOnboardingEngagementData(to: targetUid)
        // Plus de questionnaire de configuration : plan auto depuis l'onboarding.
        WelcomePlanStore.shared.autoCompleteWelcomePlanIfNeeded(profile: profile)
    }

    static func migrateOnboardingEngagementData(to userId: String) {
        for base in [
            "process.evening_checkin",
            "process.hydration_log",
            "process.streak",
            "process.debloat.trajectory"
        ] {
            migrateUserDefaultsBlob(base: base, to: userId)
        }
        migrateOnboardingProgressData(to: userId)
        ProcessEveningCheckInStore.shared.reload()
        ProcessHydrationLogStore.shared.reload()
        ProcessDebloatTrajectoryStore.shared.reload()
        ProcessStreakStore.shared.reload()
    }

    static func migrateOnboardingProgressData(to userId: String) {
        let suffixes = ["current_step", "last_completed_step", "visited_steps", "answers", "flow_progress"]
        for suffix in suffixes {
            migrateUserDefaultsBlob(base: "onboarding.progress.\(suffix)", to: userId)
        }
    }

    private static func migrateUserDefaultsBlob(base: String, to userId: String) {
        let targetKey = UserScopedStorage.key(base, userId: userId)
        guard UserDefaults.standard.data(forKey: targetKey) == nil else { return }
        for sourceUid in UserScopedStorage.likelyUserIds(primary: userId) where sourceUid != userId {
            let sourceKey = UserScopedStorage.key(base, userId: sourceUid)
            if let data = UserDefaults.standard.data(forKey: sourceKey) {
                UserDefaults.standard.set(data, forKey: targetKey)
                return
            }
        }
    }

    static func migrateOnboardingFaceScanData() {
        let targetUid = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
            ?? "local-user"

        OnboardingFaceMarkersStore.migrateFromLikelyUsers(to: targetUid)
        FaceScanHistoryStore.shared.migrateOnboardingDataFromLikelyUsers(to: targetUid)
    }
}
