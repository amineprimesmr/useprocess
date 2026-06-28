import Foundation

/// Catalogue repas debloat Process — images : `WelcomePlan/MEAL_IMAGE_PROMPTS.md`
enum ProcessDebloatMealLibrary {
    static let potassiumFoods = [
        "eau de coco sans sucre",
        "banane", "kiwi", "melon", "ananas",
        "patate douce", "pomme de terre fermière", "quinoa",
        "avocat", "épinards", "roquette", "brocoli",
        "concombre", "tomate", "poivron", "fenouil",
        "haricots verts", "carottes", "pastèque"
    ]

    static let debloatFoods = [
        "gingembre",
        "fenouil",
        "concombre",
        "citron",
        "menthe",
        "ananas",
        "céleri",
        "yaourt grec nature",
        "kéfir nature"
    ]

    static let rules = [
        "Sodium modéré, surtout le soir.",
        "Base potassium naturelle : patate douce, pomme de terre, banane, avocat, épinards ou eau de coco.",
        "Protéines simples à chaque repas : œufs, poulet, dinde, poisson, steak maigre, yaourt grec ou kéfir.",
        "Interdit absolu : porc et alcool — jamais dans le catalogue ni les suggestions.",
        "Salades debloat : roquette, mâche, concombre, tomate, fenouil — vinaigrette citron/huile d'olive, pas sauce salade industrielle.",
        "Légumes variés cuits ou rôtis : brocoli, carottes, poivrons, haricots verts, épinards.",
        "Cuisson savoureuse (poêle, four, grill) : huile d'olive extra vierge, herbes, ail, citron — pas friture ni sauces industrielles salées.",
        "Évite ultra-transformé, charcuterie salée et gros repas tardif."
    ]

    static let featuredImageAsset = "meal_debloat_chicken_sweet_potato"

    static var featuredChickenMeal: MealSuggestionContent {
        lunchMeals.first(where: { $0.imageAssetName == featuredImageAsset }) ?? lunchMeals[0]
    }

    static func meal(for slot: MealTimeSlot, dayIndex: Int, planType: NutritionPlanType) -> MealSuggestionContent {
        let pool = mealPool(for: slot, planType: planType)
        guard !pool.isEmpty else { return featuredChickenMeal }
        return pool[abs(dayIndex) % pool.count]
    }

    static func mealsInPool(for slot: MealTimeSlot, planType: NutritionPlanType) -> [MealSuggestionContent] {
        mealPool(for: slot, planType: planType)
    }

    /// Repas catalogue dont le nom correspond (slot prioritaire pour le matching image).
    static func catalogMeal(
        matchingName name: String,
        slot: MealTimeSlot,
        planType: NutritionPlanType
    ) -> MealSuggestionContent? {
        let normalized = normalizeCatalogName(name)
        guard !normalized.isEmpty else { return nil }

        let pool = mealPool(for: slot, planType: planType)
        if let exact = pool.first(where: { normalizeCatalogName($0.name) == normalized }) {
            return exact
        }
        return allCatalogMeals.first {
            normalizeCatalogName($0.name) == normalized && $0.timeSlot == slot
        }
    }

    /// Tous les repas catalogue — matching image pour repas IA / legacy persistés.
    static var allCatalogMeals: [MealSuggestionContent] {
        breakfastMeals + lunchMeals + dinnerMeals + omadMeals + snackMeals
    }

    struct CatalogSection: Identifiable, Equatable {
        let slot: MealTimeSlot
        let title: String
        let meals: [MealSuggestionContent]
        var id: String { slot.rawValue }
    }

    /// Sections catalogue debloat — filtrées par type de plan (3 repas, 2MAD, OMAD).
    static func catalogSections(for planType: NutritionPlanType) -> [CatalogSection] {
        planType.slots.map { slot in
            CatalogSection(
                slot: slot,
                title: catalogSectionTitle(for: slot, planType: planType),
                meals: mealsInPool(for: slot, planType: planType)
            )
        }
    }

