//
//  SleepModels.swift
//  Process
//
//  Modèles pour les données de sommeil dans l'onboarding
//

import Foundation
import HealthKit

/// Qualité perçue du sommeil actuel (pour l'onboarding)
enum OnboardingSleepQuality: String, Codable, CaseIterable, Identifiable, Equatable {
    case excellent = "Excellent"
    case veryGood = "Très bon"
    case good = "Bon"
    case average = "Moyen"
    case poor = "Mauvais"
    case veryPoor = "Très mauvais"

    var id: String { rawValue }

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .excellent: return AppCopy.t("Excellent", en: "Excellent")
        case .veryGood: return AppCopy.t("Très bon", en: "Very good")
        case .good: return AppCopy.t("Bon", en: "Good")
        case .average: return AppCopy.t("Moyen", en: "Average")
        case .poor: return AppCopy.t("Mauvais", en: "Poor")
        case .veryPoor: return AppCopy.t("Très mauvais", en: "Very poor")
        }
    }

    var emoji: String {
        switch self {
        case .excellent: return "😴"
        case .veryGood: return "😊"
        case .good: return "🙂"
        case .average: return "😐"
        case .poor: return "😴"
        case .veryPoor: return "😫"
        }
    }

    @MainActor
    var description: String {
        switch self {
        case .excellent: return AppCopy.t("Je me réveille toujours reposé à 100%", en: "I always wake up fully rested")
        case .veryGood: return AppCopy.t("Je me réveille généralement bien reposé", en: "I usually wake up well rested")
        case .good: return AppCopy.t("Je me réveille assez reposé la plupart du temps", en: "I wake up fairly rested most of the time")
        case .average: return AppCopy.t("Parfois reposé, parfois fatigué", en: "Sometimes rested, sometimes tired")
        case .poor: return AppCopy.t("Je me réveille souvent fatigué", en: "I often wake up tired")
        case .veryPoor: return AppCopy.t("Je me réveille toujours épuisé", en: "I always wake up exhausted")
        }
    }

    var score: Double {
        switch self {
        case .excellent: return 5.0
        case .veryGood: return 4.0
        case .good: return 3.0
        case .average: return 2.0
        case .poor: return 1.0
        case .veryPoor: return 0.0
        }
    }
}

/// Fréquence de fatigue
enum FatigueFrequency: String, Codable, CaseIterable, Identifiable, Equatable {
    case never = "Jamais"
    case rarely = "Rarement"
    case sometimes = "Parfois"
    case often = "Souvent"
    case always = "Toujours"

    var id: String { rawValue }

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .never: return AppCopy.t("Jamais", en: "Never")
        case .rarely: return AppCopy.t("Rarement", en: "Rarely")
        case .sometimes: return AppCopy.t("Parfois", en: "Sometimes")
        case .often: return AppCopy.t("Souvent", en: "Often")
        case .always: return AppCopy.t("Toujours", en: "Always")
        }
    }

    var emoji: String {
        switch self {
        case .never: return "⚡"
        case .rarely: return "😊"
        case .sometimes: return "😐"
        case .often: return "😴"
        case .always: return "😫"
        }
    }

    @MainActor
    var description: String {
        switch self {
        case .never: return AppCopy.t("Je suis toujours plein d'énergie", en: "I'm always full of energy")
        case .rarely: return AppCopy.t("Je me sens fatigué de temps en temps", en: "I feel tired every now and then")
        case .sometimes: return AppCopy.t("J'ai des moments de fatigue", en: "I have spells of fatigue")
        case .often: return AppCopy.t("Je me sens souvent fatigué", en: "I often feel tired")
        case .always: return AppCopy.t("Je suis constamment fatigué", en: "I'm constantly tired")
        }
    }

    var score: Double {
        switch self {
        case .never: return 4.0
        case .rarely: return 3.0
        case .sometimes: return 2.0
        case .often: return 1.0
        case .always: return 0.0
        }
    }
}

