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
    let magnesiumMg: Double

    init(
        calories: Int,
        proteinG: Double,
        carbsG: Double,
        fatsG: Double,
        fiberG: Double,
        sugarG: Double,
        sodiumMg: Double,
        potassiumMg: Double,
        magnesiumMg: Double = 0
    ) {
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatsG = fatsG
        self.sugarG = sugarG
        self.fiberG = fiberG
        self.sodiumMg = sodiumMg
        self.potassiumMg = potassiumMg
        self.magnesiumMg = magnesiumMg
    }

    var potassiumSodiumRatio: Double {
        potassiumMg / max(sodiumMg, 1)
    }
}

struct MealDebloatAssessment: Equatable {
    let score: Int
    let electrolyteScore: Int
    let digestiveScore: Int
    let foodQualityScore: Int
    let balance: MealElectrolyteBalance
    let label: String
    let summary: String
    let caution: String?
    let isEstimated: Bool

    var scoreText: String {
        isEstimated ? "≈\(score)" : "\(score)"
    }
}

enum MealNutritionCatalog {
    static func profile(for meal: MealSuggestionContent) -> MealNutritionProfile {
        for asset in imageAssetCandidates(for: meal) {
            if let known = profilesByAsset[asset] {
                return enrichMagnesiumIfNeeded(known, meal: meal)
            }
        }
        return estimate(from: meal)
    }

    private static func enrichMagnesiumIfNeeded(
        _ profile: MealNutritionProfile,
        meal: MealSuggestionContent
    ) -> MealNutritionProfile {
        guard profile.magnesiumMg <= 0 else { return profile }
        let mg = matchedFoods(for: meal).reduce(0.0) { partial, food in
            partial + (food.magnesiumMgPer100g ?? 0) * 0.45
        }
        return MealNutritionProfile(
            calories: profile.calories,
            proteinG: profile.proteinG,
            carbsG: profile.carbsG,
            fatsG: profile.fatsG,
            fiberG: profile.fiberG,
            sugarG: profile.sugarG,
            sodiumMg: profile.sodiumMg,
            potassiumMg: profile.potassiumMg,
            magnesiumMg: max(40, mg)
        )
    }

    /// Score Debloat global : équilibre hydrique 50 %, confort digestif 30 %,
    /// qualité nutritionnelle 20 %. Il s'agit d'une estimation, pas d'un diagnostic.
    @MainActor
    static func debloatAssessment(for meal: MealSuggestionContent) -> MealDebloatAssessment {
        let nutrition = profile(for: meal)
        let ratio = potassiumSodiumRatioScore(nutrition)
        let sodium = lowSodiumScore(nutrition)
        let potassium = potassiumScore(nutrition)
        let magnesium = magnesiumScore(nutrition)
        // Visage dégonflé : K + Na bas dominent, Mg en soutien (~18 %).
        let electrolyte = ratio * 0.24 + sodium * 0.30 + potassium * 0.28 + magnesium * 0.18

        let tolerance = digestiveToleranceScore(for: meal)
        let fiber = fiberComfortScore(nutrition)
        let fats = fatComfortScore(nutrition)
        let portion = portionComfortScore(nutrition)
        let digestive = tolerance.score * 0.38 + fiber * 0.24 + fats * 0.23 + portion * 0.15

        let quality = foodQualityScore(for: meal, profile: nutrition)
        let overall = Int((electrolyte * 0.50 + digestive * 0.30 + quality * 0.20).rounded())
        let clamped = min(100, max(0, overall))
        let label = scoreLabel(clamped)
        let balance = MealElectrolyteBalance.from(profile: nutrition)
        let summary = summary(
            score: clamped,
            electrolyte: Int(electrolyte.rounded()),
            digestive: Int(digestive.rounded()),
            balance: balance
        )

        return MealDebloatAssessment(
            score: clamped,
            electrolyteScore: Int(electrolyte.rounded()),
            digestiveScore: Int(digestive.rounded()),
            foodQualityScore: Int(quality.rounded()),
            balance: balance,
            label: label,
            summary: summary,
            caution: tolerance.caution,
            // Même les profils catalogue reposent sur des quantités nutritionnelles
            // moyennes : la marque, la cuisson et le sel ajouté font varier le résultat.
            isEstimated: true
        )
    }