    static func catalogMealCount(for planType: NutritionPlanType) -> Int {
        planType.slots.reduce(0) { partial, slot in
            partial + mealsInPool(for: slot, planType: planType).count
        }
    }

    static func catalogPreviewImageAssets(for planType: NutritionPlanType, limit: Int = 3) -> [String] {
        var assets: [String] = []
        for slot in planType.slots {
            for meal in mealsInPool(for: slot, planType: planType) {
                let asset = meal.imageAssetName ?? featuredImageAsset
                if !assets.contains(asset) {
                    assets.append(asset)
                }
                if assets.count >= limit { return assets }
            }
        }
        return assets
    }

    private static func catalogSectionTitle(for slot: MealTimeSlot, planType: NutritionPlanType) -> String {
        if planType == .omad, slot == .lunch {
            return "Repas OMAD"
        }
        return slot.rawValue
    }

    /// Sections catalogue debloat — petit-déj, midi, dîner, collation (tous types de plan).
    static func catalogSections() -> [CatalogSection] {
        [
            CatalogSection(slot: .breakfast, title: "Petit-déjeuner", meals: breakfastMeals),
            CatalogSection(slot: .lunch, title: "Déjeuner", meals: lunchMeals),
            CatalogSection(slot: .dinner, title: "Dîner", meals: dinnerMeals),
            CatalogSection(slot: .snack, title: "Collation", meals: snackMeals)
        ]
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
            name: "Œufs Banane Kiwi",
            slot: .breakfast,
            score: 88,
            summary: "Hydratation, protéines et fruits potassium — rapide le matin.",
            items: [
                item(ProcessHydrationGuide.morningWaterItemName, ProcessHydrationGuide.morningWaterLabel, "Hydratation"),
                item("Œufs plein air", "2", "Protéine"),
                item("Banane bien mûre", "1", "Glucide"),
                item("Kiwi", "1", "Glucide")
            ],
            prep: "Œufs brouillés dorés, fruits frais.",
            tip: "Eau salée en premier — pas de pain blanc ni granola industriel.",
            tags: ["potassium", "simple"],
            sub: .init(protocolFit: 89, satiety: 82, antiBloat: 88),
            image: "meal_debloat_eggs_banana_kiwi"
        ),
        makeMeal(
            name: "Œufs Avocat Citron",
            slot: .breakfast,
            score: 89,
            summary: "Protéines et lipides qualité — sans tubercule au matin.",
            items: [
                item(ProcessHydrationGuide.morningWaterItemName, ProcessHydrationGuide.morningWaterLabel, "Hydratation"),
                item("Œufs plein air", "3", "Protéine"),
                item("Avocat mûr", "1/2", "Gras"),
                item("Citron frais", "1/2", "Autre")
            ],
            prep: "Œufs brouillés, avocat, citron et poivre.",
            tip: "Citron > sauce salée sur les œufs.",
            tags: ["simple", "satiété"],
            sub: .init(protocolFit: 90, satiety: 88, antiBloat: 87),
            image: "meal_debloat_eggs_avocado"
        ),
        makeMeal(
            name: "Œufs Tomates Salade Roquette",
            slot: .breakfast,
            score: 87,
            summary: "Petit-déj salé + salade fraîche — change des fruits seuls.",
            items: [
                item(ProcessHydrationGuide.morningWaterItemName, ProcessHydrationGuide.morningWaterLabel, "Hydratation"),
                item("Œufs plein air", "2", "Protéine"),
                item("Tomates cerises", "150 g", "Légume"),
                item("Roquette + concombre", "120 g", "Légume")
            ],
            prep: "Œufs poêlés, salade roquette-concombre citron et huile d'olive.",
            tip: "Tomates + roquette : fibres et potassium sans tubercule.",
            tags: ["salade", "simple"],
            sub: .init(protocolFit: 88, satiety: 80, antiBloat: 89),
            image: "meal_debloat_eggs_tomato_salad"
        )
    ]

    private static let lunchMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Poulet Patate Douce Brocoli",
            slot: .lunch,
            score: 91,
            summary: "Classique dense — poulet doré, tubercule rôti et brocoli grillé.",
            items: [
                item("Blanc de poulet (label rouge)", "180 g", "Protéine"),
                item("Patate douce rôtie", "220 g", "Glucide"),
                item("Brocoli rôti ail-citron", "200 g", "Légume"),
                item("Huile d'olive extra vierge", "1 c. à soupe", "Gras")
            ],
            prep: "Poulet poêlé herbes, patate et brocoli rôtis au four.",
            tip: "Eau de coco sans sucre si sport ou chaleur.",
            tags: ["debloat", "potassium"],
            sub: .init(protocolFit: 92, satiety: 89, antiBloat: 91),
            image: "meal_debloat_chicken_sweet_potato"
        ),
        makeMeal(
            name: "Salade Poulet Avocat Composée",
            slot: .lunch,
            score: 90,
            summary: "Grande salade protéinée — avocat, concombre, roquette, tomate.",
            items: [
                item("Blanc de poulet grillé (label rouge)", "180 g", "Protéine"),
                item("Avocat mûr", "1/2", "Gras"),
                item("Roquette + tomates cerises", "150 g", "Légume"),
                item("Concombre + citron + huile d'olive", "150 g", "Légume")
            ],
            prep: "Poulet grillé tranché sur salade — vinaigrette citron maison.",
            tip: "Pas de sauce salade du commerce (sodium + sucre).",
            tags: ["salade", "viande"],
            sub: .init(protocolFit: 91, satiety: 86, antiBloat: 92),
            image: "meal_debloat_chicken_avocado_salad"
        ),
        makeMeal(
            name: "Saumon Quinoa Salade Concombre",
            slot: .lunch,
            score: 89,
            summary: "Oméga-3, quinoa complet et salade fraîche menthe-citron.",
            items: [
                item("Pavé de saumon frais", "170 g", "Protéine"),
                item("Quinoa cuit", "160 g", "Glucide"),
                item("Salade concombre menthe", "200 g", "Légume"),
                item("Huile d'olive + citron", "1 c. à soupe", "Gras")
            ],
            prep: "Saumon poêlé peau dorée, quinoa, salade concombre fraîche.",
            tip: "Change du riz — quinoa + salade = variété et fibres.",
            tags: ["omega3", "salade"],
            sub: .init(protocolFit: 90, satiety: 87, antiBloat: 90),
            image: "meal_debloat_salmon_quinoa_salad"
        ),
        makeMeal(
            name: "Dinde Pommes Salade Verte",
            slot: .lunch,
            score: 90,
            summary: "Dinde poêlée, pommes rôties et salade verte avocat.",
            items: [
                item("Escalope de dinde", "180 g", "Protéine"),
                item("Pommes de terre fermières rôties", "250 g", "Glucide"),
                item("Salade verte + avocat", "180 g", "Légume"),
                item("Huile d'olive + citron", "1 c. à soupe", "Gras")
            ],
            prep: "Dinde dorée, pommes rôties thym, salade avocat citron.",
            tip: "Journée rétention : sel modéré, citron sur la dinde.",
            tags: ["potassium", "salade"],
            sub: .init(protocolFit: 91, satiety: 90, antiBloat: 88),
            image: "meal_debloat_turkey_potato_salad"
        ),
        makeMeal(
            name: "Bœuf Haché Riz Poivrons",
            slot: .lunch,
            score: 90,
            summary: "Bœuf 5% frais, riz basmati et poivrons rôtis — pas de patate douce.",
            items: [
                item("Bœuf haché 5% MG frais", "200 g", "Protéine"),
                item("Riz basmati semi-complet", "180 g cuit", "Glucide"),
                item("Poivrons + oignons rôtis", "220 g", "Légume"),
                item("Huile d'olive extra vierge", "1 c. à soupe", "Gras")
            ],
            prep: "Bœuf poêlé doré, riz basmati, poivrons rôtis au four.",
            tip: "Herbes fraîches, ail — pas de sauce taco ou tomate salée.",
            tags: ["viande", "variété"],
            sub: .init(protocolFit: 90, satiety: 91, antiBloat: 87),
            image: "meal_debloat_beef_rice_peppers"
        ),
        makeMeal(
            name: "Lieu Noir Haricots Salade Fenouil",
            slot: .lunch,
            score: 88,
            summary: "Poisson blanc léger, haricots verts et salade fenouil-concombre.",
            items: [
                item("Filet de lieu noir frais", "190 g", "Protéine"),
                item("Haricots verts poêlés", "200 g", "Légume"),
                item("Salade fenouil + concombre", "150 g", "Légume"),
                item("Huile d'olive + citron", "1 c. à soupe", "Gras")
            ],
            prep: "Lieu poêlé citron, haricots verts ail, salade fenouil croquante.",
            tip: "Poisson blanc le soir aussi possible — très léger en sel.",
            tags: ["poisson", "salade"],
            sub: .init(protocolFit: 89, satiety: 84, antiBloat: 91),
            image: "meal_debloat_white_fish_green_salad"
        )
    ]

    private static let dinnerMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Steak Salade Roquette Pommes",
            slot: .dinner,
            score: 91,
            summary: "Steak grillé, salade roquette-tomate et pommes rôties — dîner viande + salade.",
            items: [
                item("Steak maigre (rumsteck)", "200 g", "Protéine"),
                item("Pommes de terre fermières rôties", "180 g", "Glucide"),
                item("Salade roquette + tomates", "180 g", "Légume"),
                item("Huile d'olive + citron", "1 c. à soupe", "Gras")
            ],
            prep: "Steak grillé, pommes rôties, salade roquette vinaigrette citron.",
            tip: "Sel léger le soir ; poivre et ail sur le steak.",
            tags: ["soir", "viande", "salade"],
            sub: .init(protocolFit: 92, satiety: 88, antiBloat: 90),
            image: "meal_debloat_steak_salad_potato"
        ),
        makeMeal(
            name: "Poulet Rôti Salade Avocat",
            slot: .dinner,
            score: 90,
            summary: "Poulet doré au four et grande salade avocat-concombre.",
            items: [
                item("Blanc de poulet label rouge", "200 g", "Protéine"),
                item("Salade composée (roquette, concombre)", "200 g", "Légume"),
                item("Avocat mûr", "1/2", "Gras"),
                item("Tomates cerises", "120 g", "Légume")
            ],
            prep: "Poulet rôti herbes/ail, salade fraîche avocat citron.",
            tip: "Marinade citron-herbes maison — pas marinade industrielle.",
            tags: ["soir", "salade", "viande"],
            sub: .init(protocolFit: 91, satiety: 86, antiBloat: 91),
            image: "meal_debloat_chicken_salad_bowl"
        ),
        makeMeal(
            name: "Dinde Brocoli Riz Basmati",
            slot: .dinner,
            score: 89,
            summary: "Dinde poêlée, brocoli rôti et riz — dîner protéiné sans salade uniquement.",
            items: [
                item("Escalope de dinde", "190 g", "Protéine"),
                item("Riz basmati semi-complet", "160 g cuit", "Glucide"),
                item("Brocoli rôti ail-citron", "200 g", "Légume"),
                item("Huile d'olive", "1 c. à soupe", "Gras")
            ],
            prep: "Dinde poêlée, brocoli rôti four, riz basmati.",
            tip: "Alternative chaude quand tu ne veux pas de salade froide.",
            tags: ["soir", "viande"],
            sub: .init(protocolFit: 90, satiety: 88, antiBloat: 88),
            image: "meal_debloat_turkey_broccoli_rice"
        ),
        makeMeal(
            name: "Cabillaud Carottes Salade Mâche",
            slot: .dinner,
            score: 88,
            summary: "Poisson blanc rôti, carottes fondantes et salade mâche citron.",
            items: [
                item("Filet de cabillaud frais", "190 g", "Protéine"),
                item("Carottes rôties au thym", "200 g", "Légume"),
                item("Salade mâche + concombre", "150 g", "Légume"),
                item("Huile d'olive + citron", "1 c. à soupe", "Gras")
            ],
            prep: "Cabillaud rôti four citron-herbes, carottes rôties, salade mâche fraîche.",
            tip: "Poisson blanc le soir — sel modéré, citron sur le poisson.",
            tags: ["soir", "poisson", "salade"],
            sub: .init(protocolFit: 89, satiety: 84, antiBloat: 91),
            image: "meal_debloat_cod_carrot_salad"
        )
    ]

    private static let omadMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Assiette OMAD Steak Patate Avocat",
            slot: .lunch,
            score: 90,
            summary: "Repas unique dense — steak grillé, patate rôtie, avocat.",
            items: [
                item("Steak maigre (rumsteck)", "230 g", "Protéine"),
                item("Patate douce rôtie", "320 g", "Glucide"),
                item("Avocat mûr", "1", "Gras"),
                item("Salade roquette + concombre", "200 g", "Légume")
            ],
            prep: "Steak grillé, patate rôtie, avocat et salade citron sur la même assiette.",
            tip: "Eau + eau de coco sans sucre — sel contrôlé dans la fenêtre.",
            tags: ["omad", "potassium"],
            sub: .init(protocolFit: 91, satiety: 94, antiBloat: 86),
            image: "meal_debloat_omad_steak_sweet_potato"
        ),
        makeMeal(
            name: "Bowl OMAD Poulet Quinoa Salade",
            slot: .lunch,
            score: 89,
            summary: "OMAD salade-bowl — poulet grillé, quinoa, légumes variés et avocat.",
            items: [
                item("Blanc de poulet grillé", "220 g", "Protéine"),
                item("Quinoa cuit", "200 g", "Glucide"),
                item("Salade composée (roquette, tomate, concombre)", "250 g", "Légume"),
                item("Avocat mûr", "1/2", "Gras")
            ],
            prep: "Grand bowl : poulet tranché, quinoa, salade et avocat vinaigrette citron.",
            tip: "Tout en un bol dense — pas de sauce crémeuse industrielle.",
            tags: ["omad", "salade"],
            sub: .init(protocolFit: 90, satiety: 92, antiBloat: 88),
            image: "meal_debloat_omad_chicken_quinoa_bowl"
        )
    ]

    private static let snackMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Eau de Coco Banane",
            slot: .snack,
            score: 82,
            summary: "Hydratation + potassium post-sport.",
            items: [
                item("Eau de coco sans sucre ajouté", "250 ml", "Autre"),
                item("Banane bien mûre", "1", "Glucide"),
                item("Yaourt grec 0% nature", "150 g", "Protéine")
            ],
            prep: "Frais — eau de coco pure, pas nectar.",
            tip: "Après sport uniquement.",
            tags: ["hydratation", "potassium"],
            sub: .init(protocolFit: 82, satiety: 76, antiBloat: 86),
            image: "meal_debloat_coconut_banana"
        ),
        makeMeal(
            name: "Ananas Jambon de Dinde",
            slot: .snack,
            score: 80,
            summary: "Collation protéinée — ananas frais (bromélaïne) et dinde qualité.",
            items: [
                item("Ananas frais", "200 g", "Glucide"),
                item("Jambon de dinde supérieur", "80 g", "Protéine"),
                item("Concombre", "100 g", "Légume")
            ],
            prep: "Tranches ananas frais, jambon dinde sans nitrites si possible.",
            tip: "Ponctuel — pas charcuterie industrielle quotidienne.",
            tags: ["variété", "protéine"],
            sub: .init(protocolFit: 80, satiety: 72, antiBloat: 85),
            image: "meal_debloat_pineapple_turkey_snack"
        )
    ]

    private static func normalizeCatalogName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
    }

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
