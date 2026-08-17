import Foundation

/// Estimation nutritionnelle réaliste à partir des ingrédients scannés / saisis.
enum MealNutritionEstimator {

    struct IngredientBreakdown {
        var grams: Double
        var proteinG: Double
        var carbsG: Double
        var fatsG: Double
        var fiberG: Double
        var sugarG: Double
        var sodiumMg: Double
        var potassiumMg: Double
        var magnesiumMg: Double
        var qualityPenalty: Double
        var digestivePenalty: Double
    }

    // MARK: - Public

    static func profile(for meal: MealSuggestionContent) -> MealNutritionProfile {
        let breakdowns = meal.foodItems.map { analyze(item: $0) }

        let protein = breakdowns.reduce(0) { $0 + $1.proteinG }
        let carbs = breakdowns.reduce(0) { $0 + $1.carbsG }
        let fats = breakdowns.reduce(0) { $0 + $1.fatsG }
        let fiber = breakdowns.reduce(0) { $0 + $1.fiberG }
        let sugar = breakdowns.reduce(0) { $0 + $1.sugarG }
        let sodium = breakdowns.reduce(0) { $0 + $1.sodiumMg }
        let potassium = breakdowns.reduce(0) { $0 + $1.potassiumMg }
        let magnesium = breakdowns.reduce(0) { $0 + $1.magnesiumMg }
        let calories = Int(protein * 4 + carbs * 4 + fats * 9)

        return MealNutritionProfile(
            calories: max(calories, 40),
            proteinG: max(0, protein),
            carbsG: max(0, carbs),
            fatsG: max(0, fats),
            fiberG: max(0, fiber),
            sugarG: max(0, sugar),
            sodiumMg: max(0, sodium),
            potassiumMg: max(0, potassium),
            magnesiumMg: max(0, magnesium)
        )
    }

    static func totalQualityPenalty(for meal: MealSuggestionContent) -> Double {
        meal.foodItems.reduce(0) { $0 + analyze(item: $1).qualityPenalty }
    }

    static func totalDigestivePenalty(for meal: MealSuggestionContent) -> Double {
        meal.foodItems.reduce(0) { $0 + analyze(item: $1).digestivePenalty }
    }

    // MARK: - Ingredient analysis

    private static func analyze(item: MealSuggestionItem) -> IngredientBreakdown {
        let grams = parseGrams(quantity: item.quantity, name: item.name)
        let normalizedName = normalize(item.name)
        let normalizedRole = normalize(item.role)

        if let catalog = DebloatFoodCatalog.item(matchingName: item.name) {
            return breakdown(from: catalog, grams: grams, role: normalizedRole)
        }

        if let template = keywordTemplate(for: normalizedName) {
            return scaled(template, grams: grams, name: normalizedName, role: normalizedRole)
        }

        return roleFallback(grams: grams, role: normalizedRole, name: normalizedName)
    }

    private static func breakdown(
        from food: DebloatFoodItem,
        grams: Double,
        role: String
    ) -> IngredientBreakdown {
        let factor = grams / 100.0
        let sodiumPer100 = food.sodiumMgPer100g ?? defaultSodium(for: food.tier)
        let potassiumPer100 = food.potassiumMgPer100g ?? defaultPotassium(for: food.tier, role: role)
        let magnesiumPer100 = food.magnesiumMgPer100g ?? defaultMagnesium(for: food.tier)

        let macros = macroTemplate(for: food, grams: grams, role: role)

        let qualityPenalty = tierQualityPenalty(food.tier) + keywordQualityPenalty(in: normalize(food.name))
        let digestivePenalty = tierDigestivePenalty(food.tier, name: food.name)
            + keywordDigestivePenalty(in: normalize(food.name))

        return IngredientBreakdown(
            grams: grams,
            proteinG: macros.protein,
            carbsG: macros.carbs,
            fatsG: macros.fats,
            fiberG: macros.fiber,
            sugarG: macros.sugar,
            sodiumMg: sodiumPer100 * factor,
            potassiumMg: potassiumPer100 * factor,
            magnesiumMg: magnesiumPer100 * factor,
            qualityPenalty: qualityPenalty,
            digestivePenalty: digestivePenalty
        )
    }

    // MARK: - Quantity parsing

