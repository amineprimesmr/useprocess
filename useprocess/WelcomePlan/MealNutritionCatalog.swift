import SwiftUI

struct MealChartSegment: Identifiable, Hashable {
    let id: String
    let name: String
    /// Pourcentage affiche dans la fleur du repas.
    let percentage: Double
}

struct MealNutritionProfile: Hashable {
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatsG: Double
    let fiberG: Double
    let sugarG: Double
    let sodiumMg: Double
    let potassiumMg: Double

    var potassiumSodiumRatio: Double {
        potassiumMg / max(sodiumMg, 1)
    }
}

enum MealNutritionCatalog {
    static func profile(for meal: MealSuggestionContent) -> MealNutritionProfile {
        for asset in imageAssetCandidates(for: meal) {
            if let known = profilesByAsset[asset] {
                return known
            }
        }
        return estimate(from: meal)
    }

    /// 6 pétales — indicateurs debloat 80/20 (scores 0…100).
    static func debloatChartSegments(for profile: MealNutritionProfile) -> [MealChartSegment] {
        [
            .init(id: "kna", name: "K / Na", percentage: knaRatioScore(profile)),
            .init(id: "potassium", name: "Potassium", percentage: potassiumScore(profile)),
            .init(id: "sodium", name: "Sodium bas", percentage: lowSodiumScore(profile)),
            .init(id: "fiber", name: "Fibres", percentage: fiberScore(profile)),
            .init(id: "protein", name: "Protéines", percentage: proteinScore(profile)),
            .init(id: "sugar", name: "Sucres", percentage: lowSugarScore(profile))
        ]
    }

    /// Pétales ingrédients — proche de la maquette: aliment + part visuelle du repas.
    static func ingredientChartSegments(for meal: MealSuggestionContent) -> [MealChartSegment] {
        let weightedItems = meal.items.map { item in
            (item: item, weight: visualIngredientWeight(for: item))
        }
        let total = weightedItems.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return [] }

