//
//  NutritionModels.swift
//  Process
//
//  Modèles pour la nutrition dans l'onboarding
//

import Foundation

/// Niveau d'estimation de l'alimentation actuelle
enum NutritionQuality: String, Codable, CaseIterable {
    case excellent = "Excellente"
    case veryGood = "Très bonne"
    case good = "Bonne"
    case average = "Moyenne"
    case poor = "Non adaptée"
    case veryPoor = "Très mauvaise"

    var emoji: String {
        switch self {
        case .excellent: return "🌟"
        case .veryGood: return "✨"
        case .good: return "👍"
        case .average: return "😐"
        case .poor: return "😕"
        case .veryPoor: return "😞"
        }
    }

    var description: String {
        switch self {
        case .excellent: return "Je mange équilibré et varié tous les jours. Mon alimentation est optimale pour mes objectifs."
        case .veryGood: return "Je fais attention à mon alimentation la plupart du temps"
        case .good: return "Je mange plutôt bien mais je peux améliorer certains aspects de mon alimentation."
        case .average: return "Je contrôle plus ou moins mon alimentation. Il y a des jours où je mange bien et d'autres moins."
        case .poor: return "Je mange souvent n'importe quoi. Mon alimentation n'est pas adaptée à mes objectifs."
        case .veryPoor: return "Je mange n'importe quoi. Je ne fais vraiment pas attention à ce que je mange."
        }
    }

    // ✅ Commentaire principal pour chaque qualité
    var comment: String {
        switch self {
        case .excellent: return "Excellente"
        case .veryGood: return "Très bonne"
        case .good: return "Bonne"
        case .average: return "Améliorable"
        case .poor: return "Non adaptée"
        case .veryPoor: return "Très mauvaise"
        }
    }

    var value: Double {
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

/// Restrictions alimentaires
enum DietaryRestriction: String, Codable, CaseIterable, Identifiable {
    case none = "Aucune"
    case vegan = "Végan"
    case vegetarian = "Végétarien"
    case pescatarian = "Pescétarien"
    case glutenFree = "Sans gluten"
    case lactoseFree = "Intolérant au lactose"
    case peanutAllergy = "Allergie aux arachides"
    case shellfishAllergy = "Fruits de mer ou crustacés"
    case religiousPreferences = "Préférences religieuses"
    case other = "Autre"
    // Anciennes options conservées pour compatibilité mais non affichées
    case halal = "Halal"
    case kosher = "Cacher"
    case nutAllergy = "Allergie aux noix"
    case eggAllergy = "Allergie aux œufs"
    case soyAllergy = "Allergie au soja"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .none: return "checkmark.circle"
        case .vegan: return "leaf.circle.fill"
        case .vegetarian: return "leaf.fill"
        case .pescatarian: return "fish.fill"
        case .glutenFree: return "wheat"
        case .lactoseFree: return "drop.fill"
        case .peanutAllergy: return "exclamationmark.triangle.fill"
        case .shellfishAllergy: return "exclamationmark.triangle.fill"
        case .religiousPreferences: return "moon.stars.fill"
        case .other: return "ellipsis.circle"
        // Anciennes options
        case .halal: return "moon.stars.fill"
        case .kosher: return "star.fill"
        case .nutAllergy: return "exclamationmark.triangle.fill"
        case .eggAllergy: return "exclamationmark.triangle.fill"
        case .soyAllergy: return "exclamationmark.triangle.fill"
        }
    }

    var description: String {
        switch self {
        case .none: return "Je n'ai aucune restriction"
        case .vegan: return "Je ne mange aucun produit d'origine animale"
        case .vegetarian: return "Je ne mange pas de viande"
        case .pescatarian: return "Je mange du poisson mais pas de viande"
        case .glutenFree: return "Je dois éviter le gluten"
        case .lactoseFree: return "Je dois éviter le lactose"
        case .peanutAllergy: return "Allergie aux arachides"
        case .shellfishAllergy: return "Allergie aux fruits de mer ou crustacés"
        case .religiousPreferences: return "Préférences religieuses (halal, casher, etc.)"
        case .other: return "Autre restriction alimentaire"
        // Anciennes options
        case .halal: return "Alimentation conforme aux règles halal"
        case .kosher: return "Alimentation conforme aux règles casher"
        case .nutAllergy: return "Allergie aux noix et fruits à coque"
        case .eggAllergy: return "Allergie aux œufs"
        case .soyAllergy: return "Allergie au soja"
        }
    }
}