    static func parseGrams(quantity: String, name: String) -> Double {
        let qty = quantity
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if qty.isEmpty || qty == "—" || qty == "-" || qty == "n/a" {
            return defaultPortionGrams(for: name)
        }

        if let match = firstRegexMatch(in: qty, pattern: #"(\d+(?:[.,]\d+)?)\s*kg"#) {
            return (parseNumber(match) ?? 0) * 1000
        }
        if let match = firstRegexMatch(in: qty, pattern: #"(\d+(?:[.,]\d+)?)\s*g\b"#) {
            return parseNumber(match) ?? defaultPortionGrams(for: name)
        }
        if let match = firstRegexMatch(in: qty, pattern: #"(\d+(?:[.,]\d+)?)\s*ml"#) {
            return parseNumber(match) ?? defaultPortionGrams(for: name)
        }
        if let match = firstRegexMatch(in: qty, pattern: #"(\d+(?:[.,]\d+)?)\s*cl"#) {
            return (parseNumber(match) ?? 0) * 10
        }
        if qty.contains("c. a soupe") || qty.contains("c a soupe") || qty.contains("cs")
            || qty.contains("tbsp") || qty.contains("tablespoon") {
            if let match = firstRegexMatch(in: qty, pattern: #"(\d+(?:[.,]\d+)?)"#) {
                return (parseNumber(match) ?? 1) * 15
            }
            return 15
        }
        if qty.contains("c. a cafe") || qty.contains("c a cafe") || qty.contains("cc")
            || qty.contains("tsp") || qty.contains("teaspoon") {
            if let match = firstRegexMatch(in: qty, pattern: #"(\d+(?:[.,]\d+)?)"#) {
                return (parseNumber(match) ?? 1) * 5
            }
            return 5
        }
        if let match = firstRegexMatch(in: qty, pattern: #"^(\d+(?:[.,]\d+)?)$"#) {
            let count = parseNumber(match) ?? 1
            return count * defaultUnitGrams(for: name)
        }

        return defaultPortionGrams(for: name)
    }

    private static func defaultPortionGrams(for name: String) -> Double {
        let n = normalize(name)
        if n.contains("pizza") { return 180 }
        if n.contains("burger") || n.contains("hamburger") { return 220 }
        if n.contains("sandwich") { return 160 }
        if n.contains("frites") || n.contains("fries") || n.contains("frite") { return 150 }
        if n.contains("sauce") { return 30 }
        if n.contains("fromage") || n.contains("cheese") { return 40 }
        if n.contains("creme") || n.contains("cream") { return 30 }
        if n.contains("salade") || n.contains("salad") { return 120 }
        return 120
    }

    private static func defaultUnitGrams(for name: String) -> Double {
        let n = normalize(name)
        if n.contains("oeuf") || n.contains("egg") { return 55 }
        if n.contains("tranche") || n.contains("slice") { return 35 }
        if n.contains("banane") || n.contains("banana") { return 120 }
        return 80
    }

    // MARK: - Keyword templates (per 100 g)

    private struct MacroTemplate {
        var protein: Double
        var carbs: Double
        var fats: Double
        var fiber: Double
        var sugar: Double
        var sodium: Double
        var potassium: Double
        var magnesium: Double
        var qualityPenalty: Double
        var digestivePenalty: Double
    }

