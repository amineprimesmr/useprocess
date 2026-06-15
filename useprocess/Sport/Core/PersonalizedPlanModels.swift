//
//  PersonalizedPlanModels.swift
//  Process
//
//  Modèles pour le plan personnalisé ultra-complet
//  Généré après 7 jours app (ou Jour 1 avec pré-download)
//
//  Cibles quotidiennes et suite : PersonalizedPlanModelsDaily.swift
//

import SwiftUI

// MARK: - Personalized Plan Config

/// Configuration complète du plan personnalisé
struct PersonalizedPlanConfig: Codable, Identifiable {
    let id: String
    let userId: String
    let createdAt: Date
    var lastUpdated: Date
    let basedOnDays: Int              // Nombre de jours d'apprentissage
    var confidence: Double            // Confiance globale du plan

    // SPORT & OBJECTIFS
    var primarySport: SportDetail
    var secondarySports: [SportDetail]
    var userGoals: UserGoals                  // Objectifs multi-dimensionnels
    var specificGoals: [SpecificGoal]         // Objectifs chiffrés précis

    // NIVEAU & HISTORIQUE
    var currentLevel: ExperienceLevel
    var yearsOfExperience: Int
    var personalRecords: [PersonalRecord]

    // CONTRAINTES
    var constraints: TrainingConstraints
    var injuries: [InjuryHistory]
    var availableEquipment: [PlanEquipment]

    // PRÉFÉRENCES
    var preferences: UserTrainingPreferences

    // BASELINES FINALES
    var baselines: FinalBaselines

    // PATTERNS CONFIRMÉS
    var confirmedPatterns: [UserPattern]

    // MOTIVATION & PSYCHOLOGIE
    var motivationProfile: MotivationProfile

    // POTENTIEL SPORTIF
    var sportPotential: SportPotentialLevel?

    init(userId: String, basedOnDays: Int) {
        self.id = UUID().uuidString
        self.userId = userId
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.basedOnDays = basedOnDays
        self.confidence = 0.0
        self.primarySport = SportDetail(sportName: "Course à pied", sportCategory: "Cardio")
        self.secondarySports = []
        self.userGoals = UserGoals()  // Objectifs adaptatifs par défaut
        self.specificGoals = []
        self.currentLevel = .intermediaire
        self.yearsOfExperience = 0
        self.personalRecords = []
        self.constraints = TrainingConstraints()
        self.injuries = []
        self.availableEquipment = []
        self.preferences = UserTrainingPreferences()
        self.baselines = FinalBaselines()
        self.confirmedPatterns = []
        self.motivationProfile = MotivationProfile()
    }
}

// MARK: - Sport Detail

struct SportDetail: Codable, Identifiable {
    let id: String
    var sportName: String             // Nom du sport (ex: "Course à pied")
    var sportCategory: String         // Catégorie (ex: "Cardio")
    var specificDiscipline: String?   // Ex: "10K", "Semi-Marathon"
    var level: ExperienceLevel
    var hoursPerWeek: Int
    var goals: [String]               // Objectifs spécifiques

    init(sportName: String, sportCategory: String = "Cardio") {
        self.id = UUID().uuidString
        self.sportName = sportName
        self.sportCategory = sportCategory
        self.level = .intermediaire
        self.hoursPerWeek = 0
        self.goals = []
    }
}

// MARK: - Main Goal (Legacy pour onboarding - N'EST PLUS UTILISÉ DANS LE PLAN)

/// ⚠️ LEGACY: Gardé pour compatibilité onboarding mais le plan utilise UserGoals
enum MainGoal: String, Codable, CaseIterable {
    case performanceSportive = "Performance Sportive"
    case preparationCompetition = "Préparation Compétition"
    case pertePoids = "Perte de Poids"
    case priseMasse = "Prise de Masse"
    case endurance = "Améliorer Endurance"
    case force = "Améliorer Force"
    case sante = "Santé Générale"
    case energie = "Augmenter Énergie"
    case gestionStress = "Gestion du Stress"
    case sommeil = "Améliorer Sommeil"

    var icon: String {
        switch self {
        case .performanceSportive: return "figure.run"
        case .preparationCompetition: return "trophy.fill"
        case .pertePoids: return "scalemass.fill"
        case .priseMasse: return "dumbbell.fill"
        case .endurance: return "flame.fill"
        case .force: return "bolt.fill"
        case .sante: return "heart.fill"
        case .energie: return "bolt.heart.fill"
        case .gestionStress: return "brain.head.profile"
        case .sommeil: return "moon.fill"
        }
    }
}

// MARK: - User Goals (Multi-objectifs adaptatifs - UTILISÉ PAR LE PLAN)

