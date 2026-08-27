import Foundation

enum EveningCheckInQuestionID {
    static let water = "water"
    static let debloatMeal = "debloatMeal"
    /// Legacy — plus affiché dans la checklist, conservé pour l’historique trajectoire.
    static let cardio = "cardio"
    static let morningRoutine = "morningRoutine"
    static let faceScan = "faceScan"
    static let legacyPostureCircuit = "postureCircuit"

    /// Leviers debloat — score, streak et validation jour.
    static let debloatLevers: [String] = [water, debloatMeal]
    /// Toutes les questions affichées dans la checklist.
    static let all: [String] = [faceScan, morningRoutine] + debloatLevers
}

struct ProcessEveningCheckInDayRecord: nonisolated Codable, Equatable, Sendable {
    var answers: [String: String] = [:]
}

struct ProcessEveningCheckInState: nonisolated Codable, Equatable, Sendable {
    var submittedDayKeys: Set<String> = []
    var recordsByDay: [String: ProcessEveningCheckInDayRecord] = [:]
}

/// Soumissions du bilan du soir — seule source de validation de la streak.
@MainActor
@Observable
final class ProcessEveningCheckInStore {
    static let shared = ProcessEveningCheckInStore()

    private(set) var submittedDayKeys: Set<String> = []
    private(set) var recordsByDay: [String: ProcessEveningCheckInDayRecord] = [:]
    private var persistenceGeneration: UInt64 = 0

    private init() {
        reload()
    }

    func reload() {
        let state = loadState()
        submittedDayKeys = state?.submittedDayKeys ?? []
        recordsByDay = state?.recordsByDay ?? [:]
    }

    var hasSubmittedToday: Bool {
        hasSubmitted(on: Date())
    }

    func hasSubmitted(on date: Date) -> Bool {
        submittedDayKeys.contains(ProcessStreakStore.dayKey(for: date))
    }

    func answers(for date: Date = Date()) -> [String: String] {
        let key = ProcessStreakStore.dayKey(for: date)
        return sanitizedAnswers(recordsByDay[key]?.answers ?? [:])
    }

    func markSubmitted(answers: [String: String] = [:], for date: Date = Date()) {
        let key = ProcessStreakStore.dayKey(for: date)
        let sanitized = sanitizedAnswers(answers)
        var keys = submittedDayKeys
        keys.insert(key)
        submittedDayKeys = keys
        var records = recordsByDay
        var record = records[key] ?? ProcessEveningCheckInDayRecord()
        record.answers = sanitized
        records[key] = record
        recordsByDay = records
        persist()
        applyAnswersToPlan(sanitized, for: date)
        ProcessDebloatTrajectoryStore.shared.recordCheckIn(answers: sanitized, for: date)
    }

    private func sanitizedAnswers(_ answers: [String: String]) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: answers.filter { EveningCheckInQuestionID.all.contains($0.key) }
        )
    }

    private func applyAnswersToPlan(_ answers: [String: String], for date: Date) {
        guard let plan = WelcomePlanStore.shared.plan else { return }
        guard let day = OriginPlanPresenter.programDay(in: plan, for: date)
            ?? OriginPlanPresenter.todayDay(in: plan, date: date)
        else { return }

        let dayId = day.id
        let planStore = WelcomePlanStore.shared

        if let water = answers[EveningCheckInQuestionID.water] {
            if water == "yes" {
                ProcessHydrationLogStore.shared.applyEveningCheckInWaterAnswer(
                    water,
                    for: date,
                    dayId: dayId
                )
            }
            planStore.setJournalTaskStatus(
                water == "yes" ? .completed : .failed,
                taskId: "\(dayId).core.hydrate",
                dayId: dayId
            )
        }

        if let meal = answers[EveningCheckInQuestionID.debloatMeal] {
            planStore.setJournalTaskStatus(
                meal == "yes" ? .completed : .failed,
                taskId: JournalCoreTaskCatalog.nutritionTaskId(for: dayId),
                dayId: dayId
            )
        }

        if let morning = answers[EveningCheckInQuestionID.morningRoutine] {
            planStore.setJournalTaskStatus(
                morning == "yes" ? .completed : .failed,
                taskId: "\(dayId).core.morning",
                dayId: dayId
            )
        }
    }

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.evening_checkin", userId: uid)
        let state = ProcessEveningCheckInState(
            submittedDayKeys: submittedDayKeys,
            recordsByDay: recordsByDay
        )
        persistenceGeneration &+= 1
        let generation = persistenceGeneration
        Task.detached(priority: .utility) {
            await ProcessPersistenceWriter.shared.store(
                state,
                forKey: key,
                generation: generation
            )
        }
    }

    private func loadState() -> ProcessEveningCheckInState? {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.evening_checkin", userId: uid)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProcessEveningCheckInState.self, from: data)
    }
}

enum ProcessEveningCheckInSchedule {
    /// Heure du bilan du soir (pastille + notif). Avant ça, on peut cocher mais on ne nag pas.
    static let reminderHour = 21

    static func isOverdue(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }

    static func isBilanWindowOpen(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.component(.hour, from: now) >= reminderHour
    }

    /// Pastille rouge : seulement à partir de 21h, tant que le bilan du jour n’est pas validé.
    @MainActor
    static func showsAttentionBadge(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !PlanHomeTutorialStore.shared.shouldDeferEveningCheckIn else { return false }
        guard !ProcessEveningCheckInStore.shared.hasSubmittedToday else { return false }
        return isBilanWindowOpen(now: now, calendar: calendar)
    }

    @MainActor
    static func streakLaunchMessage(from now: Date = Date(), calendar: Calendar = .current) -> String {
        let isFirstCheck = ProcessEveningCheckInStore.shared.submittedDayKeys.isEmpty
        if ProcessEveningCheckInStore.shared.hasSubmittedToday {
            return AppCopy.t("Check du jour validé — reviens demain.", en: "Today’s check-in is done — come back tomorrow.")
        }
        if !isBilanWindowOpen(now: now, calendar: calendar) {
            return AppCopy.t("Le bilan du soir s'ouvre à 21h.", en: "The evening check-in opens at 9 PM.")
        }
        return isFirstCheck
            ? AppCopy.t("Valide ton check pour lancer la série", en: "Complete your check-in to start your streak")
            : AppCopy.t("Valide ton check pour continuer la série", en: "Complete your check-in to keep your streak")
    }

    /// Jour déjà validé côté série (bilan soumis ou grâce J1 après téléchargement).
    @MainActor
    static func isTodayStreakSettledForNavigation(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let store = ProcessEveningCheckInStore.shared
        if store.hasSubmitted(on: now) { return true }

        let streak = ProcessStreakStore.shared
        if streak.snapshot.isTodayComplete { return true }

        // Téléchargement + premier scan : série affichée à 1 sans bilan soumis.
        if store.submittedDayKeys.isEmpty, streak.displayStreak > 0 {
            return true
        }

        return false
    }

    /// Avant 21h : ouvre d’abord le rattrapage d’hier si la série serait cassée.
    @MainActor
    static func preferredManualCheckInDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let store = ProcessEveningCheckInStore.shared
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
            return now
        }
        if !store.hasSubmitted(on: yesterday),
           !isBilanWindowOpen(now: now, calendar: calendar),
           !store.submittedDayKeys.isEmpty {
            return yesterday
        }
        return now
    }
}
