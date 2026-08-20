import Foundation

struct PlanHomeGreeting: Equatable {
    let line: String
}

/// Salutation accueil — « Salut {prénom} » / « Hi {name} ».
enum PlanHomeGreetingBuilder {
    @MainActor
    static func make(profile: UnifiedUserProfile?) -> PlanHomeGreeting {
        .init(line: salut(resolvedFirstName(from: profile)))
    }

    @MainActor
    static func resolvedFirstName(from profile: UnifiedUserProfile?) -> String {
        let profileName = profile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if OnboardingViewModel.isRealUserFirstName(profileName) {
            return profileName
        }

        let snapshotName = OnboardingProgressService.shared.loadAnswers()?.firstName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if OnboardingViewModel.isRealUserFirstName(snapshotName) {
            return snapshotName
        }

        let pendingName = UserDefaults.standard.string(forKey: "pending_firstname_to_save")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if OnboardingViewModel.isRealUserFirstName(pendingName) {
            return pendingName
        }

        let authDisplayName = AuthUser.current?.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if OnboardingViewModel.isRealUserFirstName(authDisplayName) {
            return authDisplayName
        }

        return ""
    }

    @MainActor
    private static func salut(_ firstName: String) -> String {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return AppCopy.t("Salut", en: "Hi") }
        return AppCopy.t("Salut \(name)", en: "Hi \(name)")
    }
}
