import Foundation

@MainActor
@Observable
final class WelcomePlanStore {
    static let shared = WelcomePlanStore()

    private(set) var questionnaire: WelcomePlanQuestionnaireState = WelcomePlanQuestionnaireState()
    private(set) var plan: FaceOriginPlan?

    private var previewBackup: (questionnaire: WelcomePlanQuestionnaireState, plan: FaceOriginPlan?)?

    var isPreviewSession: Bool { previewBackup != nil }

    private init() {
        reload()
    }

    func reload() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        questionnaire = loadQuestionnaire(userId: uid) ?? WelcomePlanQuestionnaireState()
        plan = loadPlan(userId: uid)
        repairAccessIfNeeded(profile: UnifiedProfileService.shared.currentProfile)
        if plan != nil {
            migratePlanIfNeeded(answers: questionnaire.answers, profile: UnifiedProfileService.shared.currentProfile)
        }
        CoachMemoryStore.shared.reloadForCurrentUser()

        if AppConfiguration.firebaseConfigured, uid != "local-user" {
            Task {
                await WelcomePlanFirestoreRepository.shared.syncFromRemote(userId: uid)
                reloadLocalOnly(uid: uid)
            }
        }
    }

    private func reloadLocalOnly(uid: String) {
        questionnaire = loadQuestionnaire(userId: uid) ?? WelcomePlanQuestionnaireState()
        plan = loadPlan(userId: uid)
        repairAccessIfNeeded(profile: UnifiedProfileService.shared.currentProfile)
        CoachMemoryStore.shared.reloadForCurrentUser()
    }

    func reloadForCurrentUser() {
        reload()
    }

    func saveAnswer(questionId: String, answer: WelcomePlanAnswer) {
        questionnaire.answers[questionId] = answer
        if !isPreviewSession {
            persistQuestionnaire()
        }
    }

    func markQuestionnaireComplete() {
        questionnaire.completedAt = Date()
        if !isPreviewSession {
            persistQuestionnaire()
        }
    }

    func savePlan(_ newPlan: FaceOriginPlan) {
        var enriched = newPlan
        if enriched.calendar.startedAt == nil {
            enriched.calendar.startedAt = enriched.createdAt
        }
        plan = enriched
        guard !isPreviewSession else { return }
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("welcome.plan", userId: uid)
        if let data = try? JSONEncoder().encode(enriched) {
            UserDefaults.standard.set(data, forKey: key)
        }
        Task {
            if uid != "local-user" {
                await WelcomePlanFirestoreRepository.shared.savePlan(enriched, userId: uid)
            }
            await OriginPlanNotificationService.scheduleMorningBrief(plan: enriched)
        }
    }

    func ensureCalendarIfMissing(answers: [String: WelcomePlanAnswer], profile: UnifiedUserProfile?) {
        guard var current = plan, current.calendar.weeks.isEmpty else { return }
        CoachPlanEditor.regenerateCalendarIfNeeded(plan: &current, answers: answers, profile: profile)
        savePlan(current)
    }

    func migratePlanIfNeeded(answers: [String: WelcomePlanAnswer]?, profile: UnifiedUserProfile?) {
        guard var current = plan else { return }
        var changed = false

        if current.calendar.weeks.isEmpty {
            CoachPlanEditor.regenerateCalendarIfNeeded(plan: &current, answers: answers ?? questionnaire.answers, profile: profile)
            changed = true
        }
        if current.calendar.startedAt == nil {
            current.calendar.startedAt = current.createdAt
            changed = true
        }
        if current.lifestyleExtras.bonusProposals.isEmpty {
            current.lifestyleExtras = OriginLifestyleExtras.default
            changed = true
        }
        if current.calendar.buildVersion < 5 {
            CoachPlanEditor.regenerateCalendar(
                plan: &current,
                answers: answers ?? questionnaire.answers,
                profile: profile
            )
            changed = true
        }

        if changed { savePlan(current) }
    }

    func setJournalTaskStatus(_ status: JournalTaskStatus?, taskId: String, dayId: String) {
        guard var current = plan else { return }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: dayId, in: current) else { return }
        let key = OriginPlanProgress.taskKey(dayId: dayId, taskId: taskId)
        if let status {
            current.progress.taskStatuses[key] = status
            if status == .completed {
                current.progress.completedTaskIds.insert(taskId)
            } else {
                current.progress.completedTaskIds.remove(taskId)
            }
        } else {
            current.progress.taskStatuses.removeValue(forKey: key)
            current.progress.completedTaskIds.remove(taskId)
        }
        syncJournalDayCompletion(on: &current, dayId: dayId)
        savePlan(current)
    }

    func toggleTaskComplete(taskId: String, dayId: String) {
        guard let current = plan else { return }
        let existing = current.progress.status(for: taskId, dayId: dayId)
        setJournalTaskStatus(existing == .completed ? nil : .completed, taskId: taskId, dayId: dayId)
    }

    func saveValidatedMeal(dayId: String, meal: String) {
        guard var current = plan else { return }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: dayId, in: current) else { return }
        current.progress.validatedMeals[dayId] = meal
        syncJournalDayCompletion(on: &current, dayId: dayId)
        savePlan(current)
    }

    func clearValidatedMeal(dayId: String) {
        guard var current = plan else { return }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: dayId, in: current) else { return }
        current.progress.validatedMeals.removeValue(forKey: dayId)
        savePlan(current)
    }

    func validatedMeal(for dayId: String) -> String? {
        plan?.progress.validatedMeals[dayId]
    }

    private func syncJournalDayCompletion(on plan: inout FaceOriginPlan, dayId: String) {
        guard let day = plan.calendar.weeks.flatMap(\.days).first(where: { $0.id == dayId }) else { return }
        if OriginPlanPresenter.isDayJournalFilled(plan: plan, day: day) {
            plan.progress.completedDayIds.insert(dayId)
            plan.lastUpdated = Date()
        } else {
            plan.progress.completedDayIds.remove(dayId)
        }
    }

    var hasQuestionnaireAnswers: Bool {
        !questionnaire.answers.isEmpty
    }

    var isQuestionnaireComplete: Bool {
        questionnaire.completedAt != nil
    }

    var canRestorePlan: Bool {
        plan == nil && hasQuestionnaireAnswers
    }

    /// Importe données locales d'un autre uid, régénère le plan si besoin, resynchronise le flag d'accès.
    @discardableResult
    func repairAccessIfNeeded(profile: UnifiedUserProfile?) -> Bool {
        importPersistedDataFromLikelyUsers()

        if plan == nil, hasQuestionnaireAnswers {
            regeneratePlanFromQuestionnaire(profile: profile)
        }

        if plan != nil {
            syncWelcomePlanCompletionFlag()
            return true
        }
        return false
    }

    func resetForCurrentUser() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("welcome.questionnaire", userId: uid))
        UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("welcome.plan", userId: uid))
        previewBackup = nil
        questionnaire = WelcomePlanQuestionnaireState()
        plan = nil
    }

    /// Réinitialise le questionnaire pour rejouer le chat d'accueil (preview / debug).
    func resetQuestionnaireForPreview() {
        beginPreviewSession()
    }

    /// Sauvegarde l'état réel, puis démarre un questionnaire vierge en mémoire (sans écraser le compte).
    func beginPreviewSession() {
        if previewBackup == nil {
            previewBackup = (questionnaire, plan)
        }
        questionnaire = WelcomePlanQuestionnaireState()
    }

    /// Restaure le questionnaire / plan réels après une preview abandonnée ou terminée.
    func endPreviewSession(restore: Bool = true) {
        guard let backup = previewBackup else { return }
        if restore {
            questionnaire = backup.questionnaire
            plan = backup.plan
        }
        previewBackup = nil
    }

    private func persistQuestionnaire() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("welcome.questionnaire", userId: uid)
        if let data = try? JSONEncoder().encode(questionnaire) {
            UserDefaults.standard.set(data, forKey: key)
        }
        if uid != "local-user" {
            Task { await WelcomePlanFirestoreRepository.shared.saveQuestionnaire(questionnaire, userId: uid) }
        }
    }

    private func loadQuestionnaire(userId: String) -> WelcomePlanQuestionnaireState? {
        let key = UserScopedStorage.key("welcome.questionnaire", userId: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WelcomePlanQuestionnaireState.self, from: data)
    }

    private func loadPlan(userId: String) -> FaceOriginPlan? {
        let key = UserScopedStorage.key("welcome.plan", userId: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FaceOriginPlan.self, from: data)
    }

    private func importPersistedDataFromLikelyUsers() {
        let targetUid = UserScopedStorage.currentUserId() ?? "local-user"

        if questionnaire.answers.isEmpty {
            for sourceUid in UserScopedStorage.likelyUserIds(primary: targetUid) {
                guard sourceUid != targetUid,
                      let imported = loadQuestionnaire(userId: sourceUid),
                      !imported.answers.isEmpty
                else { continue }
                questionnaire = imported
                persistQuestionnaire()
                break
            }
        }

        if plan == nil {
            for sourceUid in UserScopedStorage.likelyUserIds(primary: targetUid) {
                guard sourceUid != targetUid, let imported = loadPlan(userId: sourceUid) else { continue }
                savePlan(imported)
                break
            }
        }
    }

    private func regeneratePlanFromQuestionnaire(profile: UnifiedUserProfile?) {
        guard hasQuestionnaireAnswers else { return }
        let regenerated = WelcomePlanGenerator.generate(answers: questionnaire.answers, profile: profile)
        if !isQuestionnaireComplete {
            markQuestionnaireComplete()
        }
        savePlan(regenerated)
    }

    private func syncWelcomePlanCompletionFlag() {
        guard AppSession.shared.hasCompletedOnboarding, plan != nil else { return }
        if isQuestionnaireComplete || hasQuestionnaireAnswers {
            AppSession.shared.completeWelcomePlanChat()
        }
    }
}