/// Pics de fatigue
enum FatiguePeaks: String, Codable, CaseIterable, Identifiable, Equatable {
    case morning = "Le matin"
    case afternoon = "L'après-midi"
    case evening = "Le soir"
    case noPeaks = "Pas de pics particuliers"
    case allDay = "Toute la journée"

    var id: String { rawValue }

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .morning: return AppCopy.t("Le matin", en: "In the morning")
        case .afternoon: return AppCopy.t("L'après-midi", en: "In the afternoon")
        case .evening: return AppCopy.t("Le soir", en: "In the evening")
        case .noPeaks: return AppCopy.t("Pas de pics particuliers", en: "No particular peaks")
        case .allDay: return AppCopy.t("Toute la journée", en: "All day")
        }
    }

    var emoji: String {
        switch self {
        case .morning: return "🌅"
        case .afternoon: return "☀️"
        case .evening: return "🌆"
        case .noPeaks: return "⚡"
        case .allDay: return "😫"
        }
    }

    @MainActor
    var description: String {
        switch self {
        case .morning: return AppCopy.t("Je suis le plus fatigué au réveil", en: "I'm most tired when I wake up")
        case .afternoon: return AppCopy.t("J'ai un coup de barre après le déjeuner", en: "I crash after lunch")
        case .evening: return AppCopy.t("Je suis épuisé en fin de journée", en: "I'm wiped out by end of day")
        case .noPeaks: return AppCopy.t("Ma fatigue est constante", en: "My fatigue is steady")
        case .allDay: return AppCopy.t("Je suis fatigué du matin au soir", en: "I'm tired from morning to night")
        }
    }
}

/// Profil de sommeil complet
struct SleepProfile: Codable, Equatable {
    var sleepQuality: OnboardingSleepQuality?
    var fatigueFrequency: FatigueFrequency?
    var fatiguePeaks: Set<FatiguePeaks> = []  // Pics de fatigue (peut être multiple)
    var averageSleepHours: Double?  // Heures de sommeil moyennes (si connu)
    var bedtimePreference: String?  // Heure de coucher préférée
    var wakeTimePreference: String?  // Heure de réveil préférée
    var sleepIssues: [String] = []  // Problèmes de sommeil (insomnie, réveils nocturnes, etc.)

    var isComplete: Bool {
        return sleepQuality != nil && fatigueFrequency != nil && !fatiguePeaks.isEmpty
    }
}

/// Données de sommeil récupérées depuis HealthKit
struct RecoveredSleepData: Equatable {
    var totalNights: Int
    var averageSleepHours: Double
    var averageBedtime: Date?
    var averageWakeTime: Date?
    var bestNight: (date: Date, hours: Double)?
    var worstNight: (date: Date, hours: Double)?
    var sleepSamples: [HKCategorySample]
    var recoveryScore: Double?  // Score de récupération moyen

    // HKCategorySample n'est pas Equatable, on compare seulement les métadonnées importantes
    static func == (lhs: RecoveredSleepData, rhs: RecoveredSleepData) -> Bool {
        return lhs.totalNights == rhs.totalNights &&
               lhs.averageSleepHours == rhs.averageSleepHours &&
               lhs.averageBedtime == rhs.averageBedtime &&
               lhs.averageWakeTime == rhs.averageWakeTime &&
               lhs.bestNight?.date == rhs.bestNight?.date &&
               lhs.bestNight?.hours == rhs.bestNight?.hours &&
               lhs.worstNight?.date == rhs.worstNight?.date &&
               lhs.worstNight?.hours == rhs.worstNight?.hours &&
               lhs.recoveryScore == rhs.recoveryScore &&
               lhs.sleepSamples.count == rhs.sleepSamples.count
    }

    static var empty: RecoveredSleepData {
        RecoveredSleepData(
            totalNights: 0,
            averageSleepHours: 0.0,
            averageBedtime: nil,
            averageWakeTime: nil,
            bestNight: nil,
            worstNight: nil,
            sleepSamples: [],
            recoveryScore: nil
        )
    }
}

