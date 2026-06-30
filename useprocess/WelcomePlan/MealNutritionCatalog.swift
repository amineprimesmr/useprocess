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

    static func resolvedImageAsset(
        for meal: MealSuggestionContent,
        slot: MealTimeSlot? = nil,
        dayIndex: Int = 0,
        planType: NutritionPlanType = .threeMeals
    ) -> String {
        let resolvedSlot = slot ?? meal.timeSlot
        let featuredAsset = ProcessDebloatMealLibrary.featuredImageAsset
        let featuredName = ProcessDebloatMealLibrary.featuredChickenMeal.name

        if let catalogMeal = ProcessDebloatMealLibrary.catalogMeal(
            matchingName: meal.name,
            slot: resolvedSlot,
            planType: planType
        ),
           let asset = catalogMeal.imageAssetName,
           ProcessAssetCatalog.contains(asset) {
            return asset
        }

        if let inferred = inferImageAssetFromCatalog(for: meal),
           ProcessAssetCatalog.contains(inferred) {
            return inferred
        }

        for asset in imageAssetCandidates(for: meal) {
            guard ProcessAssetCatalog.contains(asset) else { continue }
            if asset == featuredAsset && meal.name != featuredName {
                continue
            }
            return asset
        }

        let slotMeal = ProcessDebloatMealLibrary.meal(
            for: resolvedSlot,
            dayIndex: dayIndex,
            planType: planType
        )
        if let slotAsset = slotMeal.imageAssetName,
           ProcessAssetCatalog.contains(slotAsset) {
            return slotAsset
        }

        for poolMeal in ProcessDebloatMealLibrary.mealsInPool(for: resolvedSlot, planType: planType) {
            if let asset = poolMeal.imageAssetName,
               ProcessAssetCatalog.contains(asset) {
                return asset
            }
        }

        if ProcessAssetCatalog.contains(featuredAsset) {
            return featuredAsset
        }
        return imageAssetCandidates(for: meal).first ?? featuredAsset
    }

    private static func imageAssetCandidates(for meal: MealSuggestionContent) -> [String] {
        guard let asset = meal.imageAssetName else { return [] }
        if let alias = legacyImageAliases[asset] {
            return [asset, alias]
        }
        return [asset]
    }

    private static let legacyImageAliases: [String: String] = [
        "meal_debloat_omelette_spinach_avocado": "epinardomelette",
        "meal_debloat_salmon_rice_zucchini": "meal_debloat_salmon_quinoa_salad",
        "meal_debloat_beef_sweet_potato_zucchini": "meal_debloat_beef_rice_peppers",
        "meal_debloat_steak_potato_zucchini": "meal_debloat_steak_salad_potato",
        "meal_debloat_chicken_carrot_potato": "meal_debloat_chicken_salad_bowl",
        "meal_debloat_turkey_rice_zucchini": "meal_debloat_turkey_broccoli_rice",
        "meal_debloat_turkey_potato_spinach": "meal_debloat_turkey_potato_salad",
        "meal_debloat_sweet_potato_avocado": "meal_debloat_omad_steak_sweet_potato",
        "meal_debloat_chicken_sweet_potato_zucchini": "meal_debloat_chicken_sweet_potato",
        "meal_debloat_chicken_sweet_potato_courgette": "meal_debloat_chicken_sweet_potato",
        "meal_debloat_chicken_sweet_potato_broccoli": "meal_debloat_chicken_sweet_potato"
    ]

    private static func inferImageAssetFromCatalog(for meal: MealSuggestionContent) -> String? {
        let haystack = mealSearchText(for: meal)
        var bestAsset: String?
        var bestScore = 0

        for catalogMeal in ProcessDebloatMealLibrary.allCatalogMeals {
            guard let asset = catalogMeal.imageAssetName else { continue }
            let score = catalogImageMatchScore(haystack: haystack, catalogMeal: catalogMeal)
            if score > bestScore {
                bestScore = score
                bestAsset = asset
            }
        }

        return bestScore >= 4 ? bestAsset : nil
    }

    private static func catalogImageMatchScore(
        haystack: String,
        catalogMeal: MealSuggestionContent
    ) -> Int {
        var score = 0
        for token in catalogImageTokens(for: catalogMeal) {
            if haystack.contains(token) {
                score += tokenMatchWeight(token)
            }
        }
        return score
    }

    private static func mealSearchText(for meal: MealSuggestionContent) -> String {
        let parts = [meal.name] + meal.items.map(\.name)
        return normalizeMealSearchText(parts.joined(separator: " "))
    }

    private static func catalogImageTokens(for meal: MealSuggestionContent) -> [String] {
        let parts = [meal.name] + meal.items.map(\.name)
        return tokenizeMealSearchText(parts.joined(separator: " "))
    }

    private static func normalizeMealSearchText(_ raw: String) -> String {
        raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
    }

    private static func tokenizeMealSearchText(_ raw: String) -> [String] {
        let normalized = normalizeMealSearchText(raw)
        let split = CharacterSet.alphanumerics.inverted
        return normalized
            .components(separatedBy: split)
            .filter { $0.count >= 3 }
    }

    private static func tokenMatchWeight(_ token: String) -> Int {
        switch token {
        case "poulet", "dinde", "saumon", "cabillaud", "lieu", "steak", "boeuf", "oeufs", "oeuf":
            return 4
        case "avocat", "banane", "kiwi", "ananas", "quinoa":
            return 3
        case "patate", "douce", "courgette", "zucchini", "brocoli", "carotte", "carottes", "riz":
            return 2
        case "coco", "yaourt", "jambon":
            return 2
        default:
            return token.count >= 5 ? 1 : 0
        }
    }

    private static let profilesByAsset: [String: MealNutritionProfile] = [
        "meal_debloat_chicken_sweet_potato": .init(
            calories: 530, proteinG: 48, carbsG: 40, fatsG: 16,
            fiberG: 8.0, sugarG: 8.0, sodiumMg: 198, potassiumMg: 1150
        ),
        "meal_debloat_eggs_banana_kiwi": .init(
            calories: 385, proteinG: 22, carbsG: 38, fatsG: 16,
            fiberG: 6.5, sugarG: 22, sodiumMg: 420, potassiumMg: 780
        ),
        "meal_debloat_eggs_avocado": .init(
            calories: 445, proteinG: 28, carbsG: 12, fatsG: 34,
            fiberG: 9.0, sugarG: 3.2, sodiumMg: 410, potassiumMg: 720
        ),
        "meal_debloat_eggs_tomato_salad": .init(
            calories: 320, proteinG: 18, carbsG: 14, fatsG: 22,
            fiberG: 5.5, sugarG: 6.0, sodiumMg: 380, potassiumMg: 680
        ),
        "meal_debloat_chicken_avocado_salad": .init(
            calories: 480, proteinG: 44, carbsG: 18, fatsG: 26,
            fiberG: 9.5, sugarG: 5.0, sodiumMg: 185, potassiumMg: 920
        ),
        "meal_debloat_salmon_quinoa_salad": .init(
            calories: 580, proteinG: 40, carbsG: 48, fatsG: 24,
            fiberG: 7.0, sugarG: 3.5, sodiumMg: 200, potassiumMg: 860
        ),
        "meal_debloat_turkey_potato_salad": .init(
            calories: 520, proteinG: 40, carbsG: 48, fatsG: 16,
            fiberG: 8.5, sugarG: 4.5, sodiumMg: 178, potassiumMg: 1080
        ),
        "meal_debloat_beef_rice_peppers": .init(
            calories: 555, proteinG: 44, carbsG: 50, fatsG: 18,
            fiberG: 6.8, sugarG: 6.5, sodiumMg: 192, potassiumMg: 780
        ),
        "meal_debloat_white_fish_green_salad": .init(
            calories: 420, proteinG: 42, carbsG: 18, fatsG: 14,
            fiberG: 7.5, sugarG: 4.0, sodiumMg: 165, potassiumMg: 820
        ),
        "meal_debloat_steak_salad_potato": .init(
            calories: 520, proteinG: 44, carbsG: 36, fatsG: 22,
            fiberG: 6.8, sugarG: 4.5, sodiumMg: 175, potassiumMg: 980
        ),
        "meal_debloat_chicken_salad_bowl": .init(
            calories: 465, proteinG: 46, carbsG: 16, fatsG: 24,
            fiberG: 8.0, sugarG: 5.5, sodiumMg: 168, potassiumMg: 900
        ),
        "meal_debloat_turkey_broccoli_rice": .init(
            calories: 495, proteinG: 42, carbsG: 46, fatsG: 12,
            fiberG: 7.2, sugarG: 3.8, sodiumMg: 170, potassiumMg: 820
        ),
        "meal_debloat_cod_carrot_salad": .init(
            calories: 465, proteinG: 40, carbsG: 28, fatsG: 14,
            fiberG: 7.8, sugarG: 8.0, sodiumMg: 168, potassiumMg: 920
        ),
        "meal_debloat_omad_steak_sweet_potato": .init(
            calories: 780, proteinG: 52, carbsG: 58, fatsG: 36,
            fiberG: 12.0, sugarG: 10.0, sodiumMg: 220, potassiumMg: 1400
        ),
        "meal_debloat_omad_chicken_quinoa_bowl": .init(
            calories: 720, proteinG: 50, carbsG: 62, fatsG: 28,
            fiberG: 11.0, sugarG: 6.0, sodiumMg: 210, potassiumMg: 1100
        ),
        "meal_debloat_coconut_banana": .init(
            calories: 340, proteinG: 14, carbsG: 52, fatsG: 8,
            fiberG: 5.0, sugarG: 38, sodiumMg: 120, potassiumMg: 920
        ),
        "vitacoco": .init(
            calories: 55, proteinG: 0.5, carbsG: 11, fatsG: 0,
            fiberG: 0, sugarG: 9, sodiumMg: 35, potassiumMg: 620
        ),
        "meal_debloat_pineapple_turkey_snack": .init(
            calories: 220, proteinG: 18, carbsG: 28, fatsG: 4,
            fiberG: 4.5, sugarG: 22, sodiumMg: 280, potassiumMg: 420
        ),
        // Legacy — repas retirés du catalogue mais asset encore présent
        "epinardomelette": .init(
            calories: 428, proteinG: 26, carbsG: 14, fatsG: 30,
            fiberG: 7.2, sugarG: 4.5, sodiumMg: 172, potassiumMg: 1020
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

    // MARK: - Balance K/Na (cartes repas)

    static func electrolyteBalance(for meal: MealSuggestionContent) -> MealElectrolyteBalance {
        MealElectrolyteBalance.from(profile: profile(for: meal))
    }

    static func isDebloatOptimized(_ profile: MealNutritionProfile) -> Bool {
        knaRatioScore(profile) >= 68
            && lowSodiumScore(profile) >= 68
            && potassiumScore(profile) >= 62
    }
}

struct MealElectrolyteBalance: Equatable {
    let potassiumShare: Double
    let sodiumShare: Double
    let ratio: Double
    let ratioLabel: String
    let isDebloatOptimized: Bool

    static func from(profile: MealNutritionProfile) -> MealElectrolyteBalance {
        let ratio = profile.potassiumSodiumRatio
        let potassiumShare = min(0.88, max(0.56, ratio / (ratio + 0.8)))
        let rounded = (ratio * 10).rounded() / 10
        let ratioLabel = rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f:1", rounded)
            : String(format: "%.1f:1", rounded)

        return MealElectrolyteBalance(
            potassiumShare: potassiumShare,
            sodiumShare: 1 - potassiumShare,
            ratio: ratio,
            ratioLabel: ratioLabel,
            isDebloatOptimized: MealNutritionCatalog.isDebloatOptimized(profile)
        )
    }
}

enum MealElectrolytePalette {
    static let potassium = Color(red: 0.24, green: 0.70, blue: 0.46)
    static let sodium = Color(red: 0.93, green: 0.52, blue: 0.30)
}

enum PlanMealSlotLabel {
    static func carouselTitle(for slot: MealTimeSlot, planType: NutritionPlanType = .threeMeals) -> String {
        if planType == .omad, slot == .lunch {
            return "Repas debloat"
        }
        switch slot {
        case .breakfast: return "Ce matin"
        case .lunch: return "Ce midi"
        case .dinner: return "Ce soir"
        case .snack: return "Collation"
        }
    }

    static func preferredSlot(
        in slots: [MealTimeSlot],
        planType: NutritionPlanType = .threeMeals,
        validated: Set<MealTimeSlot> = [],
        now: Date = Date()
    ) -> MealTimeSlot {
        let timeSlot = preferredSlotByTime(in: slots, planType: planType, now: now)
        guard validated.contains(timeSlot) else { return timeSlot }

        if let startIndex = slots.firstIndex(of: timeSlot) {
            for slot in slots.dropFirst(startIndex + 1) where !validated.contains(slot) {
                return slot
            }
        }
        return slots.first { !validated.contains($0) } ?? timeSlot
    }

    private static func preferredSlotByTime(
        in slots: [MealTimeSlot],
        planType: NutritionPlanType,
        now: Date
    ) -> MealTimeSlot {
        let hour = Calendar.current.component(.hour, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        let minutesSinceMidnight = hour * 60 + minute

        let ordered = slots.sorted { lhs, rhs in
            let l = PlanMealSchedule.timing(for: lhs, planType: planType)?.windowEndHour ?? 0
            let r = PlanMealSchedule.timing(for: rhs, planType: planType)?.windowEndHour ?? 0
            return l < r
        }

        if let active = ordered.last(where: { slot in
            guard let timing = PlanMealSchedule.timing(for: slot, planType: planType) else { return false }
            let start = timing.windowStartHour * 60 + timing.windowStartMinute
            return minutesSinceMidnight >= start
        }) {
            return active
        }

        return ordered.first ?? slots.last ?? .lunch
    }
}