    private static func keywordTemplate(for normalizedName: String) -> MacroTemplate? {
        let rules: [(tokens: [String], template: MacroTemplate)] = [
            (["pizza"], .init(protein: 12, carbs: 28, fats: 11, fiber: 2, sugar: 4, sodium: 680, potassium: 140, magnesium: 18, qualityPenalty: 32, digestivePenalty: 8)),
            (["burger", "hamburger", "cheeseburger"], .init(protein: 14, carbs: 22, fats: 16, fiber: 1.5, sugar: 5, sodium: 820, potassium: 160, magnesium: 20, qualityPenalty: 34, digestivePenalty: 10)),
            (["frites", "frite", "fries", "frit", "fried", "nuggets", "beignet"], .init(protein: 4, carbs: 32, fats: 17, fiber: 3, sugar: 0.5, sodium: 520, potassium: 480, magnesium: 22, qualityPenalty: 30, digestivePenalty: 12)),
            (["kebab", "tacos", "burrito", "shawarma"], .init(protein: 13, carbs: 24, fats: 14, fiber: 2, sugar: 3, sodium: 780, potassium: 180, magnesium: 18, qualityPenalty: 30, digestivePenalty: 10)),
            (["mcdonald", "fast food", "fast-food", "livraison", "deliveroo", "uber eats"], .init(protein: 12, carbs: 26, fats: 15, fiber: 2, sugar: 6, sodium: 900, potassium: 150, magnesium: 15, qualityPenalty: 35, digestivePenalty: 12)),
            (["chips", "crisps", "apéritif", "aperitif", "snack sale"], .init(protein: 6, carbs: 52, fats: 32, fiber: 4, sugar: 1, sodium: 650, potassium: 900, magnesium: 40, qualityPenalty: 28, digestivePenalty: 6)),
            (["soda", "coca", "pepsi", "limonade", "soda", "boisson sucree"], .init(protein: 0, carbs: 11, fats: 0, fiber: 0, sugar: 11, sodium: 15, potassium: 0, magnesium: 0, qualityPenalty: 26, digestivePenalty: 8)),
            (["gateau", "gâteau", "cake", "cookie", "biscuit", "viennoiserie", "croissant", "donut", "beignet", "patisserie"], .init(protein: 5, carbs: 48, fats: 18, fiber: 1.5, sugar: 28, sodium: 380, potassium: 80, magnesium: 12, qualityPenalty: 28, digestivePenalty: 10)),
            (["glace", "ice cream", "dessert", "mousse", "tiramisu"], .init(protein: 4, carbs: 28, fats: 12, fiber: 0.5, sugar: 24, sodium: 90, potassium: 120, magnesium: 14, qualityPenalty: 24, digestivePenalty: 14)),
            (["charcuterie", "jambon", "ham", "bacon", "lardon", "saucisson", "salami", "pepperoni"], .init(protein: 18, carbs: 1, fats: 22, fiber: 0, sugar: 0.5, sodium: 1200, potassium: 220, magnesium: 16, qualityPenalty: 32, digestivePenalty: 8)),
            (["fromage", "cheese", "cheddar", "mozzarella", "emmental"], .init(protein: 22, carbs: 2, fats: 28, fiber: 0, sugar: 1, sodium: 620, potassium: 80, magnesium: 20, qualityPenalty: 14, digestivePenalty: 14)),
            (["creme", "cream", "beurre", "butter", "margarine"], .init(protein: 2, carbs: 3, fats: 35, fiber: 0, sugar: 3, sodium: 45, potassium: 40, magnesium: 4, qualityPenalty: 16, digestivePenalty: 16)),
            (["sauce soja", "soy sauce", "ketchup", "mayo", "mayonnaise", "moutarde"], .init(protein: 2, carbs: 6, fats: 8, fiber: 0, sugar: 8, sodium: 2400, potassium: 60, magnesium: 4, qualityPenalty: 22, digestivePenalty: 4)),
            (["pain", "bread", "baguette", "brioche", "mie"], .init(protein: 9, carbs: 48, fats: 3, fiber: 3, sugar: 4, sodium: 480, potassium: 110, magnesium: 22, qualityPenalty: 12, digestivePenalty: 6)),
            (["pates", "pâtes", "pasta", "spaghetti", "macaroni"], .init(protein: 5, carbs: 30, fats: 1.5, fiber: 2, sugar: 1, sodium: 220, potassium: 50, magnesium: 18, qualityPenalty: 6, digestivePenalty: 4)),
            (["riz", "rice"], .init(protein: 3, carbs: 28, fats: 0.5, fiber: 0.8, sugar: 0.2, sodium: 180, potassium: 35, magnesium: 12, qualityPenalty: 4, digestivePenalty: 2)),
            (["poulet", "chicken", "dinde", "turkey"], .init(protein: 27, carbs: 0, fats: 4, fiber: 0, sugar: 0, sodium: 85, potassium: 280, magnesium: 28, qualityPenalty: 0, digestivePenalty: 0)),
            (["saumon", "salmon", "poisson", "fish", "cabillaud", "cod"], .init(protein: 22, carbs: 0, fats: 8, fiber: 0, sugar: 0, sodium: 70, potassium: 380, magnesium: 30, qualityPenalty: 0, digestivePenalty: 0)),
            (["oeuf", "oeufs", "egg", "eggs"], .init(protein: 13, carbs: 1, fats: 11, fiber: 0, sugar: 0.5, sodium: 140, potassium: 130, magnesium: 12, qualityPenalty: 0, digestivePenalty: 4)),
            (["avocat", "avocado"], .init(protein: 2, carbs: 4, fats: 15, fiber: 7, sugar: 0.5, sodium: 7, potassium: 485, magnesium: 29, qualityPenalty: 0, digestivePenalty: 6)),
            (["banane", "banana"], .init(protein: 1, carbs: 23, fats: 0.3, fiber: 2.6, sugar: 12, sodium: 1, potassium: 358, magnesium: 27, qualityPenalty: 0, digestivePenalty: 4)),
            (["brocoli", "broccoli", "chou", "cabbage", "cauliflower"], .init(protein: 3, carbs: 5, fats: 0.4, fiber: 3, sugar: 2, sodium: 35, potassium: 290, magnesium: 22, qualityPenalty: 0, digestivePenalty: 8)),
            (["salade", "salad", "tomate", "tomato", "concombre", "cucumber", "courgette", "zucchini"], .init(protein: 1.5, carbs: 4, fats: 0.2, fiber: 1.8, sugar: 2.5, sodium: 20, potassium: 260, magnesium: 18, qualityPenalty: 0, digestivePenalty: 0)),
            (["patate", "pomme de terre", "potato", "sweet potato", "patate douce"], .init(protein: 2, carbs: 20, fats: 0.2, fiber: 2.5, sugar: 4, sodium: 15, potassium: 420, magnesium: 24, qualityPenalty: 0, digestivePenalty: 2)),
            (["lentille", "lentil", "pois chiche", "chickpea", "haricot", "bean"], .init(protein: 9, carbs: 20, fats: 0.8, fiber: 8, sugar: 2, sodium: 30, potassium: 350, magnesium: 48, qualityPenalty: 0, digestivePenalty: 18))
        ]

        for rule in rules {
            if rule.tokens.contains(where: { normalizedName.contains($0) }) {
                return rule.template
            }
        }
        return nil
    }

