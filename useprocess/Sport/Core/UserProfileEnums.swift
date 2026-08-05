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

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .veryLow: return AppCopy.t("Très faible", en: "Very low")
        case .low: return AppCopy.t("Faible", en: "Low")
        case .moderate: return AppCopy.t("Modéré", en: "Moderate")
        case .high: return AppCopy.t("Élevé", en: "High")
        case .veryHigh: return AppCopy.t("Très élevé", en: "Very high")
        }
    }

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

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .veryEarly: return AppCopy.t("Très matinal", en: "Very early bird")
        case .early: return AppCopy.t("Matinal", en: "Early bird")
        case .intermediate: return AppCopy.t("Intermédiaire", en: "Intermediate")
        case .late: return AppCopy.t("Tardif", en: "Night owl")
        case .veryLate: return AppCopy.t("Très tardif", en: "Very late owl")
        }
    }

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
        case .totalRest:
            return AppCopy.tSync(
                "Besoin réduit car peu de dépense énergétique",
                en: "Lower needs due to low energy expenditure"
            )
        case .veryLow:
            return AppCopy.tSync(
                "Activité minimale, récupération rapide",
                en: "Minimal activity, fast recovery"
            )
        case .low:
            return AppCopy.tSync(
                "Niveau d'activité normal de la baseline",
                en: "Normal baseline activity level"
            )
        case .moderateLow:
            return AppCopy.tSync(
                "Légère fatigue accumulée",
                en: "Slight accumulated fatigue"
            )
        case .moderate:
            return AppCopy.tSync(
                "Début de fatigue musculaire",
                en: "Early muscle fatigue"
            )
        case .moderateHigh:
            return AppCopy.tSync(
                "Fatigue significative, micro-déchirures musculaires",
                en: "Significant fatigue, muscle micro-tears"
            )
        case .high:
            return AppCopy.tSync(
                "Fatigue musculaire importante, inflammation",
                en: "Significant muscle fatigue, inflammation"
            )
        case .veryHigh:
            return AppCopy.tSync(
                "Micro-lésions musculaires, cortisol élevé, stress oxydatif",
                en: "Muscle micro-damage, elevated cortisol, oxidative stress"
            )
        case .extreme:
            return AppCopy.tSync(
                "Épuisement des réserves énergétiques, glycogène bas",
                en: "Depleted energy stores, low glycogen"
            )
        case .maximum:
            return AppCopy.tSync(
                "Dommages musculaires majeurs, inflammation systémique",
                en: "Major muscle damage, systemic inflammation"
            )
        }
    }
}

/// Niveau d'activité de l'utilisateur
enum ActivityLevel: String, CaseIterable, Codable, Equatable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "veryHigh"

    @MainActor
    var displayName: String {
        switch self {
        case .low: return AppCopy.t("Faible", en: "Low")
        case .moderate: return AppCopy.t("Modéré", en: "Moderate")
        case .high: return AppCopy.t("Élevé", en: "High")
        case .veryHigh: return AppCopy.t("Très élevé", en: "Very high")
        }
    }
}