        return weightedItems.map { item, weight in
            MealChartSegment(
                id: item.id,
                name: shortIngredientName(item.name),
                percentage: (weight / total) * 100
            )
        }
    }

    static func resolvedImageAsset(for meal: MealSuggestionContent) -> String {
        let candidates = imageAssetCandidates(for: meal)
        for asset in candidates {
            if availableImageAssets.contains(asset) {
                return asset
            }
        }
        return ProcessDebloatMealLibrary.featuredImageAsset
    }

    private static func imageAssetCandidates(for meal: MealSuggestionContent) -> [String] {
        guard let asset = meal.imageAssetName else { return [] }
        if let alias = legacyImageAliases[asset] {
            return [asset, alias]
        }
        return [asset]
    }

    private static let legacyImageAliases: [String: String] = [
        "meal_debloat_omelette_spinach_avocado": "epinardomelette"
    ]

    private static let availableImageAssets: Set<String> = [
        ProcessDebloatMealLibrary.featuredImageAsset,
        "epinardomelette"
    ]

    private static let profilesByAsset: [String: MealNutritionProfile] = [
        ProcessDebloatMealLibrary.featuredImageAsset: .init(
            calories: 537,
            proteinG: 48,
            carbsG: 42,
            fatsG: 16,
            fiberG: 7.5,
            sugarG: 8.2,
            sodiumMg: 198,
            potassiumMg: 1180
        ),
        "meal_debloat_salmon_rice_zucchini": .init(
            calories: 612,
            proteinG: 42,
            carbsG: 58,
            fatsG: 22,
            fiberG: 6.2,
            sugarG: 4.1,
            sodiumMg: 210,
            potassiumMg: 820
        ),
        "meal_debloat_eggs_sweet_potato": .init(
            calories: 498,
            proteinG: 32,
            carbsG: 36,
            fatsG: 26,
            fiberG: 8.0,
            sugarG: 5.5,
            sodiumMg: 185,
            potassiumMg: 960
        ),
        "meal_debloat_cod_asparagus_potato": .init(
            calories: 465,
            proteinG: 44,
            carbsG: 38,
            fatsG: 12,
            fiberG: 6.8,
            sugarG: 3.8,
            sodiumMg: 165,
            potassiumMg: 890
        ),
        "epinardomelette": .init(
            calories: 428,
            proteinG: 26,
            carbsG: 14,
            fatsG: 30,
            fiberG: 7.2,
            sugarG: 4.5,
            sodiumMg: 172,
            potassiumMg: 1020
        )
    ]

    // MARK: - Scores debloat (0…100)

    /// Ratio K/Na — levier #1 rétention d'eau (cible alimentaire ~2:1 ou plus).
    private static func knaRatioScore(_ profile: MealNutritionProfile) -> Double {
        let ratio = profile.potassiumSodiumRatio
        return clampScore((ratio / 2.5) * 100, minimum: 10)
    }

    /// Potassium par repas — cible ~800 mg+ (3400 mg/jour répartis).
    private static func potassiumScore(_ profile: MealNutritionProfile) -> Double {
        clampScore((profile.potassiumMg / 850) * 100, minimum: 8)
    }

    /// Sodium bas — cible <500 mg/repas (<2300 mg/jour).
    private static func lowSodiumScore(_ profile: MealNutritionProfile) -> Double {
        if profile.sodiumMg <= 350 { return 100 }
        if profile.sodiumMg >= 900 { return 12 }
        return clampScore(100 - ((profile.sodiumMg - 350) / 550) * 88, minimum: 12)
    }

    /// Fibres — motilité intestinale, cible ~8 g/repas.
    private static func fiberScore(_ profile: MealNutritionProfile) -> Double {
        clampScore((profile.fiberG / 8) * 100, minimum: 8)
    }

    /// Protéines — satiété, repas dense sans ultra-transformé.
    private static func proteinScore(_ profile: MealNutritionProfile) -> Double {
        clampScore((profile.proteinG / 35) * 100, minimum: 8)
    }

    /// Sucres bas — moins de fermentation / pics glycémiques.
    private static func lowSugarScore(_ profile: MealNutritionProfile) -> Double {
        if profile.sugarG <= 5 { return 100 }
        if profile.sugarG >= 22 { return 15 }
        return clampScore(100 - ((profile.sugarG - 5) / 17) * 85, minimum: 15)
    }

    private static func clampScore(_ value: Double, minimum: Double) -> Double {
        min(100, max(minimum, value))
    }

    private static func visualIngredientWeight(for item: MealSuggestionItem) -> Double {
        let role = item.role.lowercased()
        if role.contains("prot") { return 40 }
        if role.contains("gluc") { return 30 }
        if role.contains("lég") || role.contains("leg") { return 20 }
        if role.contains("gras") { return 10 }
        return 12
    }

    private static func shortIngredientName(_ name: String) -> String {
        let lowered = name.lowercased()
        if lowered.contains("poulet") { return "Poulet" }
        if lowered.contains("patate") { return "Patate douce" }
        if lowered.contains("courgette") { return "Courgettes" }
        if lowered.contains("huile") { return "Huile d'olive" }
        if lowered.contains("saumon") { return "Saumon" }
        if lowered.contains("riz") { return "Riz" }
        if lowered.contains("oeuf") || lowered.contains("œuf") { return "Oeufs" }
        if lowered.contains("avocat") { return "Avocat" }
        return name
    }

    private static func estimate(from meal: MealSuggestionContent) -> MealNutritionProfile {
        var protein = 0.0
        var carbs = 0.0
        var fats = 0.0
        var potassium = 0.0

        for item in meal.items {
            let role = item.role.lowercased()
            let name = item.name.lowercased()

            switch role {
            case let r where r.contains("prot"):
                protein += 18
            case let r where r.contains("gluc"):
                carbs += 28
            case let r where r.contains("gras"):
                fats += 10
            case let r where r.contains("lég") || r.contains("leg"):
                carbs += 6
                protein += 2
                potassium += 180
            default:
                carbs += 8
            }

            if name.contains("patate") || name.contains("pomme de terre") { potassium += 320 }
            if name.contains("avocat") { potassium += 240 }
            if name.contains("épinard") || name.contains("epinard") { potassium += 260 }
            if name.contains("banane") { potassium += 220 }
            if name.contains("courgette") { potassium += 120 }
        }

        let calories = Int(protein * 4 + carbs * 4 + fats * 9)
        return MealNutritionProfile(
            calories: max(calories, 420),
            proteinG: max(protein, 30),
            carbsG: max(carbs, 30),
            fatsG: max(fats, 10),
            fiberG: 6.5,
            sugarG: 5.0,
            sodiumMg: 200,
            potassiumMg: max(potassium, 650)
        )
    }
}

enum PlanMealSlotLabel {
    static func carouselTitle(for slot: MealTimeSlot) -> String {
        switch slot {
        case .breakfast: return "Ce matin"
        case .lunch: return "Ce midi"
        case .dinner: return "Ce soir"
        case .snack: return "Collation"
        }
    }

    static func preferredSlot(
        in slots: [MealTimeSlot],
        validated: Set<MealTimeSlot> = [],
        now: Date = Date()
    ) -> MealTimeSlot {
        let timeSlot = preferredSlotByTime(in: slots, now: now)
        guard validated.contains(timeSlot) else { return timeSlot }

        if let startIndex = slots.firstIndex(of: timeSlot) {
            for slot in slots.dropFirst(startIndex + 1) where !validated.contains(slot) {
                return slot
            }
        }
        return slots.first { !validated.contains($0) } ?? timeSlot
    }

    private static func preferredSlotByTime(in slots: [MealTimeSlot], now: Date) -> MealTimeSlot {
        let hour = Calendar.current.component(.hour, from: now)
        if slots.contains(.dinner), hour >= 17 { return .dinner }
        if slots.contains(.lunch), hour >= 11, hour < 17 { return .lunch }
        if slots.contains(.breakfast), hour < 11 { return .breakfast }
        if slots.contains(.snack), hour >= 15, hour < 17 { return .snack }
        return slots.last ?? .lunch
    }
}
