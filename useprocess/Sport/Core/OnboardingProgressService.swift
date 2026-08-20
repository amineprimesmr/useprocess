import Foundation

@MainActor
final class OnboardingProgressService {
    static let shared = OnboardingProgressService()

    private let userDefaults = UserDefaults.standard
    private static let legacyPrefix = (Bundle.main.bundleIdentifier ?? "useprocess") + ".sport."

    private var storageUserId: String {
        if AppSession.shared.hasCompletedOnboarding {
            return UserScopedStorage.currentUserId() ?? "onboarding-local"
        }
        return "onboarding-in-progress"
    }

    private func scopedKey(_ suffix: String) -> String {
        UserScopedStorage.key("onboarding.progress.\(suffix)", userId: storageUserId)
    }

    private init() {}

    /// Unifie la progression sous `onboarding-in-progress` (Auth pas encore prêt au 1er lancement).
    func migrateInProgressStorageIfNeeded() {
        guard !AppSession.shared.hasCompletedOnboarding else { return }

        let targetUID = "onboarding-in-progress"
        var sourceUIDs: [String] = ["onboarding-local"]
        if let uid = UserScopedStorage.currentUserId() {
            sourceUIDs.append(uid)
        }

        for suffix in ["current_step", "last_completed_step", "visited_steps", "answers", "flow_progress"] {
            let targetKey = UserScopedStorage.key("onboarding.progress.\(suffix)", userId: targetUID)
            guard userDefaults.object(forKey: targetKey) == nil else { continue }

            for uid in sourceUIDs {
                let sourceKey = UserScopedStorage.key("onboarding.progress.\(suffix)", userId: uid)
                guard let value = userDefaults.object(forKey: sourceKey) else { continue }
                userDefaults.set(value, forKey: targetKey)
                break
            }
        }
    }

    func saveCurrentStep(_ step: Int) {
        userDefaults.set(step, forKey: scopedKey("current_step"))
    }

    func loadCurrentStep() -> Int {
        if let value = userDefaults.object(forKey: scopedKey("current_step")) as? Int {
            return value
        }
        return userDefaults.integer(forKey: Self.legacyPrefix + "onboarding_current_step")
    }

    func saveLastCompletedStep(_ step: Int) {
        userDefaults.set(step, forKey: scopedKey("last_completed_step"))
    }

    func loadLastCompletedStep() -> Int {
        if let value = userDefaults.object(forKey: scopedKey("last_completed_step")) as? Int {
            return value
        }
        return userDefaults.integer(forKey: Self.legacyPrefix + "onboarding_last_completed_step")
    }

    func saveVisitedSteps(_ steps: [Int]) {
        userDefaults.set(steps, forKey: scopedKey("visited_steps"))
    }

    func loadVisitedSteps() -> [Int] {
        if let steps = userDefaults.array(forKey: scopedKey("visited_steps")) as? [Int] {
            return steps
        }
        return userDefaults.array(forKey: Self.legacyPrefix + "onboarding_visited_steps") as? [Int] ?? []
    }

    func saveFlowProgress(_ progress: Double) {
        userDefaults.set(min(max(progress, 0), 1), forKey: scopedKey("flow_progress"))
    }

    func loadFlowProgress() -> Double? {
        if userDefaults.object(forKey: scopedKey("flow_progress")) != nil {
            return min(max(userDefaults.double(forKey: scopedKey("flow_progress")), 0), 1)
        }
        guard userDefaults.object(forKey: Self.legacyPrefix + "onboarding_flow_progress") != nil else { return nil }
        return min(max(userDefaults.double(forKey: Self.legacyPrefix + "onboarding_flow_progress"), 0), 1)
    }

    func resetProgress() {
        resetProgress(userId: storageUserId)
        clearLegacyProgressKeys()
    }

    /// Efface la progression onboarding pour tous les identifiants connus (suppression de compte).
    func resetProgressForAccountDeletion(primaryUID: String) {
        var userIds = Set(UserScopedStorage.likelyUserIds(primary: primaryUID))
        userIds.insert("onboarding-local")
        userIds.insert("anonymous")
        userIds.insert("local-user")

        for uid in userIds {
            resetProgress(userId: uid)
        }

        clearLegacyProgressKeys()
    }

    private func resetProgress(userId: String) {
        for suffix in ["current_step", "last_completed_step", "visited_steps", "answers", "flow_progress"] {
            userDefaults.removeObject(forKey: UserScopedStorage.key("onboarding.progress.\(suffix)", userId: userId))
        }
    }

    private func clearLegacyProgressKeys() {
        userDefaults.removeObject(forKey: Self.legacyPrefix + "onboarding_current_step")
        userDefaults.removeObject(forKey: Self.legacyPrefix + "onboarding_last_completed_step")
        userDefaults.removeObject(forKey: Self.legacyPrefix + "onboarding_visited_steps")
        userDefaults.removeObject(forKey: Self.legacyPrefix + "onboarding_answers_cache")
        userDefaults.removeObject(forKey: Self.legacyPrefix + "onboarding_flow_progress")
    }

    func saveAnswers(_ snapshot: OnboardingAnswersSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: scopedKey("answers"))
    }

    func flush() {
        userDefaults.synchronize()
    }

    func loadAnswers() -> OnboardingAnswersSnapshot? {
        if let data = userDefaults.data(forKey: scopedKey("answers")) {
            return try? JSONDecoder().decode(OnboardingAnswersSnapshot.self, from: data)
        }
        guard let data = userDefaults.data(forKey: Self.legacyPrefix + "onboarding_answers_cache") else { return nil }
        return try? JSONDecoder().decode(OnboardingAnswersSnapshot.self, from: data)
    }

    func savePendingDataIfNeeded(to profileService: UnifiedProfileService) async {
        guard let snapshot = loadAnswers() else { return }
        guard var profile = profileService.currentProfile else { return }

        if let firstName = snapshot.firstName,
           OnboardingViewModel.isRealUserFirstName(firstName),
           !OnboardingViewModel.isRealUserFirstName(profile.firstName) {
            profile.firstName = firstName
        }

        if let age = snapshot.selectedAge, age > 0, age <= 120 {
            profile.updateAge(age)
        }

        if let height = snapshot.selectedHeight, height > 0 {
            profile.height = height
        }

        if let weight = snapshot.selectedWeight, OnboardingViewModel.isPlausibleWeight(weight) {
            profile.weight = weight
        }

        if let idealWeight = snapshot.idealWeightValue, OnboardingViewModel.isPlausibleWeight(idealWeight) {
            profile.idealWeight = idealWeight
        }

        if let gender = snapshot.selectedGender {
            profile.gender = gender
        }

        try? await profileService.saveProfile(profile)
    }
    func saveAge(_ age: Int, to profileService: UnifiedProfileService) async {
        guard var profile = profileService.currentProfile else { return }
        profile.updateAge(age)
        try? await profileService.saveProfile(profile)
    }
    func saveOptimizationGoals(_ goals: Set<String>, to profileService: UnifiedProfileService) async {}
    func saveTrainingFrequency(_ frequency: String, to profileService: UnifiedProfileService) async {}
    func savePlanData(
        mainGoal: MainGoal?,
        experienceLevel: ExperienceLevel?,
        yearsOfExperience: Int,
        sessionsPerWeek: Int,
        sessionDuration: Int,
        trainingLocation: TrainingLocation,
        equipment: Set<PlanEquipment>,
        weightGoal: WeightGoal?,
        to profileService: UnifiedProfileService
    ) async {}
}
