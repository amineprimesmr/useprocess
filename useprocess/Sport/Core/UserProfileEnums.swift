//
//  UserProfileEnums.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

/// Niveau de stress de l'utilisateur
enum StressLevel: String, CaseIterable, Codable, Equatable {
    case veryLow = "Très faible"
    case low = "Faible"
    case moderate = "Modéré"
    case high = "Élevé"
    case veryHigh = "Très élevé"

    var adjustment: Double {
        switch self {
        case .veryLow: return -5.0 // -5 min
        case .low: return 0.0
        case .moderate: return 10.0 // +10 min
        case .high: return 20.0 // +20 min
        case .veryHigh: return 30.0 // +30 min
        }
    }
}

/// Chronotype de l'utilisateur
enum Chronotype: String, CaseIterable, Codable, Equatable {
    case veryEarly = "Très matinal"
    case early = "Matinal"
    case intermediate = "Intermédiaire"
    case late = "Tardif"
    case veryLate = "Très tardif"

    var adjustment: Double {
        switch self {
        case .veryEarly: return -10.0 // -10 min
        case .early: return -5.0 // -5 min
        case .intermediate: return 0.0
        case .late: return 5.0 // +5 min
        case .veryLate: return 10.0 // +10 min
        }
    }

    var naturalSleepWindow: String {
        switch self {
        case .veryEarly: return "21h-5h"
        case .early: return "22h-6h"
        case .intermediate: return "23h-7h"
        case .late: return "00h-8h"
        case .veryLate: return "01h-9h"
        }
    }
}

/// Catégorie de strain pour le système Whoop
enum StrainCategory: String, CaseIterable, Codable, Equatable {
    case totalRest = "Repos total"
    case veryLow = "Très faible"
    case low = "Faible"
    case moderateLow = "Modéré bas"
    case moderate = "Modéré"
    case moderateHigh = "Modéré élevé"
    case high = "Élevé"
    case veryHigh = "Très élevé"
    case extreme = "Extrême"
    case maximum = "Maximum"

    var adjustment: Double {
        switch self {
        case .totalRest: return -15.0
        case .veryLow: return -5.0
        case .low: return 0.0
        case .moderateLow: return 10.0
        case .moderate: return 20.0
        case .moderateHigh: return 30.0
        case .high: return 45.0
        case .veryHigh: return 60.0
        case .extreme: return 75.0
        case .maximum: return 90.0
        }
    }

    var physiologicalImpact: String {
        switch self {
        case .totalRest: return "Besoin réduit car peu de dépense énergétique"
        case .veryLow: return "Activité minimale, récupération rapide"
        case .low: return "Niveau d'activité normal de la baseline"
        case .moderateLow: return "Légère fatigue accumulée"
        case .moderate: return "Début de fatigue musculaire"
        case .moderateHigh: return "Fatigue significative, micro-déchirures musculaires"
        case .high: return "Fatigue musculaire importante, inflammation"
        case .veryHigh: return "Micro-lésions musculaires, cortisol élevé, stress oxydatif"
        case .extreme: return "Épuisement des réserves énergétiques, glycogène bas"
        case .maximum: return "Dommages musculaires majeurs, inflammation systémique"
        }
    }
}

/// Niveau d'activité de l'utilisateur
enum ActivityLevel: String, CaseIterable, Codable, Equatable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "veryHigh"

    var displayName: String {
        switch self {
        case .low: return "Faible"
        case .moderate: return "Modéré"
        case .high: return "Élevé"
        case .veryHigh: return "Très élevé"
        }
    }
}

/// Niveau de fitness de l'utilisateur
enum FitnessLevel: String, CaseIterable, Codable, Equatable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"

    var displayName: String {
        switch self {
        case .beginner: return "Débutant"
        case .intermediate: return "Intermédiaire"
        case .advanced: return "Avancé"
        case .expert: return "Expert"
        }
    }
}

/// Type d'objectif de fitness
enum FitnessGoalType: String, CaseIterable, Codable, Equatable {
    case weightLoss = "weightLoss"
    case muscleGain = "muscleGain"
    case endurance = "endurance"
    case strength = "strength"
    case flexibility = "flexibility"
    case generalHealth = "generalHealth"

    var displayName: String {
        switch self {
        case .weightLoss: return "Perte de poids"
        case .muscleGain: return "Prise de muscle"
        case .endurance: return "Endurance"
        case .strength: return "Force"
        case .flexibility: return "Flexibilité"
        case .generalHealth: return "Santé générale"
        }
    }
}

