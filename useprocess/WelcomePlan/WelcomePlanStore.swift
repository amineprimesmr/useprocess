import Foundation

@MainActor
@Observable
final class WelcomePlanStore {
    static let shared = WelcomePlanStore()

    private(set) var questionnaire: WelcomePlanQuestionnaireState = WelcomePlanQuestionnaireState()
    private(set) var plan: FaceOriginPlan?
    private var remoteSyncTask: Task<Void, Never>?
    private var planSideEffectsTask: Task<Void, Never>?
    private var lastRemoteSyncAt: Date?
    private var lastRemoteSyncUserId: String?
    private var loadedUserId: String?
    private var persistenceGeneration: UInt64 = 0
    private let remoteSyncMinInterval: TimeInterval = 60
    /// Plan généré uniquement pour l’aperçu onboarding — jamais persisté.
    private var hasEphemeralPreviewPlan = false

    private init() {
        reload(force: true)
    }

    func reload(force: Bool = false) {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let userChanged = loadedUserId != uid
        guard force || userChanged else { return }
        loadedUserId = uid
        questionnaire = loadQuestionnaire(userId: uid) ?? WelcomePlanQuestionnaireState()
        if !hasEphemeralPreviewPlan {
            if let loaded = loadPlan(userId: uid) {
                plan = loaded
                repairAccessIfNeeded(profile: UnifiedProfileService.shared.currentProfile)
                migratePlanIfNeeded(answers: questionnaire.answers, profile: UnifiedProfileService.shared.currentProfile)
            } else if plan == nil {
                repairAccessIfNeeded(profile: UnifiedProfileService.shared.currentProfile)
            }
        }
        CoachMemoryStore.shared.reloadForCurrentUser()
        if userChanged {
            ProcessDebloatTrajectoryStore.shared.reload()
        }
        ProcessDebloatTrajectoryStore.shared.sync(from: plan)

        if AppConfiguration.firebaseConfigured, uid != "local-user" {
            scheduleRemoteSyncIfNeeded(uid: uid)
        }
    }

    private func reloadLocalOnly(uid: String) {
        questionnaire = loadQuestionnaire(userId: uid) ?? WelcomePlanQuestionnaireState()
        if !hasEphemeralPreviewPlan {
            if let loaded = loadPlan(userId: uid) {
                plan = loaded
                repairAccessIfNeeded(profile: UnifiedProfileService.shared.currentProfile)
            } else if plan == nil {
                repairAccessIfNeeded(profile: UnifiedProfileService.shared.currentProfile)
            }
        }
        CoachMemoryStore.shared.reloadForCurrentUser()
        ProcessDebloatTrajectoryStore.shared.sync(from: plan)
    }

    /// Installe un plan en mémoire pour l’aperçu dashboard, sans écriture disque.
    /// Toujours régénéré depuis le profil onboarding — jamais bloqué par un reload distant.
    func installEphemeralPreviewPlanIfNeeded(profile: UnifiedUserProfile?) {
        if hasEphemeralPreviewPlan, plan != nil { return }
        installFreshEphemeralPreviewPlan(profile: profile)
    }

    /// Force un plan preview complet (utilisé si l’aperçu a monté avant que le plan soit prêt).
    func refreshEphemeralPreviewPlan(profile: UnifiedUserProfile?) {
        installFreshEphemeralPreviewPlan(profile: profile)
    }

    private func installFreshEphemeralPreviewPlan(profile: UnifiedUserProfile?) {
        // Poser le flag avant toute génération : bloque reloadLocalOnly / sync Firebase
        // d’écraser le plan pendant l’aperçu onboarding.
        hasEphemeralPreviewPlan = true

        let answers = WelcomePlanQuestionBank.prefillAnswersFromOnboarding(profile: profile)
        let generated = WelcomePlanGenerator.generate(
            answers: answers,
            profile: profile
        )
        plan = generated
        ProcessDebloatTrajectoryStore.shared.sync(from: plan)
        ProcessPlanProgressStore.shared.reload(plan: plan)
    }

