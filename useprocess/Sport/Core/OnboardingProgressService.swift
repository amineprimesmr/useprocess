import Foundation

@MainActor
final class OnboardingProgressService {
    static let shared = OnboardingProgressService()

    private let userDefaults = UserDefaults.standard
    private let prefix = (Bundle.main.bundleIdentifier ?? "useprocess") + ".sport."
    private var currentStepKey: String { prefix + "onboarding_current_step" }
    private var lastCompletedStepKey: String { prefix + "onboarding_last_completed_step" }
    private var visitedStepsKey: String { prefix + "onboarding_visited_steps" }
    private var answersKey: String { prefix + "onboarding_answers_cache" }
    private var flowProgressKey: String { prefix + "onboarding_flow_progress" }

    private init() {}

    func saveCurrentStep(_ step: Int) {
        userDefaults.set(step, forKey: currentStepKey)
    }

    func loadCurrentStep() -> Int {
        userDefaults.integer(forKey: currentStepKey)
    }

    func saveLastCompletedStep(_ step: Int) {
        userDefaults.set(step, forKey: lastCompletedStepKey)
    }

    func loadLastCompletedStep() -> Int {
        userDefaults.integer(forKey: lastCompletedStepKey)
    }

    func saveVisitedSteps(_ steps: [Int]) {
        userDefaults.set(steps, forKey: visitedStepsKey)
    }

    func loadVisitedSteps() -> [Int] {
        userDefaults.array(forKey: visitedStepsKey) as? [Int] ?? []
    }

    func saveFlowProgress(_ progress: Double) {
        userDefaults.set(min(max(progress, 0), 1), forKey: flowProgressKey)
    }

    func loadFlowProgress() -> Double? {
        guard userDefaults.object(forKey: flowProgressKey) != nil else { return nil }
        return min(max(userDefaults.double(forKey: flowProgressKey), 0), 1)
    }

    func resetProgress() {
        userDefaults.removeObject(forKey: currentStepKey)
        userDefaults.removeObject(forKey: lastCompletedStepKey)
        userDefaults.removeObject(forKey: visitedStepsKey)
        userDefaults.removeObject(forKey: answersKey)
        userDefaults.removeObject(forKey: flowProgressKey)
    }

    func saveAnswers(_ snapshot: OnboardingAnswersSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: answersKey)
    }

    func flush() {
        userDefaults.synchronize()
    }

    func loadAnswers() -> OnboardingAnswersSnapshot? {
        guard let data = userDefaults.data(forKey: answersKey) else { return nil }
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
