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

    var description: String {
        switch self {
        case .excellent: return "Je me réveille toujours reposé à 100%"
        case .veryGood: return "Je me réveille généralement bien reposé"
        case .good: return "Je me réveille assez reposé la plupart du temps"
        case .average: return "Parfois reposé, parfois fatigué"
        case .poor: return "Je me réveille souvent fatigué"
        case .veryPoor: return "Je me réveille toujours épuisé"
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

    var emoji: String {
        switch self {
        case .never: return "⚡"
        case .rarely: return "😊"
        case .sometimes: return "😐"
        case .often: return "😴"
        case .always: return "😫"
        }
    }

    var description: String {
        switch self {
        case .never: return "Je suis toujours plein d'énergie"
        case .rarely: return "Je me sens fatigué de temps en temps"
        case .sometimes: return "J'ai des moments de fatigue"
        case .often: return "Je me sens souvent fatigué"
        case .always: return "Je suis constamment fatigué"
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

    var emoji: String {
        switch self {
        case .morning: return "🌅"
        case .afternoon: return "☀️"
        case .evening: return "🌆"
        case .noPeaks: return "⚡"
        case .allDay: return "😫"
        }
    }

    var description: String {
        switch self {
        case .morning: return "Je suis le plus fatigué au réveil"
        case .afternoon: return "J'ai un coup de barre après le déjeuner"
        case .evening: return "Je suis épuisé en fin de journée"
        case .noPeaks: return "Ma fatigue est constante"
        case .allDay: return "Je suis fatigué du matin au soir"
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

/// Besoin de sommeil calculé
struct CalculatedSleepNeed: Equatable {
    var recommendedHours: Double  // Heures recommandées
    var minimumHours: Double  // Minimum nécessaire
    var optimalHours: Double  // Optimal pour la performance
    var currentAverage: Double?  // Moyenne actuelle (si disponible)
    var deficit: Double?  // Déficit par rapport à l'optimal

    var recommendation: String {
        if let current = currentAverage {
            if current < minimumHours {
                return "Tu dors en dessous du minimum recommandé"
            } else if current < optimalHours {
                return "Tu es proche de l'optimal, on peut encore améliorer"
            } else {
                return "Tu dors dans la zone optimale"
            }
        }
        return "On va t'aider à trouver ton rythme optimal"
    }
}

/// Fenêtre de sommeil optimale
struct OptimalSleepWindow: Equatable {
    var recommendedBedtime: Date  // Heure de coucher recommandée
    var recommendedWakeTime: Date  // Heure de réveil recommandée
    var sleepDuration: TimeInterval  // Durée de sommeil
    var explanation: String  // Explication personnalisée

    var bedtimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: recommendedBedtime)
    }

    var wakeTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: recommendedWakeTime)
    }
}
