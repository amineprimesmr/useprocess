//
//  UserProfileEnums.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

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

