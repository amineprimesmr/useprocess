import Foundation

// MARK: - Questionnaire

enum WelcomePlanPhase: String, Codable, CaseIterable {
    case welcome
    case profile
    case hormonesSleep
    case nutrition
    case postureFace
    case training
    case psychology
    case closing
}

enum WelcomeQuestionKind: String, Codable {
    case singleChoice
    case multiChoice
    case yesNo
    case time
    case text
    case info
}

struct WelcomePlanChoice: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let label: String
    let detail: String?

    init(id: String, label: String, detail: String? = nil) {
        self.id = id
        self.label = label
        self.detail = detail
    }
}

struct WelcomePlanQuestion: Identifiable, Codable, Equatable {
    let id: String
    let phase: WelcomePlanPhase
    let kind: WelcomeQuestionKind
    let prompt: String
    let coachIntro: String?
    let choices: [WelcomePlanChoice]
    let allowsSkip: Bool
    let skipWhen: WelcomePlanSkipRule?

    init(
        id: String,
        phase: WelcomePlanPhase,
        kind: WelcomeQuestionKind,
        prompt: String,
        coachIntro: String? = nil,
        choices: [WelcomePlanChoice] = [],
        allowsSkip: Bool = false,
        skipWhen: WelcomePlanSkipRule? = nil
    ) {
        self.id = id
        self.phase = phase
        self.kind = kind
        self.prompt = prompt
        self.coachIntro = coachIntro
        self.choices = choices
        self.allowsSkip = allowsSkip
        self.skipWhen = skipWhen
    }
}

struct WelcomePlanSkipRule: Codable, Equatable {
    let questionId: String
    let choiceIds: [String]
    let matchAny: Bool
}

struct WelcomePlanAnswer: Codable, Equatable {
    var choiceIds: [String] = []
    var textValue: String?
    var timeValue: String?
    var skipped: Bool = false

    var displayText: String {
        if skipped { return "Passer" }
        if let timeValue, !timeValue.isEmpty { return timeValue }
        if let textValue, !textValue.isEmpty { return textValue }
        return choiceIds.joined(separator: ", ")
    }
}

struct WelcomePlanQuestionnaireState: Codable, Equatable {
    var answers: [String: WelcomePlanAnswer] = [:]
    var completedAt: Date?
    var startedAt: Date = Date()
}

// MARK: - Plan généré (Protocole Origine — 100 % naturel)

