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
        "yaourt grec sans lactose si sensible",
        "kéfir nature selon tolérance"
    ]

    static let rules = [
        "Sodium modéré, surtout le soir.",
        "Base potassium naturelle : patate douce, pomme de terre, banane, avocat, épinards ou eau de coco.",
        "Protéines simples à chaque repas : œufs, poulet, dinde, poisson, steak maigre, yaourt sans lactose ou kéfir selon tolérance.",
        "Interdit absolu : porc et alcool — jamais dans le catalogue ni les suggestions.",
        "Salades debloat : roquette, mâche, concombre, tomate, fenouil — vinaigrette citron/huile d'olive, pas sauce salade industrielle.",
        "Légumes variés cuits ou rôtis : brocoli, carottes, poivrons, haricots verts, épinards.",
        "Cuisson savoureuse (poêle, four, grill) : huile d'olive extra vierge, herbes, citron et huile infusée à l'ail — pas friture ni sauces industrielles salées.",
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
                item("Banane jaune peu tachetée", "1", "Glucide"),
                item("Kiwi", "1", "Glucide")
            ],
            prep: "Bois l'eau nature ou citronnée avant de manger. Bats les œufs et brouille 4 min à feu moyen en remuant. Coupe la banane et le kiwi, puis sers avec les œufs.",
            tip: "Eau nature en premier — électrolytes seulement après forte transpiration.",
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
            prep: "Bois l'eau nature ou citronnée. Bats les œufs et brouille jusqu'à texture crémeuse. Écrase l'avocat avec citron et poivre, puis sers à côté des œufs.",
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
            prep: "Bois l'eau nature ou citronnée. Poêle les œufs 3 min de chaque côté. Prépare la salade roquette, concombre, tomates et assaisonne citron-huile d'olive.",
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
                item("Brocoli + courgette, huile infusée à l'ail", "100 g + 100 g", "Légume"),
                item("Huile d'olive extra vierge", "1 c. à soupe", "Gras")
            ],
            prep: "Coupe la patate douce, le brocoli et la courgette. Assaisonne avec huile infusée à l'ail et herbes. Rôtis 22 min à 200°C. Poêle le poulet 6 min de chaque côté, puis dresse.",
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
            prep: "Grille le poulet 6 min de chaque côté, puis tranche. Compose la salade roquette, tomates et concombre. Arrose de vinaigrette citron et huile d'olive maison.",
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
            prep: "Cuire le quinoa selon le paquet et laisser tiédir. Poêle le saumon 4 min peau vers le bas puis 2 min côté chair. Mélange concombre, menthe, citron et huile pour la salade. Dresser saumon, quinoa et salade.",
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
            prep: "Coupe les pommes de terre, rôtis avec thym et huile 25 min à 200°C. Poêle la dinde 5 min de chaque côté. Prépare la salade verte et l'avocat, finis avec citron et huile d'olive.",
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
                item("Poivrons + fenouil rôtis", "220 g", "Légume"),
                item("Huile d'olive extra vierge", "1 c. à soupe", "Gras")
            ],
            prep: "Cuire le riz basmati. Poêle le bœuf haché 6 min à feu vif. Rôtis poivrons et fenouil 18 min à 200°C. Sers avec des herbes fraîches.",
            tip: "Herbes et huile infusée à l'ail — pas de sauce taco ou tomate salée.",
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
            prep: "Assaisonne le lieu avec citron, poêle 3 min de chaque côté. Poêle les haricots verts avec huile infusée à l'ail 5 min. Tranche fenouil et concombre pour la salade croquante.",
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
            prep: "Grille le steak 3 min de chaque côté selon l'épaisseur. Rôtis les pommes de terre 25 min à 200°C. Prépare la salade roquette et tomates avec citron et huile d'olive.",
            tip: "Sel léger le soir ; poivre, herbes et huile infusée à l'ail sur le steak.",
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
            prep: "Marine le poulet avec citron, herbes et huile infusée à l'ail 10 min. Rôtis au four 22 min à 200°C. Compose salade roquette, concombre, tomates et avocat.",
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
                item("Brocoli + courgette, huile infusée à l'ail", "100 g + 100 g", "Légume"),
                item("Huile d'olive", "1 c. à soupe", "Gras")
            ],
            prep: "Cuire le riz basmati. Poêle la dinde 5 min de chaque côté. Rôtis le brocoli et la courgette avec citron et huile infusée à l'ail 15 min à 200°C. Dresse avec le riz.",
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
            prep: "Assaisonne le cabillaud citron-herbes, rôtis 14 min à 190°C. Rôtis les carottes thym 20 min à 200°C. Prépare salade mâche et concombre avec citron et huile d'olive.",
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
                item("Avocat mûr", "1/2", "Gras"),
                item("Salade roquette + concombre", "200 g", "Légume")
            ],
            prep: "Grille le steak 3 min de chaque côté. Rôtis la patate douce 22 min à 200°C. Prépare salade roquette-concombre et tranche l'avocat. Dresser tout sur une grande assiette.",
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
            prep: "Grille le poulet et tranche. Cuire le quinoa et laisser tiédir. Compose le bowl avec salade, tomates, concombre et avocat. Arrose de vinaigrette citron et huile d'olive.",
            tip: "Tout en un bol dense — pas de sauce crémeuse industrielle.",
            tags: ["omad", "salade"],
            sub: .init(protocolFit: 90, satiety: 92, antiBloat: 88),
            image: "meal_debloat_omad_chicken_quinoa_bowl"
        )
    ]

    private static let snackMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Eau de Coco Vita Coco",
            slot: .snack,
            score: 88,
            summary: "Hydratation debloat — potassium naturel, sodium minimal, sans sucre ajouté.",
            items: [
                item("Eau de coco Vita Coco 100% pure", "330 ml", "Autre")
            ],
            prep: "Serve bien frais — directement depuis la brique ou la bouteille. Choisis la version pure, pas nectar ni aromatisée.",
            tip: "Utile après transpiration pour son potassium — cela ne compense pas un excès de sel.",
            tags: ["hydratation", "potassium", "debloat"],
            sub: .init(protocolFit: 90, satiety: 55, antiBloat: 94),
            image: "vitacoco"
        ),
        makeMeal(
            name: "Eau de Coco Banane",
            slot: .snack,
            score: 82,
            summary: "Hydratation + potassium post-sport.",
            items: [
                item("Eau de coco sans sucre ajouté", "250 ml", "Autre"),
                item("Banane jaune peu tachetée", "1", "Glucide"),
                item("Skyr nature sans lactose", "150 g", "Protéine")
            ],
            prep: "Verse l'eau de coco pure. Coupe la banane en rondelles et sers avec le skyr sans lactose.",
            tip: "Après sport uniquement.",
            tags: ["hydratation", "potassium"],
            sub: .init(protocolFit: 82, satiety: 76, antiBloat: 86),
            image: "meal_debloat_coconut_banana"
        ),
        makeMeal(
            name: "Ananas Dinde Rôtie",
            slot: .snack,
            score: 80,
            summary: "Collation protéinée — ananas frais, concombre et dinde maison.",
            items: [
                item("Ananas frais", "200 g", "Glucide"),
                item("Dinde rôtie maison froide", "80 g", "Protéine"),
                item("Concombre", "100 g", "Légume")
            ],
            prep: "Coupe l'ananas frais en tranches. Émince la dinde rôtie maison. Coupe le concombre en bâtonnets et sers le tout frais.",
            tip: "La dinde maison évite le sodium élevé des charcuteries.",
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
