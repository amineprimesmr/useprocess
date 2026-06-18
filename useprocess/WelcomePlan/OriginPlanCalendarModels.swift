import Foundation

// MARK: - Calendrier 13 semaines (jour par jour)

struct OriginProgramCalendar: Codable, Equatable {
    var startedAt: Date?
    var weeks: [OriginProgramWeek]
    /// Incrémenté quand le schéma du calendrier change (ex. IDs stables des tâches).
    var buildVersion: Int = 5

    static var empty: OriginProgramCalendar { OriginProgramCalendar(startedAt: nil, weeks: [], buildVersion: 5) }

    enum CodingKeys: String, CodingKey {
        case startedAt, weeks, buildVersion
    }

    init(startedAt: Date?, weeks: [OriginProgramWeek], buildVersion: Int = 5) {
        self.startedAt = startedAt
        self.weeks = weeks
        self.buildVersion = buildVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        weeks = try c.decodeIfPresent([OriginProgramWeek].self, forKey: .weeks) ?? []
        buildVersion = try c.decodeIfPresent(Int.self, forKey: .buildVersion) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(startedAt, forKey: .startedAt)
        try c.encode(weeks, forKey: .weeks)
        try c.encode(buildVersion, forKey: .buildVersion)
    }

    var totalDays: Int { weeks.reduce(0) { $0 + $1.days.count } }

    func day(globalIndex: Int) -> OriginProgramDay? {
        var idx = globalIndex
        for week in weeks {
            if idx < week.days.count { return week.days[idx] }
            idx -= week.days.count
        }
        return nil
    }

    func currentProgramDayIndex(from date: Date = Date()) -> Int {
        guard let start = startedAt else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: date)).day ?? 0
        return min(max(days, 0), max(totalDays - 1, 0))
    }

    func currentWeekNumber(from date: Date = Date()) -> Int {
        let idx = currentProgramDayIndex(from: date)
        var remaining = idx
        for week in weeks {
            if remaining < week.days.count { return week.weekNumber }
            remaining -= week.days.count
        }
        return weeks.last?.weekNumber ?? 1
    }
}

struct OriginProgramWeek: Codable, Identifiable, Equatable {
    let id: String
    let weekNumber: Int
    var theme: String
    var phaseTitle: String
    var focus: String
    var days: [OriginProgramDay]
}

struct OriginProgramDay: Codable, Identifiable, Equatable {
    let id: String
    let globalDayIndex: Int
    let weekNumber: Int
    let weekdayIndex: Int
    var weekdayLabel: String
    var title: String
    var morning: [OriginPlanTask]
    var nutrition: OriginDayNutrition
    var training: OriginDayTraining?
    var posture: [OriginPlanTask]
    var face: [OriginPlanTask]
    var evening: [OriginPlanTask]
    var sleep: OriginDaySleep
    var mindset: String?
}

struct OriginPlanTask: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var detail: String
    var pillar: String
    var durationMinutes: Int?
    var isOptional: Bool
}

enum OriginMealPlanStyle: String, Codable, Equatable {
    case standard
    case omad
    case twoMeals
}

struct OriginDayNutrition: Codable, Equatable {
    var breakfast: String
    var lunch: String
    var dinner: String
    var snack: String?
    var hydration: String
    var principles: [String]
    var foodsToday: [String]
    var mealPlanStyle: OriginMealPlanStyle?
    var omadMeal: String?

    var isOMAD: Bool {
        mealPlanStyle == .omad || (omadMeal?.isEmpty == false && breakfast.isEmpty && dinner.isEmpty)
    }
}

struct OriginDayTraining: Codable, Equatable {
    var sessionName: String
    var durationMinutes: Int
    var warmup: [String]
    var exercises: [OriginExercise]
    var cooldown: [String]
    var notes: String?
}

struct OriginExercise: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var sets: Int
    var reps: String
    var restSeconds: Int
    var coachingCue: String
    var muscleGroup: String
}

struct OriginDaySleep: Codable, Equatable {
    var targetBedtime: String
    var targetWake: String
    var targetHours: Double
    var eveningActions: [String]
    var morningActions: [String]
}

enum JournalTaskStatus: String, Codable, Equatable {
    case failed
    case completed
}

struct OriginPlanProgress: Codable, Equatable {
    var completedTaskIds: Set<String> = []
    var taskStatuses: [String: JournalTaskStatus] = [:]
    var completedDayIds: Set<String> = []
    var userNotes: [String: String] = [:]
    var modifications: [OriginPlanModification] = []
    var lastCoachSyncAt: Date?
    /// Repas validé par jour (`dayId` → description).
    var validatedMeals: [String: String] = [:]

    static func taskKey(dayId: String, taskId: String) -> String {
        "\(dayId)|\(taskId)"
    }

    func status(for taskId: String, dayId: String) -> JournalTaskStatus? {
        let key = Self.taskKey(dayId: dayId, taskId: taskId)
        if let status = taskStatuses[key] { return status }
        if completedTaskIds.contains(taskId) { return .completed }
        return nil
    }
}

struct OriginPlanModification: Codable, Identifiable, Equatable {
    let id: String
    let createdAt: Date
    var sectionPath: String
    var previousSummary: String
    var userRequest: String
    var coachResponse: String
    var applied: Bool
}

struct OriginLifestyleExtras: Codable, Equatable {
    var sunlightProtocol: [String]
    var stressRegulation: [String]
    var recoveryProtocol: [String]
    var trackingChecklist: [String]
    var weeklyReviews: [String]
    var bonusProposals: [String]

    static var `default`: OriginLifestyleExtras {
        OriginLifestyleExtras(
            sunlightProtocol: [
                "\(ProcessDailyTargets.morningLightMinutes) min lumière naturelle dans l'heure après le réveil",
                "Marche outdoor \(ProcessDailyTargets.outdoorWalkSessionsPerWeek)×/sem"
            ],
            stressRegulation: [
                "Pas de téléphone au lit — validé le lendemain matin dans le journal"
            ],
            recoveryProtocol: [
                "Deload semaine 4 et 8",
                "Sommeil > séance supplémentaire si readiness basse"
            ],
            trackingChecklist: [
                "Scan visage : semaines 1, 4, 8, 13",
                "Photos profil : même lumière, même angle",
                "Readiness + pas via Santé chaque matin"
            ],
            weeklyReviews: [],
            bonusProposals: [
                ProcessContinuousHabits.masticationDetail,
                ProcessContinuousHabits.mewingDetail,
                ProcessContinuousHabits.deglutitionDetail,
                "Chambre fraîche (\(ProcessDailyTargets.bedroomTempCelsius) °C) + obscurité totale"
            ]
        )
    }
}

enum PlanCoachMode: String, Codable {
    case ask
    case evaluate
    case modify
}

struct CoachPlanFocus: Equatable {
    var sectionPath: String
    var sectionTitle: String
    var sectionContent: String
    var mode: PlanCoachMode
}