/// Objectif de fitness complet
struct FitnessGoal: Codable, Equatable {
    var id: UUID
    var name: String
    var description: String
    var type: FitnessGoalType
    var targetDate: Date
    var isCompleted: Bool
    var progress: Int = 0 // 0-100

    enum CodingKeys: String, CodingKey {
        case id, name, description, type, targetDate, isCompleted, progress
    }

    init(name: String, description: String, type: FitnessGoalType, targetDate: Date, isCompleted: Bool = false) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.type = type
        self.targetDate = targetDate
        self.isCompleted = isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        type = try container.decode(FitnessGoalType.self, forKey: .type)
        targetDate = try container.decode(Date.self, forKey: .targetDate)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        progress = try container.decodeIfPresent(Int.self, forKey: .progress) ?? 0
    }
}

/// Intensité d'entraînement
enum WorkoutIntensity: String, CaseIterable, Codable, Equatable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "veryHigh"

    var displayName: String {
        switch self {
        case .low: return "Faible"
        case .moderate: return "Modérée"
        case .high: return "Élevée"
        case .veryHigh: return "Très élevée"
        }
    }
}

/// Équipement disponible
enum Equipment: String, CaseIterable, Codable, Equatable {
    case none = "none"
    case dumbbells = "dumbbells"
    case barbell = "barbell"
    case resistanceBands = "resistanceBands"
    case yogaMat = "yogaMat"
    case treadmill = "treadmill"
    case bike = "bike"
    case fullGym = "fullGym"

    var displayName: String {
        switch self {
        case .none: return "Aucun"
        case .dumbbells: return "Haltères"
        case .barbell: return "Barre"
        case .resistanceBands: return "Élastiques"
        case .yogaMat: return "Tapis de yoga"
        case .treadmill: return "Tapis de course"
        case .bike: return "Vélo"
        case .fullGym: return "Salle complète"
        }
    }
}

/// Sexe de l'utilisateur
enum Sex: String, CaseIterable, Codable, Equatable {
    case male = "male"
    case female = "female"
    case other = "other"

    var displayName: String {
        switch self {
        case .male: return "Homme"
        case .female: return "Femme"
        case .other: return "Autre"
        }
    }
}

/// Statut de l'utilisateur avec couleurs associées
enum UserStatus: String, CaseIterable, Codable {
    case active = "active"
    case sick = "sick"
    case paused = "paused"

    var displayName: String {
        switch self {
        case .active: return "Actif"
        case .sick: return "Malade/Blessé"
        case .paused: return "En pause"
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .sick: return .yellow
        case .paused: return .blue
        }
    }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .sick: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle.fill"
        }
    }
}

/// Blessure de l'utilisateur
struct Injury: Codable, Equatable {
    var id: UUID
    let name: String
    let description: String
    let date: Date
    let severity: String
    let isRecovered: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description, date, severity, isRecovered
    }

    init(name: String, description: String, date: Date, severity: String, isRecovered: Bool = false) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.date = date
        self.severity = severity
        self.isRecovered = isRecovered
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        date = try container.decode(Date.self, forKey: .date)
        severity = try container.decode(String.self, forKey: .severity)
        isRecovered = try container.decodeIfPresent(Bool.self, forKey: .isRecovered) ?? false
    }
}

/// Créneau horaire disponible
struct TimeSlot: Codable, Equatable {
    var id: UUID
    let startTime: Date
    let endTime: Date
    let dayOfWeek: DayOfWeek
    let isAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, dayOfWeek, isAvailable
    }

    init(startTime: Date, endTime: Date, dayOfWeek: DayOfWeek, isAvailable: Bool = true) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.dayOfWeek = dayOfWeek
        self.isAvailable = isAvailable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        dayOfWeek = try container.decode(DayOfWeek.self, forKey: .dayOfWeek)
        isAvailable = try container.decodeIfPresent(Bool.self, forKey: .isAvailable) ?? true
    }
}

/// Jour de la semaine
enum DayOfWeek: String, CaseIterable, Codable, Equatable {
    case monday = "monday"
    case tuesday = "tuesday"
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    case sunday = "sunday"

    var displayName: String {
        switch self {
        case .monday: return "Lundi"
        case .tuesday: return "Mardi"
        case .wednesday: return "Mercredi"
        case .thursday: return "Jeudi"
        case .friday: return "Vendredi"
        case .saturday: return "Samedi"
        case .sunday: return "Dimanche"
        }
    }

}

/// Facteurs de style de vie
struct LifestyleFactors: Codable, Equatable {
    var workType: WorkType = .office
    var commuteTime: Int = 0 // en minutes
    var stressLevel: Int = 5 // 1-10
    var sleepSchedule: SleepSchedule = SleepSchedule()
    var dietType: DietType = .balanced
    var smokingStatus: SmokingStatus = .never
    var alcoholConsumption: AlcoholConsumption = .none
    var hasChildren: Bool = false
    var pets: [String] = []
    var hobbies: [String] = []
    var travelFrequency: String = ""