    private static func scaled(
        _ template: MacroTemplate,
        grams: Double,
        name: String,
        role: String
    ) -> IngredientBreakdown {
        let factor = grams / 100.0
        let quality = template.qualityPenalty + keywordQualityPenalty(in: name)
        let digestive = template.digestivePenalty + keywordDigestivePenalty(in: name)

        return IngredientBreakdown(
            grams: grams,
            proteinG: template.protein * factor,
            carbsG: template.carbs * factor,
            fatsG: template.fats * factor,
            fiberG: template.fiber * factor,
            sugarG: template.sugar * factor,
            sodiumMg: template.sodium * factor,
            potassiumMg: template.potassium * factor,
            magnesiumMg: template.magnesium * factor,
            qualityPenalty: quality,
            digestivePenalty: digestive
        )
    }

    private static func roleFallback(grams: Double, role: String, name: String) -> IngredientBreakdown {
        let factor = grams / 100.0
        var protein = 0.0
        var carbs = 0.0
        var fats = 0.0
        var fiber = 1.0
        let sugar = 1.0
        var sodium = 180.0
        var potassium = 120.0
        let magnesium = 12.0

        if role.contains("prot") {
            protein = 22; sodium = 90; potassium = 250
        } else if role.contains("gluc") {
            carbs = 24; sodium = 220; potassium = 80
        } else if role.contains("gras") {
            fats = 18; sodium = 60
        } else if role.contains("leg") {
            carbs = 6; fiber = 3.5; potassium = 280; sodium = 25
        } else {
            carbs = 12; protein = 4; fats = 5; sodium = 250
        }

        return IngredientBreakdown(
            grams: grams,
            proteinG: protein * factor,
            carbsG: carbs * factor,
            fatsG: fats * factor,
            fiberG: fiber * factor,
            sugarG: sugar * factor,
            sodiumMg: sodium * factor,
            potassiumMg: potassium * factor,
            magnesiumMg: magnesium * factor,
            qualityPenalty: keywordQualityPenalty(in: name) + 6,
            digestivePenalty: keywordDigestivePenalty(in: name)
        )
    }

    // MARK: - Penalties