    /// 6 pétales — lecture scientifique du repas, sans faire des calories le score.
    @MainActor
    static func debloatChartSegments(for profile: MealNutritionProfile) -> [MealChartSegment] {
        [
            .init(id: "kna", name: AppCopy.t("Équilibre K/Na", en: "K/Na balance"), percentage: potassiumSodiumRatioScore(profile)),
            .init(id: "potassium", name: AppCopy.t("Potassium", en: "Potassium"), percentage: potassiumScore(profile)),
            .init(id: "sodium", name: AppCopy.t("Sodium bas", en: "Low sodium"), percentage: lowSodiumScore(profile)),
            .init(id: "magnesium", name: AppCopy.t("Magnésium", en: "Magnesium"), percentage: magnesiumScore(profile)),
            .init(id: "fiber", name: AppCopy.t("Fibres tolérées", en: "Tolerated fiber"), percentage: fiberComfortScore(profile)),
            .init(id: "portion", name: AppCopy.t("Portion digeste", en: "Digestible portion"), percentage: portionComfortScore(profile))
        ]
    }

    /// Matching repas → aliments catalogue (noms normalisés).
    static func matchedFoods(for meal: MealSuggestionContent) -> [DebloatFoodItem] {
        meal.foodItems.compactMap { DebloatFoodCatalog.item(matchingName: $0.name) }
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
            calories: 430, proteinG: 28, carbsG: 38, fatsG: 20,
            fiberG: 6.5, sugarG: 22, sodiumMg: 210, potassiumMg: 920,
            magnesiumMg: 55
        ),
        "meal_debloat_yogurt_blueberry": .init(
            calories: 280, proteinG: 14, carbsG: 36, fatsG: 9,
            fiberG: 4.0, sugarG: 28, sodiumMg: 95, potassiumMg: 520,
            magnesiumMg: 50
        ),
        "meal_debloat_salmon_avocado_bowl": .init(
            calories: 420, proteinG: 32, carbsG: 12, fatsG: 28,
            fiberG: 7.5, sugarG: 3.0, sodiumMg: 140, potassiumMg: 980,
            magnesiumMg: 70
        ),
        "meal_debloat_eggs_avocado": .init(
            calories: 405, proteinG: 27, carbsG: 12, fatsG: 26,
            fiberG: 7.0, sugarG: 3.2, sodiumMg: 220, potassiumMg: 720
        ),
        "meal_debloat_eggs_tomato_salad": .init(
            calories: 320, proteinG: 18, carbsG: 14, fatsG: 22,
            fiberG: 5.5, sugarG: 6.0, sodiumMg: 190, potassiumMg: 680
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
        "meal_debloat_sweet_potato_meat_avocado": .init(
            calories: 620, proteinG: 38, carbsG: 52, fatsG: 28,
            fiberG: 14.0, sugarG: 14.0, sodiumMg: 165, potassiumMg: 1450
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
            calories: 690, proteinG: 52, carbsG: 58, fatsG: 27,
            fiberG: 10.0, sugarG: 10.0, sodiumMg: 220, potassiumMg: 1250
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
            fiberG: 4.5, sugarG: 22, sodiumMg: 95, potassiumMg: 520
        ),
        // Legacy — repas retirés du catalogue mais asset encore présent
        "epinardomelette": .init(
            calories: 428, proteinG: 26, carbsG: 14, fatsG: 30,
            fiberG: 7.2, sugarG: 4.5, sodiumMg: 172, potassiumMg: 1020
        )
    ]

    // MARK: - Scores debloat (0…100)

    /// Le ratio est utile, mais ne remplace jamais les quantités absolues.
    /// Cible population OMS : environ 3510 mg K / <2000 mg Na par jour.
    private static func potassiumSodiumRatioScore(_ profile: MealNutritionProfile) -> Double {
        let ratio = profile.potassiumSodiumRatio
        if ratio >= 2.0 { return 100 }
        if ratio >= 1.0 { return 58 + (ratio - 1.0) * 42 }
        return 12 + ratio * 46
    }

    /// Repère par repas principal : environ 900–1100 mg de potassium.
    private static func potassiumScore(_ profile: MealNutritionProfile) -> Double {
        if profile.potassiumMg >= 950 { return 100 }
        if profile.potassiumMg >= 500 {
            return 55 + ((profile.potassiumMg - 500) / 450) * 45
        }
        return clampScore((profile.potassiumMg / 500) * 55, minimum: 8)
    }

