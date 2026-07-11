import Foundation

enum EveningCheckInQuestionID {
    static let water = "water"
    static let debloatMeal = "debloatMeal"
    static let postureCircuit = "postureCircuit"

    static let all: [String] = [water, debloatMeal, postureCircuit]
}

struct ProcessEveningCheckInDayRecord: Codable, Equatable {
    var answers: [String: String] = [:]
}

struct ProcessEveningCheckInState: Codable, Equatable {
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
        submittedDayKeys.insert(key)
        var record = recordsByDay[key] ?? ProcessEveningCheckInDayRecord()
        record.answers = sanitized
        recordsByDay[key] = record
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

        if let posture = answers[EveningCheckInQuestionID.postureCircuit] {
            planStore.setJournalTaskStatus(
                posture == "yes" ? .completed : .failed,
                taskId: "\(dayId).posture.circuit",
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
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadState() -> ProcessEveningCheckInState? {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.evening_checkin", userId: uid)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProcessEveningCheckInState.self, from: data)
    }
}
