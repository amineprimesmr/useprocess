import Foundation

enum ProcessDebloatMealLibrary {
    static let potassiumFoods = [
        "eau de coco sans sucre",
        "banane",
        "patate douce",
        "pomme de terre vapeur",
        "avocat",
        "épinards cuits",
        "courgettes",
        "concombre",
        "pastèque",
        "haricots blancs",
        "lentilles bien cuites",
        "kiwi"
    ]

    static let debloatFoods = [
        "gingembre",
        "fenouil",
        "concombre",
        "citron",
        "menthe",
        "ananas",
        "asperges",
        "céleri",
        "yaourt grec nature",
        "kéfir nature"
    ]

    static let rules = [
        "Sodium modéré, surtout le soir.",
        "Base potassium naturelle : patate douce, pomme de terre, banane, avocat, épinards ou eau de coco.",
        "Protéines simples à chaque repas : œufs, poulet, dinde, poisson, steak maigre, yaourt grec ou kéfir.",
        "Légumes plutôt cuits si digestion sensible : courgettes, carottes, épinards, asperges.",
        "Évite ultra-transformé, sauces salées, charcuterie, friture et gros repas tardif."
    ]

    static let featuredImageAsset = "meal_debloat_chicken_sweet_potato"

    static var featuredChickenMeal: MealSuggestionContent {
        lunchMeals.first(where: { $0.imageAssetName == featuredImageAsset }) ?? lunchMeals[0]
    }

    static func meal(for slot: MealTimeSlot, dayIndex: Int, planType: NutritionPlanType) -> MealSuggestionContent {
        if slot == .lunch { return featuredChickenMeal }
        let pool = mealPool(for: slot, planType: planType)
        return pool[abs(dayIndex) % max(pool.count, 1)]
    }

    static func promptBlock(for slot: MealTimeSlot?, planType: NutritionPlanType) -> String {
        let slots = slot.map { [$0] } ?? planType.slots
        let referenceMeals = slots.flatMap { mealPool(for: $0, planType: planType).prefix(3) }
        let mealLines = referenceMeals.map { meal in
            "- \(meal.mealType): \(meal.name) — \(meal.items.map { "\($0.name) \($0.quantity)" }.joined(separator: ", "))"
        }
        return """
        Base repas Process à privilégier/adaptater :
        \(mealLines.joined(separator: "\n"))

        Aliments debloat/potassium prioritaires : \(potassiumFoods.joined(separator: ", ")).
        Aides digestives possibles : \(debloatFoods.joined(separator: ", ")).
        Règles : \(rules.joined(separator: " "))
        """
    }

    private static func mealPool(for slot: MealTimeSlot, planType: NutritionPlanType) -> [MealSuggestionContent] {
        if planType == .omad { return omadMeals }
        switch slot {
        case .breakfast: return breakfastMeals
        case .lunch: return lunchMeals
        case .dinner: return dinnerMeals
        case .snack: return snackMeals
        }
    }