    /// Repère par repas principal : idéalement <=450 mg, pénalité progressive.
    private static func lowSodiumScore(_ profile: MealNutritionProfile) -> Double {
        if profile.sodiumMg <= 450 { return 100 }
        if profile.sodiumMg >= 1_100 { return 10 }
        return 100 - ((profile.sodiumMg - 450) / 650) * 90
    }

    /// Repère par repas : ~80–150 mg Mg soutient l’équilibre hydrique.
    private static func magnesiumScore(_ profile: MealNutritionProfile) -> Double {
        if profile.magnesiumMg >= 140 { return 100 }
        if profile.magnesiumMg >= 70 {
            return 55 + ((profile.magnesiumMg - 70) / 70) * 45
        }
        return clampScore((profile.magnesiumMg / 70) * 55, minimum: 8)
    }

    /// Courbe en cloche : trop peu aide peu le transit, trop d'un coup peut fermenter.
    private static func fiberComfortScore(_ profile: MealNutritionProfile) -> Double {
        switch profile.fiberG {
        case 4...9: return 100
        case 0..<4: return 45 + (profile.fiberG / 4) * 55
        case 9..<13: return 100 - ((profile.fiberG - 9) / 4) * 28
        default: return max(38, 72 - (profile.fiberG - 13) * 5)
        }
    }

    /// Les lipides sont essentiels ; seule une charge très élevée est pénalisée ici
    /// car elle peut accentuer lourdeur et ballonnement chez certaines personnes.
    private static func fatComfortScore(_ profile: MealNutritionProfile) -> Double {
        let fatCalories = profile.fatsG * 9
        let share = fatCalories / Double(max(profile.calories, 1))
        if share <= 0.34 { return 100 }
        if share <= 0.45 { return 100 - ((share - 0.34) / 0.11) * 25 }
        if share <= 0.58 { return 75 - ((share - 0.45) / 0.13) * 30 }
        return 38
    }

    /// Les calories ne définissent pas le debloat ; elles servent uniquement à
    /// repérer une portion très volumineuse susceptible de distendre l'estomac.
    private static func portionComfortScore(_ profile: MealNutritionProfile) -> Double {
        if profile.calories <= 620 { return 100 }
        if profile.calories <= 800 {
            return 100 - (Double(profile.calories - 620) / 180) * 22
        }
        return max(55, 78 - Double(profile.calories - 800) / 12)
    }

    private static func clampScore(_ value: Double, minimum: Double) -> Double {
        min(100, max(minimum, value))
    }

    @MainActor
    private static func digestiveToleranceScore(
        for meal: MealSuggestionContent
    ) -> (score: Double, caution: String?) {
        let itemLines = meal.items.map { "\($0.name) \($0.quantity)" }
        let text = normalizeMealSearchText(([meal.name] + itemLines).joined(separator: " "))
        var penalty = 0.0
        var triggers: [String] = []

        func flag(_ tokens: [String], penalty value: Double, labelFR: String, labelEN: String) {
            guard tokens.contains(where: { text.contains($0) }) else { return }
            penalty += value
            let label = AppCopy.t(labelFR, en: labelEN)
            if !triggers.contains(label) { triggers.append(label) }
        }

        flag(["oignon", "echalote"], penalty: 20, labelFR: "oignon", labelEN: "onion")
        if text.contains("ail"),
           !text.contains("huile infusee a l'ail"),
           !text.contains("huile infusee a l ail") {
            penalty += 12
            let label = AppCopy.t("ail", en: "garlic")
            if !triggers.contains(label) { triggers.append(label) }
        }
        flag(["haricot sec", "lentille", "pois chiche"], penalty: 18, labelFR: "légumineuses", labelEN: "legumes")
        flag(["yaourt", "lait", "creme"], penalty: 12, labelFR: "lactose possible", labelEN: "possible lactose")
        flag(["brocoli", "chou fleur"], penalty: 8, labelFR: "crucifères", labelEN: "crucifers")
        flag(["avocat"], penalty: 6, labelFR: "avocat", labelEN: "avocado")
        flag(["banane bien mure"], penalty: 7, labelFR: "banane très mûre", labelEN: "very ripe banana")
        flag(["sorbitol", "xylitol", "erythritol", "maltitol"], penalty: 25, labelFR: "polyols", labelEN: "polyols")

        let score = max(35, 100 - penalty)
        let joined = triggers.prefix(3).joined(separator: ", ")
        let caution: String? = triggers.isEmpty
            ? nil
            : AppCopy.t(
                "Tolérance individuelle à vérifier : \(joined).",
                en: "Individual tolerance to check: \(joined)."
            )
        return (score, caution)
    }