    private static func tierQualityPenalty(_ tier: DebloatFoodTier) -> Double {
        switch tier {
        case .hero: return 0
        case .prefer: return 0
        case .moderate: return 14
        case .avoid: return 32
        }
    }

    private static func tierDigestivePenalty(_ tier: DebloatFoodTier, name: String) -> Double {
        switch tier {
        case .hero, .prefer: return 0
        case .moderate: return 6
        case .avoid: return 10
        }
    }

    private static func keywordQualityPenalty(in text: String) -> Double {
        var penalty = 0.0
        let flags: [(tokens: [String], value: Double)] = [
            (["ultra", "transforme", "processed", "industriel", "industrial", "precuit", "precooked"], 18),
            (["frit", "fried", "deep fried", "pané", "pane", "breaded"], 22),
            (["sauce industrielle", "ready meal", "plat prepare", "prepared meal", "surgele", "frozen meal"], 20),
            (["sucre", "sugar", "sirop", "syrup", "nectar", "candy", "bonbon"], 16),
            (["alcool", "alcohol", "beer", "biere", "wine", "vin", "cocktail"], 18),
            (["soda", "coca", "pepsi", "limonade", "lemonade"], 20)
        ]
        for flag in flags where flag.tokens.contains(where: { text.contains($0) }) {
            penalty += flag.value
        }
        return penalty
    }

    private static func keywordDigestivePenalty(in text: String) -> Double {
        var penalty = 0.0
        let flags: [(tokens: [String], value: Double)] = [
            (["oignon", "onion", "echalote", "shallot"], 20),
            (["ail", "garlic"], 12),
            (["lait", "milk", "lactose", "yaourt", "yogurt", "yoghurt", "fromage blanc"], 12),
            (["creme", "cream", "beurre", "butter"], 14),
            (["haricot", "bean", "lentille", "lentil", "pois chiche", "chickpea", "legume sec"], 18),
            (["brocoli", "broccoli", "chou", "cauliflower", "cabbage", "crucifer"], 8),
            (["avocat", "avocado"], 6),
            (["banane mure", "ripe banana", "banane bien mure"], 7),
            (["sorbitol", "xylitol", "erythritol", "maltitol", "polyol"], 25),
            (["gluten", "ble", "wheat", "pain blanc", "white bread"], 6)
        ]
        for flag in flags where flag.tokens.contains(where: { text.contains($0) }) {
            penalty += flag.value
        }
        return penalty
    }

    // MARK: - Macro helpers

    private static func macroTemplate(
        for food: DebloatFoodItem,
        grams: Double,
        role: String
    ) -> (protein: Double, carbs: Double, fats: Double, fiber: Double, sugar: Double) {
        let factor = grams / 100.0
        switch food.tier {
        case .hero, .prefer:
            if role.contains("prot") {
                return (25 * factor, 2 * factor, 4 * factor, 0.5 * factor, 0.5 * factor)
            }
            if role.contains("leg") {
                return (2 * factor, 5 * factor, 0.3 * factor, 3.5 * factor, 2 * factor)
            }
            return (8 * factor, 12 * factor, 3 * factor, 3 * factor, 4 * factor)
        case .moderate:
            return (8 * factor, 18 * factor, 8 * factor, 2 * factor, 8 * factor)
        case .avoid:
            return (10 * factor, 22 * factor, 14 * factor, 1.5 * factor, 10 * factor)
        }
    }

    private static func defaultSodium(for tier: DebloatFoodTier) -> Double {
        switch tier {
        case .hero, .prefer: return 40
        case .moderate: return 350
        case .avoid: return 900
        }
    }

    private static func defaultPotassium(for tier: DebloatFoodTier, role: String) -> Double {
        switch tier {
        case .hero: return 450
        case .prefer: return 320
        case .moderate: return 180
        case .avoid: return 120
        }
    }

    private static func defaultMagnesium(for tier: DebloatFoodTier) -> Double {
        switch tier {
        case .hero: return 55
        case .prefer: return 35
        case .moderate: return 18
        case .avoid: return 10
        }
    }

    // MARK: - Utils

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
    }

    private static func firstRegexMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func parseNumber(_ raw: String) -> Double? {
        Double(raw.replacingOccurrences(of: ",", with: "."))
    }
}

extension MealSuggestionContent {
    var isPhotoScanned: Bool {
        tags.contains { $0.lowercased().contains("scan") }
    }
}