/// Objectifs de l'utilisateur - TOUS peuvent être actifs simultanément
struct UserGoals: Codable {
    var performanceSportive: GoalPriority = .medium
    var recuperation: GoalPriority = .high           // Toujours important
    var sommeil: GoalPriority = .high                // Toujours important
    var gestionStress: GoalPriority = .medium
    var pertePoids: GoalPriority = .none
    var priseMasse: GoalPriority = .none
    var endurance: GoalPriority = .medium
    var force: GoalPriority = .medium

    /// Retourne les objectifs actifs (non-none) triés par priorité
    var activeGoals: [(goal: String, priority: GoalPriority)] {
        var goals: [(String, GoalPriority)] = []
        if performanceSportive != .none { goals.append(("Performance Sportive", performanceSportive)) }
        if recuperation != .none { goals.append(("Récupération", recuperation)) }
        if sommeil != .none { goals.append(("Sommeil", sommeil)) }
        if gestionStress != .none { goals.append(("Gestion du Stress", gestionStress)) }
        if pertePoids != .none { goals.append(("Perte de Poids", pertePoids)) }
        if priseMasse != .none { goals.append(("Prise de Masse", priseMasse)) }
        if endurance != .none { goals.append(("Endurance", endurance)) }
        if force != .none { goals.append(("Force", force)) }
        return goals.sorted { $0.1.numericValue > $1.1.numericValue }
    }

    /// Créer UserGoals depuis un MainGoal legacy (onboarding)
    static func fromLegacyGoal(_ mainGoal: MainGoal?) -> UserGoals {
        var goals = UserGoals()

        // Toujours prioritaires
        goals.recuperation = .high
        goals.sommeil = .high

        // Adapter selon le mainGoal legacy
        if let legacy = mainGoal {
            switch legacy {
            case .endurance:
                goals.endurance = .critical
            case .force:
                goals.force = .critical
            case .pertePoids:
                goals.pertePoids = .critical
                goals.endurance = .medium
            case .priseMasse:
                goals.priseMasse = .critical
                goals.force = .high
            case .performanceSportive, .preparationCompetition:
                goals.performanceSportive = .critical
                goals.endurance = .high
            case .sommeil:
                goals.sommeil = .critical
            case .gestionStress:
                goals.gestionStress = .critical
            case .energie:
                goals.performanceSportive = .high
            case .sante:
                goals.performanceSportive = .medium
                goals.gestionStress = .medium
            }
        }

        return goals
    }
}

// MARK: - Specific Goal

struct SpecificGoal: Codable, Identifiable {
    let id: String
    let type: GoalType
    var target: Double
    var current: Double
    let unit: String
    var deadline: Date?
    let priority: GoalPriority
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, current / target)
    }
    let createdAt: Date

    init(type: GoalType, target: Double, current: Double, unit: String, deadline: Date? = nil, priority: GoalPriority = .medium) {
        self.id = UUID().uuidString
        self.type = type
        self.target = target
        self.current = current
        self.unit = unit
        self.deadline = deadline
        self.priority = priority
        self.createdAt = Date()
    }
}

enum GoalType: String, Codable {
    case weight = "Poids"
    case hrv = "HRV"
    case rhr = "FC Repos"
    case vo2max = "VO2 Max"
    case race = "Course"
    case distance = "Distance"
    case time = "Temps"
    case strength = "Force"
    case flexibility = "Flexibilité"
    case sleep = "Sommeil"
    case stress = "Stress"
}

enum GoalPriority: String, Codable, Comparable {
    case none = "Inactif"
    case low = "Faible"
    case medium = "Moyenne"
    case high = "Élevée"
    case critical = "Critique"

    var numericValue: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    static func < (lhs: GoalPriority, rhs: GoalPriority) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}

// MARK: - Experience Level

enum ExperienceLevel: String, Codable, CaseIterable {
    case debutant = "Débutant"              // < 1 an
    case intermediaire = "Intermédiaire"    // 1-3 ans
    case amateur = "Amateur"                // 3-5 ans
    case professionnel = "Professionnel"    // Pro/Semi-pro

    var icon: String {
        switch self {
        case .debutant: return "1.circle.fill"
        case .intermediaire: return "2.circle.fill"
        case .amateur: return "3.circle.fill"
        case .professionnel: return "star.circle.fill"
        }
    }
}

// MARK: - Personal Record

struct PersonalRecord: Codable, Identifiable {
    let id: String
    let type: String                  // "10K", "Semi", "Marathon", etc.
    var value: Double
    let unit: String
    let achievedAt: Date

    init(type: String, value: Double, unit: String, achievedAt: Date = Date()) {
        self.id = UUID().uuidString
        self.type = type
        self.value = value
        self.unit = unit
        self.achievedAt = achievedAt
    }
}