/// Obstacles à une bonne nutrition
enum NutritionObstacle: String, Codable, CaseIterable, Identifiable {
    case snacking = "Grignotage"
    case dontKnowWhatToBuy = "Ne pas savoir quoi acheter"
    case lackOfTime = "Manque de temps pour cuisiner"
    case lackOfMotivation = "Manque de motivation"
    case emotionalEating = "Manger par émotion"
    case socialPressure = "Pression sociale"
    case budget = "Budget limité"
    case noObstacle = "Aucun obstacle"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .snacking: return "cookie.fill"
        case .dontKnowWhatToBuy: return "cart.fill"
        case .lackOfTime: return "clock.fill"
        case .lackOfMotivation: return "battery.0"
        case .emotionalEating: return "heart.fill"
        case .socialPressure: return "person.2.fill"
        case .budget: return "dollarsign.circle.fill"
        case .noObstacle: return "checkmark.shield.fill"
        }
    }

    var description: String {
        switch self {
        case .snacking: return "Je grignote souvent entre les repas"
        case .dontKnowWhatToBuy: return "Je ne sais pas quoi acheter au supermarché"
        case .lackOfTime: return "Je n'ai pas le temps de cuisiner"
        case .lackOfMotivation: return "Je manque de motivation pour bien manger"
        case .emotionalEating: return "Je mange quand je suis stressé ou triste"
        case .socialPressure: return "Les sorties sociales me font manger mal"
        case .budget: return "Mon budget ne me permet pas de bien manger"
        case .noObstacle: return "Je n'ai pas d'obstacle particulier"
        }
    }
}

/// Expérience avec la perte/prise de poids
enum WeightManagementExperience: String, Codable, CaseIterable, Identifiable {
    case neverTried = "Jamais essayé"
    case triedMultiple = "J'ai essayé plusieurs fois"
    case currentlyTrying = "J'essaie actuellement"
    case succeeded = "J'ai réussi par le passé"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .neverTried: return "questionmark.circle"
        case .triedMultiple: return "repeat.circle"
        case .currentlyTrying: return "arrow.clockwise.circle"
        case .succeeded: return "checkmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .neverTried: return "C'est la première fois que j'essaie"
        case .triedMultiple: return "J'ai essayé plusieurs fois dans le passé"
        case .currentlyTrying: return "Je suis en train d'essayer actuellement"
        case .succeeded: return "J'ai réussi à atteindre mon objectif avant"
        }
    }
}

/// Niveau d'hydratation
enum HydrationLevel: String, Codable, CaseIterable {
    case excellent = "Excellente"
    case veryGood = "Très bonne"
    case good = "Bonne"
    case average = "Moyenne"
    case poor = "Mauvaise"
    case veryPoor = "Très mauvaise"

    var emoji: String {
        switch self {
        case .excellent: return "💧"
        case .veryGood: return "💦"
        case .good: return "🥤"
        case .average: return "☕"
        case .poor: return "🌵"
        case .veryPoor: return "🏜️"
        }
    }

    var description: String {
        switch self {
        case .excellent: return "Je bois 2-3L d'eau par jour facilement"
        case .veryGood: return "Je bois environ 1.5-2L par jour"
        case .good: return "Je bois environ 1L par jour"
        case .average: return "Je bois de l'eau mais pas régulièrement"
        case .poor: return "Je bois rarement de l'eau"
        case .veryPoor: return "Je ne bois presque jamais d'eau"
        }
    }

    var litersPerDay: Double {
        switch self {
        case .excellent: return 2.5
        case .veryGood: return 1.75
        case .good: return 1.0
        case .average: return 0.75
        case .poor: return 0.5
        case .veryPoor: return 0.25
        }
    }
}

/// Repas le plus difficile pour manger sainement
enum HardestMeal: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Au petit-déjeuner"
    case lunch = "Au déjeuner"
    case dinner = "Au dîner"
    case none = "Aucun"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .breakfast: return "🥐"
        case .lunch: return "🍽️"
        case .dinner: return "🍲"
        case .none: return "✅"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .none: return "checkmark.circle.fill"
        }
    }
}

/// Modèle complet de nutrition
struct NutritionProfile: Codable, Equatable {
    var nutritionQuality: NutritionQuality?
    var dietaryRestrictions: Set<DietaryRestriction> = []
    var nutritionObstacles: Set<NutritionObstacle> = []
    var weightManagementExperience: WeightManagementExperience?
    var hasPerfectNutrition: Bool?  // ✨ Croyance en une alimentation parfaite
    var hardestMeal: HardestMeal?  // ✨ Repas le plus difficile pour manger sainement
    var hasSufficientHydration: Bool?  // ✨ Penses-tu t'hydrater suffisamment ? (Oui/Non)
    var hydrationLevel: HydrationLevel?
    var otherRestrictions: String?  // Pour "Autre" restriction
}