    private static let breakfastMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Yaourt Grec Banane Kiwi",
            slot: .breakfast,
            score: 87,
            summary: "Petit-déjeuner protéiné, potassium naturel et digestion légère.",
            items: [
                item("Yaourt grec nature", "250 g", "Protéine"),
                item("Banane", "1 moyenne", "Glucide"),
                item("Kiwi", "1", "Glucide"),
                item("Graines de chia", "10 g", "Gras")
            ],
            prep: "Bol froid prêt en 5 min.",
            tip: "Garde le yaourt nature et évite granola industriel/sucre ajouté.",
            tags: ["potassium", "simple"],
            sub: .init(protocolFit: 88, satiety: 84, antiBloat: 88),
            image: "meal_debloat_greek_yogurt_banana"
        ),
        makeMeal(
            name: "Oeufs Patate Douce Avocat",
            slot: .breakfast,
            score: 90,
            summary: "Dense, stable en énergie, riche en potassium et peu transformé.",
            items: [
                item("Œufs", "3", "Protéine"),
                item("Patate douce vapeur", "180 g", "Glucide"),
                item("Avocat", "1/2", "Gras"),
                item("Épinards cuits", "1 poignée", "Légume")
            ],
            prep: "Œufs brouillés avec patate douce déjà cuite.",
            tip: "Sale léger, ajoute citron/poivre plutôt qu’une sauce salée.",
            tags: ["potassium", "satiété"],
            sub: .init(protocolFit: 92, satiety: 91, antiBloat: 86),
            image: "meal_debloat_eggs_sweet_potato"
        )
    ]

    private static let lunchMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Bol Poulet Patate Douce Courgettes",
            slot: .lunch,
            score: 91,
            summary: "Repas dense, potassium haut, sodium maîtrisé et légumes digestes.",
            items: [
                item("Blanc de poulet", "180 g", "Protéine"),
                item("Patate douce vapeur", "250 g", "Glucide"),
                item("Courgettes vapeur", "200 g", "Légume"),
                item("Huile d'olive", "1 c. à soupe", "Gras")
            ],
            prep: "Bol chaud avec citron, poivre et herbes.",
            tip: "Ajoute 250 ml d’eau de coco sans sucre si séance ou forte chaleur.",
            tags: ["debloat", "potassium"],
            sub: .init(protocolFit: 92, satiety: 89, antiBloat: 91),
            image: "meal_debloat_chicken_sweet_potato"
        ),
        makeMeal(
            name: "Saumon Riz Courgettes Gingembre",
            slot: .lunch,
            score: 89,
            summary: "Oméga-3, glucides propres et gingembre pour une digestion plus légère.",
            items: [
                item("Saumon", "170 g", "Protéine"),
                item("Riz basmati", "180 g cuit", "Glucide"),
                item("Courgettes", "220 g", "Légume"),
                item("Gingembre citron", "1 portion", "Autre")
            ],
            prep: "Saumon poêlé, riz simple, courgettes cuites.",
            tip: "Évite sauce soja classique; si besoin prends citron + gingembre.",
            tags: ["omega3", "anti-gonflement"],
            sub: .init(protocolFit: 90, satiety: 88, antiBloat: 89),
            image: "meal_debloat_salmon_rice_zucchini"
        ),
        makeMeal(
            name: "Dinde Pommes de Terre Épinards",
            slot: .lunch,
            score: 90,
            summary: "Très bon ratio protéines/potassium avec un volume facile à digérer.",
            items: [
                item("Escalope de dinde", "180 g", "Protéine"),
                item("Pommes de terre vapeur", "300 g", "Glucide"),
                item("Épinards cuits", "180 g", "Légume"),
                item("Beurre ou huile d'olive", "10 g", "Gras")
            ],
            prep: "Assiette chaude, herbes, citron, sel modéré.",
            tip: "Parfait en déjeuner les jours où le visage marque la rétention.",
            tags: ["potassium", "low-sodium"],
            sub: .init(protocolFit: 91, satiety: 90, antiBloat: 88),
            image: "meal_debloat_turkey_potato_spinach"
        )
    ]

    private static let dinnerMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Cabillaud Asperges Pommes Vapeur",
            slot: .dinner,
            score: 92,
            summary: "Dîner léger en sel, riche en potassium, idéal visage moins gonflé le matin.",
            items: [
                item("Cabillaud", "190 g", "Protéine"),
                item("Pommes de terre vapeur", "220 g", "Glucide"),
                item("Asperges", "180 g", "Légume"),
                item("Huile d'olive citron", "1 c. à soupe", "Gras")
            ],
            prep: "Cuisson vapeur ou four doux, citron et herbes.",
            tip: "Garde ce dîner simple si ton scan visage marque la rétention.",
            tags: ["soir", "low-sodium"],
            sub: .init(protocolFit: 93, satiety: 86, antiBloat: 94),
            image: "meal_debloat_cod_asparagus_potato"
        ),
        makeMeal(
            name: "Omelette Épinards Avocat Concombre",
            slot: .dinner,
            score: 88,
            summary: "Repas du soir rapide, minéraux naturels et charge digestive basse.",
            items: [
                item("Œufs", "3", "Protéine"),
                item("Épinards cuits", "180 g", "Légume"),
                item("Avocat", "1/2", "Gras"),
                item("Concombre citron menthe", "150 g", "Légume")
            ],
            prep: "Omelette + assiette fraîche citronnée.",
            tip: "Si faim forte, ajoute une petite pomme de terre vapeur plutôt que pain/sauce.",
            tags: ["soir", "potassium"],
            sub: .init(protocolFit: 89, satiety: 84, antiBloat: 91),
            image: "epinardomelette"
        )
    ]

    private static let omadMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Assiette OMAD Steak Patate Avocat",
            slot: .lunch,
            score: 90,
            summary: "Repas unique dense, potassium élevé et protéines solides sans ultra-transformé.",
            items: [
                item("Steak maigre", "230 g", "Protéine"),
                item("Patate douce", "320 g", "Glucide"),
                item("Avocat", "1", "Gras"),
                item("Courgettes + épinards cuits", "300 g", "Légume")
            ],
            prep: "Grande assiette chaude, citron/herbes, sel contrôlé.",
            tip: "Bois eau + éventuellement eau de coco sans sucre autour de la fenêtre repas.",
            tags: ["omad", "potassium"],
            sub: .init(protocolFit: 91, satiety: 94, antiBloat: 86),
            image: "meal_debloat_omad_steak_sweet_potato"
        )
    ]

    private static let snackMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Eau de Coco Banane",
            slot: .snack,
            score: 82,
            summary: "Collation hydratation/potassium simple, à garder ponctuelle.",
            items: [
                item("Eau de coco sans sucre", "250 ml", "Autre"),
                item("Banane", "1", "Glucide"),
                item("Yaourt grec nature", "150 g", "Protéine")
            ],
            prep: "À prendre froid, sans sucre ajouté.",
            tip: "Utile après sport; évite d’en faire une habitude sucrée quotidienne.",
            tags: ["hydratation", "potassium"],
            sub: .init(protocolFit: 82, satiety: 76, antiBloat: 86),
            image: "meal_debloat_coconut_banana"
        )
    ]

    private static func item(_ name: String, _ quantity: String, _ role: String) -> MealSuggestionItem {
        MealSuggestionItem(name: name, quantity: quantity, role: role)
    }

    private static func makeMeal(
        name: String,
        slot: MealTimeSlot,
        score _: Int,
        summary _: String,
        items: [MealSuggestionItem],
        prep: String,
        tip: String,
        tags: [String],
        sub _: MealSubScores,
        image: String
    ) -> MealSuggestionContent {
        MealSuggestionContent.asProcessDefault(
            name: name,
            mealType: slot.rawValue,
            items: items,
            prepMinutes: 15,
            prepSummary: prep,
            coachTip: tip,
            tags: tags,
            imageAssetName: image
        )
    }
}