// MARK: - Training Constraints

struct TrainingConstraints: Codable {
    var maxSessionsPerWeek: Int = 5
    var maxSessionDuration: Int = 90     // Minutes
    var availableDays: [WeekDay] = []
    var timeBlocks: [TimeBlock] = []
    var location: TrainingLocation = .mixed

    var hasFlexibility: Bool {
        availableDays.count >= 5 && timeBlocks.count >= 2
    }
}

enum WeekDay: String, Codable, CaseIterable {
    case monday = "Lundi"
    case tuesday = "Mardi"
    case wednesday = "Mercredi"
    case thursday = "Jeudi"
    case friday = "Vendredi"
    case saturday = "Samedi"
    case sunday = "Dimanche"
}

struct TimeBlock: Codable, Identifiable {
    let id: String
    let day: WeekDay
    let startTime: String             // "14:00"
    let endTime: String               // "18:00"

    init(day: WeekDay, startTime: String, endTime: String) {
        self.id = UUID().uuidString
        self.day = day
        self.startTime = startTime
        self.endTime = endTime
    }
}

enum TrainingLocation: String, Codable {
    case home = "À la maison"
    case gym = "Salle de sport"
    case outdoor = "Extérieur"
    case mixed = "Mixte"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .gym: return "figure.strengthtraining.traditional"
        case .outdoor: return "leaf.fill"
        case .mixed: return "arrow.left.arrow.right"
        }
    }
}

/// Équipement disponible pour le plan personnalisé
enum PlanEquipment: String, Codable, CaseIterable {
    case none = "Aucun"
    case dumbbells = "Haltères"
    case kettlebell = "Kettlebell"
    case resistanceBands = "Bandes de résistance"
    case pullupBar = "Barre de traction"
    case treadmill = "Tapis de course"
    case bike = "Vélo"
    case rower = "Rameur"
    case fullGym = "Salle complète"
}

// MARK: - Injury History

struct InjuryHistory: Codable, Identifiable {
    let id: String
    let type: String
    let bodyPart: String
    let severity: InjurySeverity
    let occurredAt: Date
    var healedAt: Date?
    var restrictions: [String]

    init(type: String, bodyPart: String, severity: InjurySeverity) {
        self.id = UUID().uuidString
        self.type = type
        self.bodyPart = bodyPart
        self.severity = severity
        self.occurredAt = Date()
        self.restrictions = []
    }
}

enum InjurySeverity: String, Codable {
    case minor = "Mineure"
    case moderate = "Modérée"
    case major = "Majeure"
}

// MARK: - User Training Preferences

struct UserTrainingPreferences: Codable {
    var preferredTrainingTime: TimeOfDay = .afternoon
    var weeklyTimeCommitment: Int = 300       // Minutes/semaine
    var restDaysPerWeek: Int = 2
    var preferredCoachingStyle: CoachingStyle = .balanced
    var gamificationEnabled: Bool = true
}

enum TimeOfDay: String, Codable {
    case earlyMorning = "Tôt le matin (5h-7h)"
    case morning = "Matin (7h-10h)"
    case midday = "Midi (11h-14h)"
    case afternoon = "Après-midi (14h-18h)"
    case evening = "Soir (18h-22h)"
}

enum CoachingStyle: String, Codable {
    case gentle = "Doux"
    case balanced = "Équilibré"
    case aggressive = "Agressif"
    case adaptive = "Adaptatif"
}

// MARK: - Final Baselines

struct FinalBaselines: Codable {
    var hrv: Double = 0.0
    var hrvStd: Double = 0.0
    var rhr: Double = 0.0
    var rhrStd: Double = 0.0
    var sleepNeed: Double = 8.0
    var sleepNeedStd: Double = 0.0
    var effortCapacity: Double = 15.0
    var recoverySpeed: Int = 2            // Jours
    var stressTolerance: Double = 50.0    // 0-100

    var allEstablished: Bool {
        hrv > 0 && rhr > 0 && sleepNeed > 0 && effortCapacity > 0
    }
}

// MARK: - Motivation Profile

struct MotivationProfile: Codable {
    var motivationLevel: MotivationLevel = .medium
    var intrinsicMotivation: Double = 0.5     // 0-1
    var extrinsicMotivation: Double = 0.5     // 0-1
    var competitiveness: Double = 0.5         // 0-1
    var consistency: Double = 0.5             // 0-1
    var resilience: Double = 0.5              // 0-1
}

enum MotivationLevel: String, Codable {
    case low = "Faible"
    case medium = "Moyenne"
    case high = "Élevée"
    case veryHigh = "Très élevée"
}
