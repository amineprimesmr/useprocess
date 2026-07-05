import Foundation

/// Prépare l'entrée dans l'app après l'onboarding sport : migration du scan, aperçu du plan, état verrouillé.
@MainActor
enum PostOnboardingActivationService {

    static func prepareFirstAppEntry(profile: UnifiedUserProfile?) {
        let targetUid = UserScopedStorage.currentUserId()
            ?? profile?.userId
            ?? "local-user"

        FaceScanHistoryStore.shared.reloadForUser(userId: targetUid)
        migrateOnboardingFaceScanData()
        repairProtocolCompletionState()
        WelcomePlanStore.shared.seedPreviewPlanIfNeeded(profile: profile)
    }

    static func migrateOnboardingFaceScanData() {
        let targetUid = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
            ?? "local-user"

        OnboardingFaceMarkersStore.migrateFromLikelyUsers(to: targetUid)
        FaceScanHistoryStore.shared.migrateOnboardingDataFromLikelyUsers(to: targetUid)
    }

    /// Réinitialise un flag « terminé » sans questionnaire réellement complété.
    private static func repairProtocolCompletionState() {
        guard AppSession.shared.hasCompletedOnboarding else { return }

        let answers = WelcomePlanStore.shared.questionnaire.answers
        let isFullyAnswered = WelcomePlanQuestionBank.isFullyAnswered(answers: answers)
        let hasCompletedQuestionnaire = WelcomePlanStore.shared.isQuestionnaireComplete && isFullyAnswered

        if AppSession.shared.hasCompletedWelcomePlanChat, !hasCompletedQuestionnaire {
            AppSession.shared.setWelcomePlanChatCompleted(false)
        }
    }
}