enum WelcomePlanProfileSync {

    @MainActor
    static func apply(
        answers: [String: WelcomePlanAnswer],
        plan: FaceOriginPlan,
        profileService: UnifiedProfileService
    ) async {
        guard var profile = profileService.currentProfile else { return }

        profile.sleepProfile = buildSleepProfile(from: answers, existing: profile.sleepProfile)
        profile.nutritionProfile = buildNutritionProfile(from: answers, existing: profile.nutritionProfile)
        profile.sessionsPerWeek = plan.trainingProtocol.sessionsPerWeek
        profile.sessionDuration = plan.trainingProtocol.sessionDurationMinutes

        if let locRaw = answers["training_location"]?.choiceIds.first,
           let loc = TrainingLocation(rawValue: locRaw) {
            profile.trainingLocation = loc
            profile.availableEquipment = equipment(for: loc)
        }

        if let expRaw = answers["training_experience"]?.choiceIds.first,
           let exp = ExperienceLevel(rawValue: expRaw) {
            profile.experienceLevel = exp
        }

        profile.accountObjective = plan.primaryFaceGoal
        profile.mainGoal = .sante

        try? await profileService.saveProfile(profile)
    }

    private static func buildSleepProfile(from answers: [String: WelcomePlanAnswer], existing: SleepProfile?) -> SleepProfile {
        var sleep = existing ?? SleepProfile()

        if let qRaw = answers["sleep_quality"]?.choiceIds.first,
           let q = OnboardingSleepQuality(rawValue: qRaw) {
            sleep.sleepQuality = q
        }
        if let fRaw = answers["fatigue_frequency"]?.choiceIds.first,
           let f = FatigueFrequency(rawValue: fRaw) {
            sleep.fatigueFrequency = f
        }
        let peaks = answers["fatigue_peaks"]?.choiceIds.compactMap { FatiguePeaks(rawValue: $0) } ?? []
        if !peaks.isEmpty { sleep.fatiguePeaks = Set(peaks) }

        sleep.bedtimePreference = answers["bedtime"]?.timeValue
        sleep.wakeTimePreference = answers["wake_time"]?.timeValue

        if let bed = answers["bedtime"]?.timeValue, let wake = answers["wake_time"]?.timeValue {
            sleep.averageSleepHours = WelcomePlanGenerator.computedSleepHours(bedtime: bed, wake: wake)
        }

        var issues: [String] = []
        if answers["screen_before_bed"]?.choiceIds.first == "yes" { issues.append("Écrans avant coucher") }
        if answers["caffeine_afternoon"]?.choiceIds.first == "yes" { issues.append("Caféine après-midi") }
        sleep.sleepIssues = issues

        return sleep
    }