    private static func foodQualityScore(
        for meal: MealSuggestionContent,
        profile: MealNutritionProfile
    ) -> Double {
        let text = normalizeMealSearchText(
            ([meal.name] + meal.items.map(\.name)).joined(separator: " ")
        )
        var score = 96.0

        if text.contains("jambon") || text.contains("charcuterie") { score -= 28 }
        if text.contains("sauce industrielle") || text.contains("frit") { score -= 22 }
        if text.contains("nectar") || text.contains("sirop") { score -= 18 }
        if profile.proteinG < 15, meal.timeSlot != .snack { score -= 8 }
        if profile.sugarG > 25 { score -= 6 }
        if meal.items.contains(where: { normalizeMealSearchText($0.role).contains("legume") }) {
            score += 4
        }
        return min(100, max(30, score))
    }

    @MainActor
    private static func scoreLabel(_ score: Int) -> String {
        switch score {
        case 88...100: return AppCopy.t("Excellent équilibre", en: "Excellent balance")
        case 76..<88: return AppCopy.t("Très bon choix", en: "Very good choice")
        case 64..<76: return AppCopy.t("Équilibre correct", en: "Solid balance")
        case 50..<64: return AppCopy.t("À ajuster", en: "Needs adjusting")
        default: return AppCopy.t("Peu adapté", en: "Poor fit")
        }
    }

    @MainActor
    private static func summary(
        score: Int,
        electrolyte: Int,
        digestive: Int,
        balance: MealElectrolyteBalance
    ) -> String {
        if electrolyte >= 88, digestive >= 78 {
            return AppCopy.t(
                "Très bon équilibre K/Na et charge digestive maîtrisée.",
                en: "Very good K/Na balance and controlled digestive load."
            )
        }
        if electrolyte < digestive {
            return AppCopy.t(
                "Électrolytes à améliorer, surtout sodium et potassium.",
                en: "Electrolytes to improve, especially sodium and potassium."
            )
        }
        if digestive < 70 {
            return AppCopy.t(
                "Équilibre minéral correct, mais tolérance digestive à surveiller.",
                en: "Mineral balance is fine, but watch digestive tolerance."
            )
        }
        return score >= 76
            ? AppCopy.t(
                "Repas cohérent pour limiter rétention et lourdeur.",
                en: "A coherent meal to limit retention and heaviness."
            )
            : AppCopy.t(
                "Quelques ajustements peuvent améliorer le confort après le repas.",
                en: "A few tweaks can improve comfort after the meal."
            )
    }

    private static func estimate(from meal: MealSuggestionContent) -> MealNutritionProfile {
        var protein = 0.0
        var carbs = 0.0
        var fats = 0.0
        var potassium = 0.0
        var sodium = 200.0
        var magnesium = 0.0

        for item in meal.foodItems {
            let role = item.role.lowercased()

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

            if let food = DebloatFoodCatalog.item(matchingName: item.name) {
                potassium += (food.potassiumMgPer100g ?? 0) * 0.85
                sodium += (food.sodiumMgPer100g ?? 0) * 0.35
                magnesium += (food.magnesiumMgPer100g ?? 0) * 0.55
            }
        }

        let calories = Int(protein * 4 + carbs * 4 + fats * 9)
        return MealNutritionProfile(
            calories: max(calories, 420),
            proteinG: max(protein, 30),
            carbsG: max(carbs, 30),
            fatsG: max(fats, 10),
            fiberG: 6.5,
            sugarG: 5.0,
            sodiumMg: min(900, max(120, sodium)),
            potassiumMg: max(potassium, 650),
            magnesiumMg: max(magnesium, 45)
        )
    }

    // MARK: - Balance K/Na (cartes repas)

    static func electrolyteBalance(for meal: MealSuggestionContent) -> MealElectrolyteBalance {
        MealElectrolyteBalance.from(profile: profile(for: meal))
    }

    static func isDebloatOptimized(_ profile: MealNutritionProfile) -> Bool {
        potassiumSodiumRatioScore(profile) >= 68
            && lowSodiumScore(profile) >= 68
            && potassiumScore(profile) >= 62
            && magnesiumScore(profile) >= 50
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
