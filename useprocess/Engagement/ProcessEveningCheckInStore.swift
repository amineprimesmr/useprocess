import Foundation

enum EveningCheckInQuestionID {
    static let water = "water"
    static let debloatMeal = "debloatMeal"
    /// Legacy — plus affiché dans la checklist, conservé pour l’historique trajectoire.
    static let cardio = "cardio"
    static let morningRoutine = "morningRoutine"
    static let legacyPostureCircuit = "postureCircuit"

    /// Leviers debloat — score, streak et validation jour.
    static let debloatLevers: [String] = [water, debloatMeal]
    /// Toutes les questions affichées dans la checklist.
    static let all: [String] = [morningRoutine] + debloatLevers
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
        ProcessStreakStore.shared.sync(from: WelcomePlanStore.shared.plan)
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
    static let openHour = 21

    static func isAvailable(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.component(.hour, from: date) >= openHour
    }

    /// Un jour sans bilan n'est « manqué » qu'une fois passé (hier ou avant).
    /// Aujourd'hui reste en attente tant que le bilan du soir n'a pas été soumis.
    static func isOverdue(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }

    static func nextOpenDate(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = openHour
        components.minute = 0
        components.second = 0
        let todayOpen = calendar.date(from: components) ?? now
        if now < todayOpen {
            return todayOpen
        }
        return calendar.date(byAdding: .day, value: 1, to: todayOpen) ?? todayOpen
    }

    static func opensInLabel(from now: Date = Date(), calendar: Calendar = .current) -> String {
        guard !isAvailable(at: now, calendar: calendar) else { return "" }
        let interval = max(0, nextOpenDate(from: now, calendar: calendar).timeIntervalSince(now))
        let totalMinutes = Int((interval / 60).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0, minutes > 0 {
            return AppCopy.tSync("dans \(hours) h \(minutes) min", en: "in \(hours) h \(minutes) min")
        }
        if hours > 0 {
            return AppCopy.tSync("dans \(hours) h", en: "in \(hours) h")
        }
        return AppCopy.tSync("dans \(max(1, minutes)) min", en: "in \(max(1, minutes)) min")
    }

    @MainActor
    static func streakLaunchMessage(from now: Date = Date(), calendar: Calendar = .current) -> String {
        let isFirstCheck = ProcessEveningCheckInStore.shared.submittedDayKeys.isEmpty
            || ProcessStreakStore.shared.snapshot.totalCompletedDays == 0

        if isAvailable(at: now, calendar: calendar) {
            return isFirstCheck
                ? AppCopy.t("Valide ton premier check pour lancer la série", en: "Complete your first check-in to start your streak")
                : AppCopy.t("Valide ton check pour lancer la série", en: "Complete your check-in to start your streak")
        }

        let countdown = opensInLabel(from: now, calendar: calendar)
        if isFirstCheck {
            return countdown.isEmpty
                ? AppCopy.t("Premier check ce soir", en: "First check-in tonight")
                : AppCopy.t("Premier check \(countdown)", en: "First check-in \(countdown)")
        }
        return countdown.isEmpty
            ? AppCopy.t("Prochain check ce soir", en: "Next check-in tonight")
            : AppCopy.t("Prochain check \(countdown)", en: "Next check-in \(countdown)")
    }
}