struct FaceOriginPlan: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let createdAt: Date
    var lastUpdated: Date

    var headline: String
    var executiveSummary: String
    var philosophyNote: String

    var primaryFaceGoal: String
    var pillarScores: [OriginPillarScore]
    var dailyHabits: [OriginDailyHabit]
    var weeklyRhythm: [OriginWeeklyBlock]
    var phaseRoadmap: [OriginPlanPhaseBlock]
    var nutritionProtocol: OriginNutritionProtocol
    var sleepProtocol: OriginSleepProtocol
    var trainingProtocol: OriginTrainingProtocol
    var postureProtocol: OriginPostureProtocol
    var faceProtocol: OriginFaceProtocol
    var mindsetNotes: [String]

    /// Durée calendrier (semaines générées).
    var totalWeeks: Int
    /// Fourchette affichée (cohérence profil).
    var durationMinWeeks: Int
    var durationMaxWeeks: Int

    var calendar: OriginProgramCalendar
    var progress: OriginPlanProgress
    var lifestyleExtras: OriginLifestyleExtras

    static let noSupplementsPhilosophy = """
    Zéro pilule, zéro complément isolé. Tout passe par l'alimentation dense, le sommeil, \
    la lumière, le mouvement et la posture. Les électrolytes viennent des aliments — pas des sachets.
    """

    init(
        id: String,
        userId: String,
        createdAt: Date,
        lastUpdated: Date,
        headline: String,
        executiveSummary: String,
        philosophyNote: String,
        primaryFaceGoal: String,
        pillarScores: [OriginPillarScore],
        dailyHabits: [OriginDailyHabit],
        weeklyRhythm: [OriginWeeklyBlock],
        phaseRoadmap: [OriginPlanPhaseBlock],
        nutritionProtocol: OriginNutritionProtocol,
        sleepProtocol: OriginSleepProtocol,
        trainingProtocol: OriginTrainingProtocol,
        postureProtocol: OriginPostureProtocol,
        faceProtocol: OriginFaceProtocol,
        mindsetNotes: [String],
        totalWeeks: Int = 13,
        durationMinWeeks: Int = 12,
        durationMaxWeeks: Int = 14,
        calendar: OriginProgramCalendar = .empty,
        progress: OriginPlanProgress = OriginPlanProgress(),
        lifestyleExtras: OriginLifestyleExtras = .default
    ) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.headline = headline
        self.executiveSummary = executiveSummary
        self.philosophyNote = philosophyNote
        self.primaryFaceGoal = primaryFaceGoal
        self.pillarScores = pillarScores
        self.dailyHabits = dailyHabits
        self.weeklyRhythm = weeklyRhythm
        self.phaseRoadmap = phaseRoadmap
        self.nutritionProtocol = nutritionProtocol
        self.sleepProtocol = sleepProtocol
        self.trainingProtocol = trainingProtocol
        self.postureProtocol = postureProtocol
        self.faceProtocol = faceProtocol
        self.mindsetNotes = mindsetNotes
        self.totalWeeks = totalWeeks
        self.durationMinWeeks = durationMinWeeks
        self.durationMaxWeeks = durationMaxWeeks
        self.calendar = calendar
        self.progress = progress
        self.lifestyleExtras = lifestyleExtras
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decode(String.self, forKey: .userId)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        lastUpdated = try c.decode(Date.self, forKey: .lastUpdated)
        headline = try c.decode(String.self, forKey: .headline)
        executiveSummary = try c.decode(String.self, forKey: .executiveSummary)
        philosophyNote = try c.decode(String.self, forKey: .philosophyNote)
        primaryFaceGoal = try c.decode(String.self, forKey: .primaryFaceGoal)
        pillarScores = try c.decode([OriginPillarScore].self, forKey: .pillarScores)
        dailyHabits = try c.decode([OriginDailyHabit].self, forKey: .dailyHabits)
        weeklyRhythm = try c.decode([OriginWeeklyBlock].self, forKey: .weeklyRhythm)
        phaseRoadmap = try c.decode([OriginPlanPhaseBlock].self, forKey: .phaseRoadmap)
        nutritionProtocol = try c.decode(OriginNutritionProtocol.self, forKey: .nutritionProtocol)
        sleepProtocol = try c.decode(OriginSleepProtocol.self, forKey: .sleepProtocol)
        trainingProtocol = try c.decode(OriginTrainingProtocol.self, forKey: .trainingProtocol)
        postureProtocol = try c.decode(OriginPostureProtocol.self, forKey: .postureProtocol)
        faceProtocol = try c.decode(OriginFaceProtocol.self, forKey: .faceProtocol)
        mindsetNotes = try c.decode([String].self, forKey: .mindsetNotes)
        totalWeeks = try c.decodeIfPresent(Int.self, forKey: .totalWeeks) ?? 13
        durationMinWeeks = try c.decodeIfPresent(Int.self, forKey: .durationMinWeeks) ?? 12
        durationMaxWeeks = try c.decodeIfPresent(Int.self, forKey: .durationMaxWeeks) ?? 14
        calendar = try c.decodeIfPresent(OriginProgramCalendar.self, forKey: .calendar) ?? .empty
        progress = try c.decodeIfPresent(OriginPlanProgress.self, forKey: .progress) ?? OriginPlanProgress()
        lifestyleExtras = try c.decodeIfPresent(OriginLifestyleExtras.self, forKey: .lifestyleExtras) ?? .default
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(userId, forKey: .userId)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(lastUpdated, forKey: .lastUpdated)
        try c.encode(headline, forKey: .headline)
        try c.encode(executiveSummary, forKey: .executiveSummary)
        try c.encode(philosophyNote, forKey: .philosophyNote)
        try c.encode(primaryFaceGoal, forKey: .primaryFaceGoal)
        try c.encode(pillarScores, forKey: .pillarScores)
        try c.encode(dailyHabits, forKey: .dailyHabits)
        try c.encode(weeklyRhythm, forKey: .weeklyRhythm)
        try c.encode(phaseRoadmap, forKey: .phaseRoadmap)
        try c.encode(nutritionProtocol, forKey: .nutritionProtocol)
        try c.encode(sleepProtocol, forKey: .sleepProtocol)
        try c.encode(trainingProtocol, forKey: .trainingProtocol)
        try c.encode(postureProtocol, forKey: .postureProtocol)
        try c.encode(faceProtocol, forKey: .faceProtocol)
        try c.encode(mindsetNotes, forKey: .mindsetNotes)
        try c.encode(totalWeeks, forKey: .totalWeeks)
        try c.encode(durationMinWeeks, forKey: .durationMinWeeks)
        try c.encode(durationMaxWeeks, forKey: .durationMaxWeeks)
        try c.encode(calendar, forKey: .calendar)
        try c.encode(progress, forKey: .progress)
        try c.encode(lifestyleExtras, forKey: .lifestyleExtras)
    }

    private enum CodingKeys: String, CodingKey {
        case id, userId, createdAt, lastUpdated, headline, executiveSummary, philosophyNote
        case primaryFaceGoal, pillarScores, dailyHabits, weeklyRhythm, phaseRoadmap
        case nutritionProtocol, sleepProtocol, trainingProtocol, postureProtocol, faceProtocol, mindsetNotes
        case totalWeeks, durationMinWeeks, durationMaxWeeks
        case calendar, progress, lifestyleExtras
    }
}

struct OriginPillarScore: Codable, Identifiable, Equatable {
    let pillar: String
    let score: Int
    let focus: String

    var id: String { pillar }
}

struct OriginDailyHabit: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let pillar: String
    let timing: String?
}

struct OriginWeeklyBlock: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

struct OriginPlanPhaseBlock: Codable, Identifiable, Equatable {
    let id: String
    let weeksRange: String
    let title: String
    let objectives: [String]
    let habits: [String]
}

struct OriginNutritionProtocol: Codable, Equatable {
    var principles: [String]
    var dailyStructure: [String]
    var foodsToPrioritize: [String]
    var foodsToReduce: [String]
    var hydrationGuide: String
    var mealExamples: [String]
    var mealPlanStyle: OriginMealPlanStyle?
}

struct OriginSleepProtocol: Codable, Equatable {
    var targetHours: Double
    var bedtimeWindow: String
    var wakeWindow: String
    var eveningRoutine: [String]
    var morningRoutine: [String]
}

struct OriginTrainingProtocol: Codable, Equatable {
    var sessionsPerWeek: Int
    var sessionDurationMinutes: Int
    var splitOverview: String
    var weeklyTemplate: [String]
    var recoveryRules: [String]
}

struct OriginPostureProtocol: Codable, Equatable {
    var dailyChecks: [String]
    var mobilityBlocks: [String]
    var breathingWork: [String]
    var walkingTargets: String
}

struct OriginFaceProtocol: Codable, Equatable {
    var focusAreas: [String]
    var jawAndTongueWork: [String]
    var lymphAndFascia: [String]
    var scanCadence: String
}