/// Niveau de fitness de l'utilisateur
enum FitnessLevel: String, CaseIterable, Codable, Equatable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"

    @MainActor
    var displayName: String {
        switch self {
        case .beginner: return AppCopy.t("Débutant", en: "Beginner")
        case .intermediate: return AppCopy.t("Intermédiaire", en: "Intermediate")
        case .advanced: return AppCopy.t("Avancé", en: "Advanced")
        case .expert: return AppCopy.t("Expert", en: "Expert")
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

    @MainActor
    var displayName: String {
        switch self {
        case .weightLoss: return AppCopy.t("Perte de poids", en: "Weight loss")
        case .muscleGain: return AppCopy.t("Prise de muscle", en: "Muscle gain")
        case .endurance: return AppCopy.t("Endurance", en: "Endurance")
        case .strength: return AppCopy.t("Force", en: "Strength")
        case .flexibility: return AppCopy.t("Flexibilité", en: "Flexibility")
        case .generalHealth: return AppCopy.t("Santé générale", en: "General health")
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

    @MainActor
    var displayName: String {
        switch self {
        case .low: return AppCopy.t("Faible", en: "Low")
        case .moderate: return AppCopy.t("Modérée", en: "Moderate")
        case .high: return AppCopy.t("Élevée", en: "High")
        case .veryHigh: return AppCopy.t("Très élevée", en: "Very high")
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

    @MainActor
    var displayName: String {
        switch self {
        case .none: return AppCopy.t("Aucun", en: "None")
        case .dumbbells: return AppCopy.t("Haltères", en: "Dumbbells")
        case .barbell: return AppCopy.t("Barre", en: "Barbell")
        case .resistanceBands: return AppCopy.t("Élastiques", en: "Resistance bands")
        case .yogaMat: return AppCopy.t("Tapis de yoga", en: "Yoga mat")
        case .treadmill: return AppCopy.t("Tapis de course", en: "Treadmill")
        case .bike: return AppCopy.t("Vélo", en: "Bike")
        case .fullGym: return AppCopy.t("Salle complète", en: "Full gym")
        }
    }
}

/// Sexe de l'utilisateur
enum Sex: String, CaseIterable, Codable, Equatable {
    case male = "male"
    case female = "female"
    case other = "other"

    @MainActor
    var displayName: String {
        switch self {
        case .male: return AppCopy.t("Homme", en: "Male")
        case .female: return AppCopy.t("Femme", en: "Female")
        case .other: return AppCopy.t("Autre", en: "Other")
        }
    }
}

/// Statut de l'utilisateur avec couleurs associées
enum UserStatus: String, CaseIterable, Codable {
    case active = "active"
    case sick = "sick"
    case paused = "paused"

    @MainActor
    var displayName: String {
        switch self {
        case .active: return AppCopy.t("Actif", en: "Active")
        case .sick: return AppCopy.t("Malade/Blessé", en: "Sick / Injured")
        case .paused: return AppCopy.t("En pause", en: "Paused")
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

    @MainActor
    var displayName: String {
        switch self {
        case .monday: return AppCopy.t("Lundi", en: "Monday")
        case .tuesday: return AppCopy.t("Mardi", en: "Tuesday")
        case .wednesday: return AppCopy.t("Mercredi", en: "Wednesday")
        case .thursday: return AppCopy.t("Jeudi", en: "Thursday")
        case .friday: return AppCopy.t("Vendredi", en: "Friday")
        case .saturday: return AppCopy.t("Samedi", en: "Saturday")
        case .sunday: return AppCopy.t("Dimanche", en: "Sunday")
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

    @MainActor
    var displayName: String {
        switch self {
        case .office: return AppCopy.t("Bureau", en: "Office")
        case .remote: return AppCopy.t("Télétravail", en: "Remote")
        case .hybrid: return AppCopy.t("Hybride", en: "Hybrid")
        case .field: return AppCopy.t("Terrain", en: "Field")
        case .shift: return AppCopy.t("Posté", en: "Shift work")
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

    @MainActor
    var displayName: String {
        switch self {
        case .balanced: return AppCopy.t("Équilibré", en: "Balanced")
        case .vegetarian: return AppCopy.t("Végétarien", en: "Vegetarian")
        case .vegan: return AppCopy.t("Végan", en: "Vegan")
        case .keto: return AppCopy.t("Keto", en: "Keto")
        case .paleo: return AppCopy.t("Paléo", en: "Paleo")
        case .mediterranean: return AppCopy.t("Méditerranéen", en: "Mediterranean")
        }
    }
}

/// Statut tabagique
enum SmokingStatus: String, CaseIterable, Codable, Equatable {
    case never = "never"
    case former = "former"
    case current = "current"
    case occasional = "occasional"

    @MainActor
    var displayName: String {
        switch self {
        case .never: return AppCopy.t("Jamais", en: "Never")
        case .former: return AppCopy.t("Ancien fumeur", en: "Former smoker")
        case .current: return AppCopy.t("Fumeur actuel", en: "Current smoker")
        case .occasional: return AppCopy.t("Occasionnel", en: "Occasional")
        }
    }
}

/// Consommation d'alcool
enum AlcoholConsumption: String, CaseIterable, Codable, Equatable {
    case none = "none"
    case light = "light"
    case moderate = "moderate"
    case heavy = "heavy"

    @MainActor
    var displayName: String {
        switch self {
        case .none: return AppCopy.t("Aucune", en: "None")
        case .light: return AppCopy.t("Légère", en: "Light")
        case .moderate: return AppCopy.t("Modérée", en: "Moderate")
        case .heavy: return AppCopy.t("Importante", en: "Heavy")
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

    @MainActor
    var displayName: String {
        switch self {
        case .monday: return AppCopy.t("Lundi", en: "Monday")
        case .tuesday: return AppCopy.t("Mardi", en: "Tuesday")
        case .wednesday: return AppCopy.t("Mercredi", en: "Wednesday")
        case .thursday: return AppCopy.t("Jeudi", en: "Thursday")
        case .friday: return AppCopy.t("Vendredi", en: "Friday")
        case .saturday: return AppCopy.t("Samedi", en: "Saturday")
        case .sunday: return AppCopy.t("Dimanche", en: "Sunday")
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

    @MainActor
    var displayName: String {
        switch self {
        case .single: return AppCopy.t("Célibataire", en: "Single")
        case .married: return AppCopy.t("Marié(e)", en: "Married")
        case .divorced: return AppCopy.t("Divorcé(e)", en: "Divorced")
        case .widowed: return AppCopy.t("Veuf/Veuve", en: "Widowed")
        case .cohabiting: return AppCopy.t("En concubinage", en: "Cohabiting")
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

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .excellent: return AppCopy.t("Excellent", en: "Excellent")
        case .good: return AppCopy.t("Bon", en: "Good")
        case .fair: return AppCopy.t("Correct", en: "Fair")
        case .poor: return AppCopy.t("Mauvais", en: "Poor")
        case .veryPoor: return AppCopy.t("Très mauvais", en: "Very poor")
        }
    }

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
