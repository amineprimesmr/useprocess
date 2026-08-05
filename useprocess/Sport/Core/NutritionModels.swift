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
        case .excellent:
            return AppCopy.tSync(
                "Je mange équilibré et varié tous les jours. Mon alimentation est optimale pour mes objectifs.",
                en: "I eat balanced and varied meals every day. My nutrition is on point for my goals."
            )
        case .veryGood:
            return AppCopy.tSync(
                "Je fais attention à mon alimentation la plupart du temps",
                en: "I watch what I eat most of the time"
            )
        case .good:
            return AppCopy.tSync(
                "Je mange plutôt bien mais je peux améliorer certains aspects de mon alimentation.",
                en: "I eat pretty well, but I can still improve some habits."
            )
        case .average:
            return AppCopy.tSync(
                "Je contrôle plus ou moins mon alimentation. Il y a des jours où je mange bien et d'autres moins.",
                en: "My eating is hit or miss — some good days, some less so."
            )
        case .poor:
            return AppCopy.tSync(
                "Je mange souvent n'importe quoi. Mon alimentation n'est pas adaptée à mes objectifs.",
                en: "I often eat whatever. My nutrition doesn't match my goals."
            )
        case .veryPoor:
            return AppCopy.tSync(
                "Je mange n'importe quoi. Je ne fais vraiment pas attention à ce que je mange.",
                en: "I eat whatever and don't really pay attention to food."
            )
        }
    }

    /// Libellé UI onboarding (bilingue).
    @MainActor
    var localizedDescription: String {
        switch self {
        case .excellent:
            return OnboardingCopy.t(
                "Je mange équilibré et varié tous les jours. Mon alimentation est optimale pour mes objectifs.",
                en: "I eat balanced and varied meals every day. My nutrition is on point for my goals."
            )
        case .veryGood:
            return OnboardingCopy.t(
                "Je fais attention à mon alimentation la plupart du temps",
                en: "I watch what I eat most of the time"
            )
        case .good:
            return OnboardingCopy.t(
                "Je mange plutôt bien mais je peux améliorer certains aspects de mon alimentation.",
                en: "I eat pretty well, but I can still improve some habits."
            )
        case .average:
            return OnboardingCopy.t(
                "Je contrôle plus ou moins mon alimentation. Il y a des jours où je mange bien et d'autres moins.",
                en: "My eating is hit or miss — some good days, some less so."
            )
        case .poor:
            return OnboardingCopy.t(
                "Je mange souvent n'importe quoi. Mon alimentation n'est pas adaptée à mes objectifs.",
                en: "I often eat whatever. My nutrition doesn't match my goals."
            )
        case .veryPoor:
            return OnboardingCopy.t(
                "Je mange n'importe quoi. Je ne fais vraiment pas attention à ce que je mange.",
                en: "I eat whatever and don't really pay attention to food."
            )
        }
    }

    // ✅ Commentaire principal pour chaque qualité
    var comment: String {
        switch self {
        case .excellent: return AppCopy.tSync("Excellente", en: "Excellent")
        case .veryGood: return AppCopy.tSync("Très bonne", en: "Very good")
        case .good: return AppCopy.tSync("Bonne", en: "Good")
        case .average: return AppCopy.tSync("Améliorable", en: "Needs work")
        case .poor: return AppCopy.tSync("Non adaptée", en: "Off track")
        case .veryPoor: return AppCopy.tSync("Très mauvaise", en: "Very poor")
        }
    }

    /// Titre UI onboarding (bilingue) — basé sur `comment`.
    @MainActor
    var title: String {
        switch self {
        case .excellent: return OnboardingCopy.t("Excellente", en: "Excellent")
        case .veryGood: return OnboardingCopy.t("Très bonne", en: "Very good")
        case .good: return OnboardingCopy.t("Bonne", en: "Good")
        case .average: return OnboardingCopy.t("Améliorable", en: "Needs work")
        case .poor: return OnboardingCopy.t("Non adaptée", en: "Off track")
        case .veryPoor: return OnboardingCopy.t("Très mauvaise", en: "Very poor")
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

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .none: return AppCopy.t("Aucune", en: "None")
        case .vegan: return AppCopy.t("Végan", en: "Vegan")
        case .vegetarian: return AppCopy.t("Végétarien", en: "Vegetarian")
        case .pescatarian: return AppCopy.t("Pescétarien", en: "Pescatarian")
        case .glutenFree: return AppCopy.t("Sans gluten", en: "Gluten-free")
        case .lactoseFree: return AppCopy.t("Intolérant au lactose", en: "Lactose intolerant")
        case .peanutAllergy: return AppCopy.t("Allergie aux arachides", en: "Peanut allergy")
        case .shellfishAllergy: return AppCopy.t("Fruits de mer ou crustacés", en: "Shellfish allergy")
        case .religiousPreferences: return AppCopy.t("Préférences religieuses", en: "Religious preferences")
        case .other: return AppCopy.t("Autre", en: "Other")
        case .halal: return AppCopy.t("Halal", en: "Halal")
        case .kosher: return AppCopy.t("Cacher", en: "Kosher")
        case .nutAllergy: return AppCopy.t("Allergie aux noix", en: "Nut allergy")
        case .eggAllergy: return AppCopy.t("Allergie aux œufs", en: "Egg allergy")
        case .soyAllergy: return AppCopy.t("Allergie au soja", en: "Soy allergy")
        }
    }

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

    @MainActor
    var description: String {
        switch self {
        case .none: return AppCopy.t("Je n'ai aucune restriction", en: "I have no restrictions")
        case .vegan: return AppCopy.t("Je ne mange aucun produit d'origine animale", en: "I don't eat any animal products")
        case .vegetarian: return AppCopy.t("Je ne mange pas de viande", en: "I don't eat meat")
        case .pescatarian: return AppCopy.t("Je mange du poisson mais pas de viande", en: "I eat fish but not meat")
        case .glutenFree: return AppCopy.t("Je dois éviter le gluten", en: "I need to avoid gluten")
        case .lactoseFree: return AppCopy.t("Je dois éviter le lactose", en: "I need to avoid lactose")
        case .peanutAllergy: return AppCopy.t("Allergie aux arachides", en: "Peanut allergy")
        case .shellfishAllergy: return AppCopy.t("Allergie aux fruits de mer ou crustacés", en: "Shellfish or crustacean allergy")
        case .religiousPreferences: return AppCopy.t("Préférences religieuses (halal, casher, etc.)", en: "Religious preferences (halal, kosher, etc.)")
        case .other: return AppCopy.t("Autre restriction alimentaire", en: "Other dietary restriction")
        case .halal: return AppCopy.t("Alimentation conforme aux règles halal", en: "Halal diet")
        case .kosher: return AppCopy.t("Alimentation conforme aux règles casher", en: "Kosher diet")
        case .nutAllergy: return AppCopy.t("Allergie aux noix et fruits à coque", en: "Tree nut allergy")
        case .eggAllergy: return AppCopy.t("Allergie aux œufs", en: "Egg allergy")
        case .soyAllergy: return AppCopy.t("Allergie au soja", en: "Soy allergy")
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
        case .snacking:
            return AppCopy.tSync(
                "Je grignote souvent entre les repas",
                en: "I often snack between meals"
            )
        case .dontKnowWhatToBuy:
            return AppCopy.tSync(
                "Je ne sais pas quoi acheter au supermarché",
                en: "I don't know what to buy at the store"
            )
        case .lackOfTime:
            return AppCopy.tSync(
                "Je n'ai pas le temps de cuisiner",
                en: "I don't have time to cook"
            )
        case .lackOfMotivation:
            return AppCopy.tSync(
                "Je manque de motivation pour bien manger",
                en: "I lack motivation to eat well"
            )
        case .emotionalEating:
            return AppCopy.tSync(
                "Je mange quand je suis stressé ou triste",
                en: "I eat when I'm stressed or sad"
            )
        case .socialPressure:
            return AppCopy.tSync(
                "Les sorties sociales me font manger mal",
                en: "Social outings make me eat poorly"
            )
        case .budget:
            return AppCopy.tSync(
                "Mon budget ne me permet pas de bien manger",
                en: "My budget doesn't let me eat well"
            )
        case .noObstacle:
            return AppCopy.tSync(
                "Je n'ai pas d'obstacle particulier",
                en: "I don't have a particular obstacle"
            )
        }
    }

    /// Titre UI onboarding (bilingue). rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .snacking: return OnboardingCopy.t("Grignotage", en: "Snacking")
        case .dontKnowWhatToBuy: return OnboardingCopy.t("Ne pas savoir quoi acheter", en: "Not knowing what to buy")
        case .lackOfTime: return OnboardingCopy.t("Manque de temps pour cuisiner", en: "No time to cook")
        case .lackOfMotivation: return OnboardingCopy.t("Manque de motivation", en: "Lack of motivation")
        case .emotionalEating: return OnboardingCopy.t("Manger par émotion", en: "Emotional eating")
        case .socialPressure: return OnboardingCopy.t("Pression sociale", en: "Social pressure")
        case .budget: return OnboardingCopy.t("Budget limité", en: "Limited budget")
        case .noObstacle: return OnboardingCopy.t("Aucun obstacle", en: "No obstacles")
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

    /// Titre UI onboarding (bilingue). rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .neverTried: return OnboardingCopy.t("Jamais essayé", en: "Never tried")
        case .triedMultiple: return OnboardingCopy.t("J'ai essayé plusieurs fois", en: "I've tried several times")
        case .currentlyTrying: return OnboardingCopy.t("J'essaie actuellement", en: "I'm trying right now")
        case .succeeded: return OnboardingCopy.t("J'ai réussi par le passé", en: "I've succeeded before")
        }
    }

    var description: String {
        switch self {
        case .neverTried:
            return AppCopy.tSync(
                "C'est la première fois que j'essaie",
                en: "This is the first time I'm trying"
            )
        case .triedMultiple:
            return AppCopy.tSync(
                "J'ai essayé plusieurs fois dans le passé",
                en: "I've tried several times in the past"
            )
        case .currentlyTrying:
            return AppCopy.tSync(
                "Je suis en train d'essayer actuellement",
                en: "I'm currently trying"
            )
        case .succeeded:
            return AppCopy.tSync(
                "J'ai réussi à atteindre mon objectif avant",
                en: "I've reached my goal before"
            )
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

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .excellent: return AppCopy.t("Excellente", en: "Excellent")
        case .veryGood: return AppCopy.t("Très bonne", en: "Very good")
        case .good: return AppCopy.t("Bonne", en: "Good")
        case .average: return AppCopy.t("Moyenne", en: "Average")
        case .poor: return AppCopy.t("Mauvaise", en: "Poor")
        case .veryPoor: return AppCopy.t("Très mauvaise", en: "Very poor")
        }
    }

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

    @MainActor
    var description: String {
        switch self {
        case .excellent: return AppCopy.t("Je bois 2-3L d'eau par jour facilement", en: "I easily drink 2–3 L of water a day")
        case .veryGood: return AppCopy.t("Je bois environ 1.5-2L par jour", en: "I drink about 1.5–2 L a day")
        case .good: return AppCopy.t("Je bois environ 1L par jour", en: "I drink about 1 L a day")
        case .average: return AppCopy.t("Je bois de l'eau mais pas régulièrement", en: "I drink water, but not regularly")
        case .poor: return AppCopy.t("Je bois rarement de l'eau", en: "I rarely drink water")
        case .veryPoor: return AppCopy.t("Je ne bois presque jamais d'eau", en: "I almost never drink water")
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

    /// Libellé UI — rawValue FR conservé pour la persistance.
    @MainActor
    var title: String {
        switch self {
        case .breakfast: return AppCopy.t("Au petit-déjeuner", en: "At breakfast")
        case .lunch: return AppCopy.t("Au déjeuner", en: "At lunch")
        case .dinner: return AppCopy.t("Au dîner", en: "At dinner")
        case .none: return AppCopy.t("Aucun", en: "None")
        }
    }

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