    func clearEphemeralPreviewPlan() {
        guard hasEphemeralPreviewPlan else { return }
        hasEphemeralPreviewPlan = false
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        plan = loadPlan(userId: uid)
        ProcessDebloatTrajectoryStore.shared.sync(from: plan)
        ProcessPlanProgressStore.shared.reload(plan: plan)
    }

    func reloadForCurrentUser(force: Bool = false) {
        reload(force: force)
    }

    private func scheduleRemoteSyncIfNeeded(uid: String) {
        guard remoteSyncTask == nil else { return }
        let isSameUser = lastRemoteSyncUserId == uid
        if let lastRemoteSyncAt,
           isSameUser,
           Date().timeIntervalSince(lastRemoteSyncAt) < remoteSyncMinInterval {
            return
        }

        lastRemoteSyncAt = Date()
        lastRemoteSyncUserId = uid
        remoteSyncTask = Task { @MainActor in
            defer { remoteSyncTask = nil }
            await WelcomePlanFirestoreRepository.shared.syncFromRemote(userId: uid)
            guard !Task.isCancelled else { return }
            reloadLocalOnly(uid: uid)
        }
    }

    func saveAnswer(questionId: String, answer: WelcomePlanAnswer) {
        let isFirstAnswer = questionnaire.answers.isEmpty
        questionnaire.answers[questionId] = answer
        if isFirstAnswer {
            questionnaire.startedAt = Date()
        }
        persistQuestionnaire()
    }

    /// Sauvegarde l'état courant du questionnaire (reprise après sortie).
    func touchQuestionnaireProgress() {
        persistQuestionnaire()
    }

    func removeAnswers(for questionIds: [String]) {
        for questionId in questionIds {
            questionnaire.answers.removeValue(forKey: questionId)
        }
        persistQuestionnaire()
    }

    func markQuestionnaireComplete() {
        questionnaire.completedAt = Date()
        persistQuestionnaire()
    }