    var isEmpty: Bool {
        return workType == .office &&
               commuteTime == 0 &&
               stressLevel == 5 &&
               dietType == .balanced &&
               smokingStatus == .never &&
               alcoholConsumption == .none &&
               !hasChildren &&
               pets.isEmpty &&
               hobbies.isEmpty &&
               travelFrequency.isEmpty
    }
}

/// Type de travail
enum WorkType: String, CaseIterable, Codable, Equatable {
    case office = "office"
    case remote = "remote"
    case hybrid = "hybrid"
    case field = "field"
    case shift = "shift"

    var displayName: String {
        switch self {
        case .office: return "Bureau"
        case .remote: return "Télétravail"
        case .hybrid: return "Hybride"
        case .field: return "Terrain"
        case .shift: return "Posté"
        }
    }
}

/// Horaires de sommeil
struct SleepSchedule: Codable, Equatable {
    var sleepDuration: Int = 8 // en heures
}

/// Type de régime
enum DietType: String, CaseIterable, Codable, Equatable {
    case balanced = "balanced"
    case vegetarian = "vegetarian"
    case vegan = "vegan"
    case keto = "keto"
    case paleo = "paleo"
    case mediterranean = "mediterranean"

    var displayName: String {
        switch self {
        case .balanced: return "Équilibré"
        case .vegetarian: return "Végétarien"
        case .vegan: return "Végan"
        case .keto: return "Keto"
        case .paleo: return "Paléo"
        case .mediterranean: return "Méditerranéen"
        }
    }
}

/// Statut tabagique
enum SmokingStatus: String, CaseIterable, Codable, Equatable {
    case never = "never"
    case former = "former"
    case current = "current"
    case occasional = "occasional"

    var displayName: String {
        switch self {
        case .never: return "Jamais"
        case .former: return "Ancien fumeur"
        case .current: return "Fumeur actuel"
        case .occasional: return "Occasionnel"
        }
    }
}

/// Consommation d'alcool
enum AlcoholConsumption: String, CaseIterable, Codable, Equatable {
    case none = "none"
    case light = "light"
    case moderate = "moderate"
    case heavy = "heavy"

    var displayName: String {
        switch self {
        case .none: return "Aucune"
        case .light: return "Légère"
        case .moderate: return "Modérée"
        case .heavy: return "Importante"
        }
    }
}

/// Horaire de travail
struct WorkSchedule: Codable, Equatable {
    var workDays: [WorkDay] = []
    var workStartTime: Date = Date()
    var workEndTime: Date = Date()
    var isFlexible: Bool = false
    var workFromHome: Bool = false

    var isEmpty: Bool {
        return workDays.isEmpty &&
               !isFlexible &&
               !workFromHome
    }
}

/// Jour de travail
enum WorkDay: String, CaseIterable, Codable, Equatable {
    case monday = "monday"
    case tuesday = "tuesday"
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    case sunday = "sunday"

    var displayName: String {
        switch self {
        case .monday: return "Lundi"
        case .tuesday: return "Mardi"
        case .wednesday: return "Mercredi"
        case .thursday: return "Jeudi"
        case .friday: return "Vendredi"
        case .saturday: return "Samedi"
        case .sunday: return "Dimanche"
        }
    }
}

/// Situation familiale
struct FamilySituation: Codable, Equatable {
    var maritalStatus: MaritalStatus = .single
    var hasChildren: Bool = false
    var numberOfChildren: Int = 0
    var childrenAges: [Int] = []
    var caregivingResponsibilities: Bool = false
    var livingSituation: String = ""
    var supportSystem: String = ""
}

/// Statut marital
enum MaritalStatus: String, CaseIterable, Codable, Equatable {
    case single = "single"
    case married = "married"
    case divorced = "divorced"
    case widowed = "widowed"
    case cohabiting = "cohabiting"

    var displayName: String {
        switch self {
        case .single: return "Célibataire"
        case .married: return "Marié(e)"
        case .divorced: return "Divorcé(e)"
        case .widowed: return "Veuf/Veuve"
        case .cohabiting: return "En concubinage"
        }
    }
}

/// Qualité du sommeil
enum SleepQuality: String, CaseIterable, Codable, Equatable {
    case excellent = "Excellent"
    case good = "Bon"
    case fair = "Correct"
    case poor = "Mauvais"
    case veryPoor = "Très mauvais"

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .veryPoor: return .red
        }
}
}
