import Foundation

// MARK: - Calendrier 13 semaines (jour par jour)

struct OriginProgramCalendar: Codable, Equatable {
    var startedAt: Date?
    var weeks: [OriginProgramWeek]

    static var empty: OriginProgramCalendar { OriginProgramCalendar(startedAt: nil, weeks: []) }

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

struct OriginPlanProgress: Codable, Equatable {
    var completedTaskIds: Set<String> = []
    var completedDayIds: Set<String> = []
    var userNotes: [String: String] = [:]
    var modifications: [OriginPlanModification] = []
    var lastCoachSyncAt: Date?
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
                "10–20 min lumière naturelle dans l'heure après le réveil",
                "Marche outdoor 2–3×/sem minimum"
            ],
            stressRegulation: [
                "Respiration nasale consciente 3×/jour",
                "Couvre-feu écran 60 min avant coucher si sommeil fragile"
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
            weeklyReviews: [
                "Dimanche 5 min : sommeil, digestion, énergie, visage",
                "Ajuster 1 habitude max — pas tout d'un coup"
            ],
            bonusProposals: [
                "Bouillon d'os 3–4×/sem pour minéraux naturels",
                "Mastication lente = digestion + stimulation maxillaire",
                "Mewing (langue au palais) en permanence — gratuit, effet cumulatif",
                "Marche post-repas 10 min — glycémie + lymphe",
                "Chambre fraîche (~18 °C) + obscurité totale"
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