    func savePlan(_ newPlan: FaceOriginPlan, structureChanged: Bool = false) {
        var enriched = newPlan
        enriched.lastUpdated = Date()
        if enriched.calendar.startedAt == nil {
            enriched.calendar.startedAt = enriched.createdAt
        }
        let previous = plan
        let shouldRefreshStreak = previous == nil
            || previous?.calendar.startedAt != enriched.calendar.startedAt
            || previous?.calendar.totalDays != enriched.calendar.totalDays
            || previous?.progress.taskStatuses != enriched.progress.taskStatuses
            || previous?.progress.completedTaskIds != enriched.progress.completedTaskIds
        plan = enriched
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let planKey = UserScopedStorage.key("welcome.plan", userId: uid)
        let progressKey = UserScopedStorage.key("welcome.plan.progress", userId: uid)
        persistenceGeneration &+= 1
        let generation = persistenceGeneration
        let shouldPersistStructure = structureChanged || previous == nil || previous?.id != enriched.id
        let structureSnapshot: FaceOriginPlan? = if shouldPersistStructure {
            {
                var snapshot = enriched
                snapshot.progress = OriginPlanProgress()
                return snapshot
            }()
        } else {
            nil
        }
        let progressSnapshot = StoredOriginPlanProgress(
            progress: enriched.progress,
            lastUpdated: enriched.lastUpdated
        )
        Task.detached(priority: .utility) {
            if let structureSnapshot {
                await ProcessPersistenceWriter.shared.store(
                    structureSnapshot,
                    forKey: planKey,
                    generation: generation
                )
            }
            await ProcessPersistenceWriter.shared.store(
                progressSnapshot,
                forKey: progressKey,
                generation: generation
            )
        }
        if shouldRefreshStreak {
            ProcessStreakStore.shared.sync(from: enriched)
        }

        // Une rafale de mutations (création des repas par défaut, checklist…)
        // ne doit produire qu'un seul upload et une seule replanification.
        planSideEffectsTask?.cancel()
        planSideEffectsTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            if uid != "local-user" {
                await WelcomePlanFirestoreRepository.shared.savePlan(enriched, userId: uid)
            }
            await CoachDailyRhythmService.rescheduleAll()
        }
    }

    /// Studio : décale le jour 1 du programme (page Progrès + calendrier).
    func updateCalendarStartedAt(_ date: Date) {
        guard var current = plan else { return }
        let start = Calendar.current.startOfDay(for: date)
        if let existing = current.calendar.startedAt,
           Calendar.current.isDate(existing, inSameDayAs: start) {
            return
        }
        current.calendar.startedAt = start
        savePlan(current, structureChanged: true)
        ProcessPlanProgressStore.shared.reload(plan: current)
    }

    func ensureCalendarIfMissing(answers: [String: WelcomePlanAnswer], profile: UnifiedUserProfile?) {
        guard var current = plan, current.calendar.weeks.isEmpty else { return }
        CoachPlanEditor.regenerateCalendarIfNeeded(plan: &current, answers: answers, profile: profile)
        savePlan(current, structureChanged: true)
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
        if current.calendar.buildVersion < 7 || current.assessmentSnapshot == nil {
            upgradePlanStructure(
                plan: &current,
                answers: answers ?? questionnaire.answers,
                profile: profile
            )
            changed = true
        }

        if current.calendar.buildVersion < 8 {
            repairStoredMealImageAssets(plan: &current)
            current.calendar.buildVersion = 8
            changed = true
        }

        if current.calendar.buildVersion < 9 {
            repairStoredMealImageAssets(plan: &current)
            current.calendar.buildVersion = 9
            changed = true
        }

        // v10 — retire les séances muscu du calendrier (push/pull/legs).
        if current.calendar.buildVersion < 10 {
            upgradePlanStructure(
                plan: &current,
                answers: answers ?? questionnaire.answers,
                profile: profile
            )
            current.calendar.buildVersion = 10
            changed = true
        }

        if current.nutritionProtocol.targetMealsPerDay == nil {
            ProcessMealPlanConfiguration.enrichNutritionProtocol(
                &current.nutritionProtocol,
                answers: answers ?? questionnaire.answers
            )
            if let target = current.nutritionProtocol.targetMealsPerDay {
                ProcessMealPlanConfiguration.applyTargetMeals(target, to: &current)
                changed = true
            }
        }

        if shouldRecalibratePlanDuration(plan: current, profile: profile) {
            recalibratePlanDuration(
                plan: &current,
                answers: answers ?? questionnaire.answers,
                profile: profile
            )
            changed = true
        }

        if shouldAlignCalendarToTrajectory(plan: current) {
            upgradePlanStructure(
                plan: &current,
                answers: answers ?? questionnaire.answers,
                profile: profile
            )
            changed = true
        }

        if changed { savePlan(current, structureChanged: true) }
    }

    private func shouldAlignCalendarToTrajectory(plan: FaceOriginPlan) -> Bool {
        guard let debloatDays = plan.assessmentSnapshot?.debloatTargetDays, debloatDays > 0 else {
            return false
        }
        return plan.calendar.totalDays < debloatDays
    }

    private func shouldRecalibratePlanDuration(
        plan: FaceOriginPlan,
        profile: UnifiedUserProfile?
    ) -> Bool {
        let snapshotVersion = plan.assessmentSnapshot?.assessmentVersion ?? 0
        if snapshotVersion < OriginPlanAssessmentSnapshot.currentVersion {
            return true
        }

        let signals = PlanDurationPersonalizer.signals(profile: profile)
        guard signals.isLean, signals.isSporty, (signals.weightGapKg ?? 99) <= 6 else {
            return false
        }
        return plan.totalWeeks >= 8
    }

    private func recalibratePlanDuration(
        plan: inout FaceOriginPlan,
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?
    ) {
        let preservedProgress = plan.progress
        let startedAt = plan.calendar.startedAt ?? plan.createdAt
        let fresh = WelcomePlanGenerator.generate(answers: answers, profile: profile)
        plan = plan.mergingUpgrade(
            from: fresh,
            progress: preservedProgress,
            calendarStartedAt: startedAt
        )
    }

    /// Regénère structure, calendrier et assessment — conserve progrès et identité.
    private func upgradePlanStructure(
        plan: inout FaceOriginPlan,
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?
    ) {
        let preservedProgress = plan.progress
        let startedAt = plan.calendar.startedAt ?? plan.createdAt

        let fresh = WelcomePlanGenerator.generate(answers: answers, profile: profile)
        plan = plan.mergingUpgrade(
            from: fresh,
            progress: preservedProgress,
            calendarStartedAt: startedAt
        )
    }

    /// Réaligne `imageAssetName` sur les repas draft/validés (legacy IA sans asset valide).
    private func repairStoredMealImageAssets(plan: inout FaceOriginPlan) {
        let days = plan.calendar.weeks.flatMap(\.days)
        let planType = plan.nutritionPlanType

        func repairPayload(_ payload: String, slot: MealTimeSlot, dayIndex: Int) -> String? {
            guard var meal = MealSuggestionContent.fromStored(payload) else { return nil }
            let resolved = MealNutritionCatalog.resolvedImageAsset(
                for: meal,
                slot: slot,
                dayIndex: dayIndex,
                planType: planType
            )
            guard meal.imageAssetName != resolved else { return nil }
            meal.imageAssetName = resolved
            return meal.encodedForStorage()
        }

        for day in days {
            for slot in plan.configuredMealSlots {
                if let payload = plan.progress.draftMealsBySlot[day.id]?[slot.rawValue],
                   let repaired = repairPayload(payload, slot: slot, dayIndex: day.globalDayIndex) {
                    plan.progress.draftMealsBySlot[day.id]?[slot.rawValue] = repaired
                }
                if let payload = plan.progress.validatedMealsBySlot[day.id]?[slot.rawValue],
                   let repaired = repairPayload(payload, slot: slot, dayIndex: day.globalDayIndex) {
                    plan.progress.validatedMealsBySlot[day.id]?[slot.rawValue] = repaired
                    if slot == .lunch {
                        plan.progress.validatedMeals[day.id] = repaired
                    }
                }
            }
        }
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

    func isDailyRoutineItemCompleted(carouselItemId: String, dayId: String) -> Bool {
        guard let plan else { return false }
        return DailyRoutineCompletionCatalog.isCompleted(
            plan: plan,
            dayId: dayId,
            carouselItemId: carouselItemId
        )
    }

    /// Valide une carte routine (maintien 5 s) et aligne les leviers journal agrégés.
    func completeDailyRoutineItem(carouselItemId: String, dayId: String) {
        guard var current = plan else { return }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: dayId, in: current) else { return }

        let taskId = DailyRoutineCompletionCatalog.taskId(
            dayId: dayId,
            carouselItemId: carouselItemId
        )
        let key = OriginPlanProgress.taskKey(dayId: dayId, taskId: taskId)
        guard current.progress.taskStatuses[key] != .completed else { return }

        current.progress.taskStatuses[key] = .completed
        current.progress.completedTaskIds.insert(taskId)
        DailyRoutineCompletionCatalog.syncAggregatedJournalTasks(on: &current, dayId: dayId)
        syncJournalDayCompletion(on: &current, dayId: dayId)
        savePlan(current)
    }

    /// Aligne la tâche « Repas debloat » si un repas est déjà validé.
    func syncCoreJournalTasks(dayId: String) {
        guard var current = plan else { return }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: dayId, in: current) else { return }
        guard JournalCoreTaskCatalog.isNutritionSatisfied(plan: current, dayId: dayId) else { return }

        let taskId = JournalCoreTaskCatalog.nutritionTaskId(for: dayId)
        guard current.progress.status(for: taskId, dayId: dayId) != .completed else { return }

        let key = OriginPlanProgress.taskKey(dayId: dayId, taskId: taskId)
        current.progress.taskStatuses[key] = .completed
        current.progress.completedTaskIds.insert(taskId)
        syncJournalDayCompletion(on: &current, dayId: dayId)
        savePlan(current)
    }

    /// Valide les 4 leviers + tâches bonus (posture) en un tap.
    func completeAllJournalTasks(dayId: String) {
        guard var current = plan else { return }
        guard let day = current.calendar.weeks.flatMap(\.days).first(where: { $0.id == dayId }) else { return }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: dayId, in: current) else { return }

        let tasks = JournalCoreTaskCatalog.allCompletableTasks(day: day, plan: current)
        for task in tasks {
            let key = OriginPlanProgress.taskKey(dayId: dayId, taskId: task.id)
            current.progress.taskStatuses[key] = .completed
            current.progress.completedTaskIds.insert(task.id)
        }
        syncJournalDayCompletion(on: &current, dayId: dayId)
        savePlan(current)
    }

    func clearValidatedMeal(dayId: String, slot: MealTimeSlot? = nil) {
        guard var current = plan else { return }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: dayId, in: current) else { return }

        if let slot {
            current.progress.validatedMealsBySlot[dayId]?.removeValue(forKey: slot.rawValue)
            current.progress.draftMealsBySlot[dayId]?.removeValue(forKey: slot.rawValue)
            if current.progress.validatedMealsBySlot[dayId]?.isEmpty == true {
                current.progress.validatedMealsBySlot.removeValue(forKey: dayId)
            }
            if current.progress.draftMealsBySlot[dayId]?.isEmpty == true {
                current.progress.draftMealsBySlot.removeValue(forKey: dayId)
            }
            if slot == .lunch {
                current.progress.validatedMeals.removeValue(forKey: dayId)
            }
        } else {
            current.progress.validatedMeals.removeValue(forKey: dayId)
            current.progress.validatedMealsBySlot.removeValue(forKey: dayId)
            current.progress.draftMealsBySlot.removeValue(forKey: dayId)
        }
        savePlan(current)
    }

    func validatedMeal(for dayId: String) -> String? {
        plan?.progress.validatedMeals[dayId]
    }

    func syncJournalDayCompletion(on plan: inout FaceOriginPlan, dayId: String) {
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
        let questionnaireKey = UserScopedStorage.key("welcome.questionnaire", userId: uid)
        let planKey = UserScopedStorage.key("welcome.plan", userId: uid)
        let progressKey = UserScopedStorage.key("welcome.plan.progress", userId: uid)
        planSideEffectsTask?.cancel()
        UserDefaults.standard.removeObject(forKey: questionnaireKey)
        UserDefaults.standard.removeObject(forKey: planKey)
        UserDefaults.standard.removeObject(forKey: progressKey)
        persistenceGeneration &+= 1
        let generation = persistenceGeneration
        Task.detached(priority: .utility) {
            await ProcessPersistenceWriter.shared.removeValue(
                forKey: questionnaireKey,
                generation: generation
            )
            await ProcessPersistenceWriter.shared.removeValue(
                forKey: planKey,
                generation: generation
            )
            await ProcessPersistenceWriter.shared.removeValue(
                forKey: progressKey,
                generation: generation
            )
        }
        questionnaire = WelcomePlanQuestionnaireState()
        hasEphemeralPreviewPlan = false
        plan = nil
    }

    private func persistQuestionnaire() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("welcome.questionnaire", userId: uid)
        let snapshot = questionnaire
        persistenceGeneration &+= 1
        let generation = persistenceGeneration
        Task.detached(priority: .utility) {
            await ProcessPersistenceWriter.shared.store(
                snapshot,
                forKey: key,
                generation: generation
            )
        }
        if uid != "local-user" {
            Task { await WelcomePlanFirestoreRepository.shared.saveQuestionnaire(snapshot, userId: uid) }
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
        guard var decoded = try? JSONDecoder().decode(FaceOriginPlan.self, from: data) else {
            return nil
        }
        let progressKey = UserScopedStorage.key("welcome.plan.progress", userId: userId)
        if let progressData = UserDefaults.standard.data(forKey: progressKey) {
            if let stored = try? JSONDecoder().decode(StoredOriginPlanProgress.self, from: progressData) {
                decoded.progress = stored.progress
                decoded.lastUpdated = max(decoded.lastUpdated, stored.lastUpdated)
            } else if let progress = try? JSONDecoder().decode(OriginPlanProgress.self, from: progressData) {
                decoded.progress = progress
            }
        }
        return decoded
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
                savePlan(imported, structureChanged: true)
                break
            }
        }
    }

    private func regeneratePlanFromQuestionnaire(profile: UnifiedUserProfile?) {
        guard hasQuestionnaireAnswers else { return }
        guard WelcomePlanQuestionBank.isFullyAnswered(answers: questionnaire.answers) else { return }
        let regenerated = WelcomePlanGenerator.generate(answers: questionnaire.answers, profile: profile)
        if !isQuestionnaireComplete {
            markQuestionnaireComplete()
        }
        savePlan(regenerated, structureChanged: true)
    }

    /// Génère un plan depuis l'onboarding et valide le protocole sans questionnaire.
    func autoCompleteWelcomePlanIfNeeded(profile: UnifiedUserProfile?) {
        guard AppSession.shared.hasCompletedOnboarding else { return }
        if AppSession.shared.hasCompletedWelcomePlanChat,
           plan != nil,
           isQuestionnaireComplete,
           WelcomePlanQuestionBank.isFullyAnswered(answers: questionnaire.answers) {
            return
        }

        let answers: [String: WelcomePlanAnswer]
        if WelcomePlanQuestionBank.isFullyAnswered(answers: questionnaire.answers) {
            answers = questionnaire.answers
        } else {
            var merged = WelcomePlanQuestionBank.prefillAnswersFromOnboarding(profile: profile)
            // Conserve les réponses déjà saisies, complète le reste.
            for (questionId, answer) in questionnaire.answers {
                merged[questionId] = answer
            }
            answers = merged
            for (questionId, answer) in answers {
                questionnaire.answers[questionId] = answer
            }
            persistQuestionnaire()
        }

        if questionnaire.completedAt == nil {
            markQuestionnaireComplete()
        }

        if plan == nil {
            let generated = WelcomePlanGenerator.generate(answers: answers, profile: profile)
            savePlan(generated, structureChanged: true)
        } else if hasEphemeralPreviewPlan, let existing = plan {
            hasEphemeralPreviewPlan = false
            savePlan(existing, structureChanged: true)
        }

        AppSession.shared.completeWelcomePlanChat()
    }

    /// Ancien aperçu — redirige vers la complétion automatique (plus de questionnaire).
    func seedPreviewPlanIfNeeded(profile: UnifiedUserProfile?) {
        autoCompleteWelcomePlanIfNeeded(profile: profile)
    }

    private func syncWelcomePlanCompletionFlag() {
        guard plan != nil else { return }
        guard questionnaire.completedAt != nil else { return }
        guard WelcomePlanQuestionBank.isFullyAnswered(answers: questionnaire.answers) else { return }

        let uid = UserScopedStorage.currentUserId()
            ?? UnifiedProfileService.shared.currentProfile?.userId
            ?? "local-user"
        let onboardingKey = UserScopedStorage.key("onboarding.completed", userId: uid)
        guard UserDefaults.standard.bool(forKey: onboardingKey) else { return }

        let welcomeKey = UserScopedStorage.key("welcome.plan.chat.completed", userId: uid)
        UserDefaults.standard.set(true, forKey: welcomeKey)

        Task { @MainActor in
            guard AppSession.shared.hasCompletedOnboarding else { return }
            AppSession.shared.setWelcomePlanChatCompleted(true)
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
        if answers["screen_before_bed"]?.choiceIds.first == "yes" {
            issues.append(AppCopy.tSync("Écrans avant coucher", en: "Screens before bed"))
        }
        if answers["caffeine_afternoon"]?.choiceIds.first == "yes" {
            issues.append(AppCopy.tSync("Caféine après-midi", en: "Afternoon caffeine"))
        }
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