    private static func buildNutritionProfile(from answers: [String: WelcomePlanAnswer], existing: NutritionProfile?) -> NutritionProfile {
        var nutrition = existing ?? NutritionProfile()

        if let qRaw = answers["nutrition_quality"]?.choiceIds.first,
           let q = NutritionQuality(rawValue: qRaw) {
            nutrition.nutritionQuality = q
        }
        if let hRaw = answers["hydration_level"]?.choiceIds.first,
           let h = HydrationLevel(rawValue: hRaw) {
            nutrition.hydrationLevel = h
        }

        let restrictions = answers["dietary_restrictions"]?.choiceIds.compactMap { DietaryRestriction(rawValue: $0) } ?? []
        if !restrictions.isEmpty { nutrition.dietaryRestrictions = Set(restrictions) }

        let obstacles = answers["nutrition_obstacles"]?.choiceIds.compactMap { NutritionObstacle(rawValue: $0) } ?? []
        if !obstacles.isEmpty { nutrition.nutritionObstacles = Set(obstacles) }

        return nutrition
    }

    private static func equipment(for location: TrainingLocation) -> [PlanEquipment] {
        switch location {
        case .gym: return [.fullGym]
        case .home: return [.dumbbells, .resistanceBands, .pullupBar]
        case .outdoor: return [.none]
        case .mixed: return [.dumbbells, .resistanceBands, .fullGym]
        }
    }
}
