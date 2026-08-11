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

    /// Nom affiché (EN via `AppCopy`) — `name` FR inchangé pour la persistance / matching.
    @MainActor
    static func localizedName(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let en = ProcessLocalizedMealContent.mealNamesFRToEN[trimmed] {
            return ProcessLocalizedMealContent.name(trimmed, en: en)
        }
        let recipe = ProcessLocalizedDebloatFoodContent.localizedRecipeName(trimmed)
        if recipe != trimmed || trimmed.hasPrefix("Matin dégonflé") || trimmed.hasPrefix("Bowl K")
            || trimmed.hasPrefix("Dîner anti-rétention") || trimmed.hasPrefix("Collation drainante") {
            return recipe
        }
        return ProcessLocalizedBreakfastBuilderContent.localizedComposedMealName(trimmed)
    }

    /// Tip coach affiché — lookup par texte FR persisté.
    @MainActor
    static func localizedTip(for tip: String) -> String {
        let trimmed = tip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if let en = ProcessLocalizedMealContent.mealTipsFRToEN[trimmed] {
            return ProcessLocalizedMealContent.tip(trimmed, en: en)
        }
        if let recipeTip = ProcessLocalizedDebloatFoodContent.localizedRecipeTip(trimmed) {
            return recipeTip
        }
        if trimmed.hasPrefix("Pas de pain ni céréales industrielles") {
            return AppCopy.t(
                trimmed,
                en: "No bread or industrial cereal in the morning. Water is tracked separately on Home."
            )
        }
        return trimmed
    }

    /// Résumé / blurb catalogue — lookup par texte FR persisté (`scoreSummary`).
    @MainActor
    static func localizedSummary(for summary: String) -> String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        guard let en = ProcessLocalizedMealContent.mealSummariesFRToEN[trimmed] else {
            return trimmed
        }
        return ProcessLocalizedMealContent.summary(trimmed, en: en)
    }

    /// Étapes de préparation catalogue — lookup par bloc FR normalisé.
    @MainActor
    static func localizedPrep(for prep: String) -> String {
        let trimmed = prep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let key = ProcessLocalizedMealContent.normalizedPrepKey(trimmed)
        if let en = ProcessLocalizedMealContent.mealPrepsFRToEN[key]
            ?? ProcessLocalizedMealContent.mealPrepsFRToEN[trimmed] {
            return ProcessLocalizedMealContent.prep(trimmed, en: en)
        }
        if let recipePrep = ProcessLocalizedDebloatFoodContent.localizedRecipePrep(trimmed) {
            return recipePrep
        }
        // Builder petit-déj — prep déjà via AppCopy au build ; fallback FR.
        if trimmed.hasPrefix("Compose ton petit-déj") {
            return AppCopy.t(
                trimmed,
                en: "Build your debloat breakfast — protein + potassium, no drink in the meal."
            )
        }
        return trimmed
    }

    /// Nom d’ingrédient catalogue / Debloat / builder.
    @MainActor
    static func localizedItemName(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if let en = ProcessLocalizedMealContent.itemNamesFRToEN[trimmed] {
            return ProcessLocalizedMealContent.itemName(trimmed, en: en)
        }
        return ProcessLocalizedMealContent.ingredientName(trimmed)
    }

    /// Quantité affichée (unités FR → EN si besoin).
    @MainActor
    static func localizedQuantity(for quantity: String) -> String {
        let trimmed = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if let en = ProcessLocalizedMealContent.quantitiesFRToEN[trimmed] {
            return ProcessLocalizedMealContent.quantity(trimmed, en: en)
        }
        return ProcessLocalizedMealContent.ingredientQuantity(trimmed)
    }

    struct CatalogSection: Identifiable, Equatable {
        let sectionKey: String
        let slot: MealTimeSlot
        let title: String
        let meals: [MealSuggestionContent]
        var id: String { sectionKey }
    }

    /// Catalogue complet — toutes les sections, indépendamment du plan (OMAD, 2MAD, etc.).
    static func fullCatalogSections() -> [CatalogSection] {
        [
            CatalogSection(sectionKey: "breakfast", slot: .breakfast, title: AppCopy.tSync("Petit-déjeuner", en: "Breakfast"), meals: breakfastMeals),
            CatalogSection(sectionKey: "lunch", slot: .lunch, title: AppCopy.tSync("Déjeuner", en: "Lunch"), meals: lunchMeals),
            CatalogSection(sectionKey: "dinner", slot: .dinner, title: AppCopy.tSync("Dîner", en: "Dinner"), meals: dinnerMeals),
            CatalogSection(sectionKey: "omad", slot: .lunch, title: AppCopy.tSync("Repas OMAD", en: "OMAD meal"), meals: omadMeals),
            CatalogSection(sectionKey: "snack", slot: .snack, title: AppCopy.tSync("Collation", en: "Snack"), meals: snackMeals)
        ]
        .filter { !$0.meals.isEmpty }
    }

    /// Toutes les propositions d'un créneau — pour swiper dans le détail repas.
    static func catalogMeals(for slot: MealTimeSlot) -> [MealSuggestionContent] {
        switch slot {
        case .breakfast: return breakfastMeals
        case .lunch: return lunchMeals + omadMeals
        case .dinner: return dinnerMeals
        case .snack: return snackMeals
        }
    }

    static func fullCatalogMealCount() -> Int {
        fullCatalogSections().reduce(0) { $0 + $1.meals.count }
    }

    static func fullCatalogPreviewImageAssets(limit: Int = 3) -> [String] {
        var assets: [String] = []
        for section in fullCatalogSections() {
            for meal in section.meals {
                let asset = meal.imageAssetName ?? featuredImageAsset
                if !assets.contains(asset) {
                    assets.append(asset)
                }
                if assets.count >= limit { return assets }
            }
        }
        return assets
    }

    /// Cache statique pour le carousel accueil — évite de reconstruire la liste à chaque frame.
    static let homeCatalogPreviewImageAssets: [String] = fullCatalogPreviewImageAssets()

    /// Sections catalogue debloat — filtrées par type de plan (carousel du jour).
    static func catalogSections(for planType: NutritionPlanType) -> [CatalogSection] {
        planType.slots.map { slot in
            CatalogSection(
                sectionKey: slot.rawValue,
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
            return AppCopy.tSync("Repas OMAD", en: "OMAD meal")
        }
        switch slot {
        case .breakfast: return AppCopy.tSync("Petit-déjeuner", en: "Breakfast")
        case .lunch: return AppCopy.tSync("Déjeuner", en: "Lunch")
        case .dinner: return AppCopy.tSync("Dîner", en: "Dinner")
        case .snack: return AppCopy.tSync("Collation", en: "Snack")
        }
    }

    /// Sections catalogue debloat — petit-déj, midi, dîner, OMAD, collation.
    static func catalogSections() -> [CatalogSection] {
        fullCatalogSections()
    }

    static func promptBlock(for slot: MealTimeSlot?, planType: NutritionPlanType) -> String {
        let slots = slot.map { [$0] } ?? planType.slots
        let referenceMeals = slots.flatMap { mealPool(for: $0, planType: planType).prefix(3) }
        let mealLines = referenceMeals.map { meal in
            "- \(meal.mealType): \(meal.name) — \(meal.foodItems.map { "\($0.name) \($0.quantity)" }.joined(separator: ", "))"
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
            name: "Œufs Brouillés Banane Kiwi",
            slot: .breakfast,
            score: 88,
            summary: "Le plus simple — 3 œufs, banane et kiwi potassium.",
            items: [
                item("Œufs plein air", "3", "Protéine"),
                item("Banane", "1", "Glucide"),
                item("Kiwi", "1", "Glucide")
            ],
            prepMinutes: 10,
            prep: """
            1. Casse les 3 œufs dans un bol, bats-les à la fourchette avec poivre (sans sel).
            2. Fais chauffer une poêle à feu moyen avec un filet d’huile d’olive.
            3. Verse les œufs et brouille 4 à 5 min en remuant jusqu’à texture crémeuse.
            4. Coupe la banane et le kiwi en rondelles, puis sers à côté des œufs.
            """,
            tip: "Zéro sel dans la poêle — poivre et herbes suffisent.",
            tags: ["simple", "potassium"],
            sub: .init(protocolFit: 89, satiety: 84, antiBloat: 88),
            image: "meal_debloat_eggs_banana_kiwi"
        ),
        makeMeal(
            name: "Yaourt Myrtilles Miel",
            slot: .breakfast,
            score: 86,
            summary: "Petit-déj style sucré — yaourt ou kéfir nature, myrtilles et une pointe de miel.",
            items: [
                item("Yaourt nature ou kéfir nature", "200 g", "Protéine"),
                item("Myrtilles", "80 g", "Glucide"),
                item("Miel", "1 c. à café", "Autre"),
                item("Amandes non salées", "10 g", "Gras")
            ],
            prepMinutes: 5,
            prep: """
            1. Verse le yaourt nature ou le kéfir dans un bol.
            2. Ajoute les myrtilles rincées sur le dessus.
            3. Verse 1 c. à café de miel en filet léger.
            4. Concasse les amandes non salées et parsème avant de manger.
            """,
            tip: "Une seule c. à café de miel — le goût sucré vient surtout des myrtilles.",
            tags: ["sucré", "simple", "rapide"],
            sub: .init(protocolFit: 86, satiety: 78, antiBloat: 85),
            image: "meal_debloat_yogurt_blueberry"
        ),
        makeMeal(
            name: "Bowl Saumon Avocat Concombre",
            slot: .breakfast,
            score: 91,
            summary: "Brunch salé drainant — saumon frais (jamais fumé), avocat et concombre.",
            items: [
                item("Saumon frais", "120 g", "Protéine"),
                item("Avocat mûr", "1/2", "Gras"),
                item("Concombre", "1/2", "Légume"),
                item("Citron + aneth ou ciboulette", "1/2 citron", "Autre")
            ],
            prepMinutes: 12,
            prep: """
            1. Fais chauffer une poêle à feu moyen-vif avec un filet d’huile d’olive.
            2. Poêle le saumon frais 3 à 4 min par face, sans sel — poivre et herbes seulement.
            3. Coupe l’avocat en lamelles et le concombre en rondelles.
            4. Dresse le saumon, l’avocat et le concombre dans un bol.
            5. Arrose de citron et parsème d’aneth ou de ciboulette.
            """,
            tip: "Saumon fumé = sodium élevé — toujours frais.",
            tags: ["saumon", "potassium", "debloat"],
            sub: .init(protocolFit: 92, satiety: 88, antiBloat: 91),
            image: "meal_debloat_salmon_avocado_bowl"
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
            prepMinutes: 30,
            prep: """
            1. Préchauffe le four à 200°C.
            2. Coupe la patate douce, le brocoli et la courgette en morceaux réguliers.
            3. Mélange les légumes avec 1 c. à soupe d’huile d’olive, herbes et huile infusée à l’ail (sans sel).
            4. Étale sur une plaque et rôtis 22 min à 200°C en remuant à mi-cuisson.
            5. Pendant ce temps, poêle le blanc de poulet 6 min de chaque côté à feu moyen.
            6. Laisse reposer le poulet 2 min, tranche-le, puis dresse avec les légumes rôtis.
            """,
            tip: "Herbes et citron plutôt que sel sur le poulet.",
            tags: ["debloat", "potassium"],
            sub: .init(protocolFit: 92, satiety: 89, antiBloat: 91),
            image: "meal_debloat_chicken_sweet_potato"
        ),
        makeMeal(
            name: "Patate Douce Viande Avocat",
            slot: .lunch,
            score: 93,
            summary: "Patate douce rôtie, viande hachée maigre, pico frais et avocat en éventail.",
            items: [
                item("Patate douce (très grosse ou 2 moyennes)", "1", "Glucide"),
                item("Viande hachée maigre (dinde, poulet ou bœuf 5%)", "170 g", "Protéine"),
                item("Avocat bien mûr", "1", "Gras"),
                item("Salade pico (tomates, oignon rouge, poivron, coriandre)", "250 g", "Légume"),
                item("Citron + ail + cumin + huile d'olive", "1 c. à café", "Gras")
            ],
            prepMinutes: 50,
            prep: """
            1. Préchauffe le four à 200°C. Lave la patate douce et coupe-la en 2 dans le sens de la longueur.
            2. Enfourne 40–50 min (face coupée vers le haut ou le bas) jusqu’à ce qu’elle soit ultra-tendre à la fourchette.
            3. Fais revenir l’ail et le cumin dans une goutte d’huile d’olive, puis ajoute la viande hachée et cuis-la bien en l’émiettant.
            4. Hors du feu, ajoute un peu de jus de citron et du poivre. Réserve.
            5. Coupe tomates, oignon rouge et poivron en tout petits dés. Mélange avec coriandre ou persil, le reste de citron, une pincée de cumin et poivre. Laisse mariner 5–10 min.
            6. Pose les 2 moitiés de patate côte à côte, écrase légèrement la chair. Répartis la viande chaude, puis la salade. Dispose l’avocat en tranches fines en éventail au centre. Finis avec un filet de citron et un peu d’herbes.
            """,
            tip: "1 grosse portion ou 2 moyennes — sel très léger, le citron et le cumin portent le goût.",
            tags: ["debloat", "potassium", "patate douce"],
            sub: .init(protocolFit: 94, satiety: 92, antiBloat: 91),
            image: "meal_debloat_sweet_potato_meat_avocado"
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
            prepMinutes: 18,
            prep: """
            1. Fais chauffer une poêle ou un grill à feu moyen-vif.
            2. Cuire le blanc de poulet 6 min de chaque côté, puis laisse reposer 2 min.
            3. Tranche le poulet en lanières.
            4. Dans un grand bol, mets la roquette, les tomates cerises et le concombre.
            5. Ajoute l’avocat en lamelles et le poulet.
            6. Prépare une vinaigrette citron + huile d’olive maison, arrose et mélange.
            """,
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
            prepMinutes: 25,
            prep: """
            1. Rince le quinoa, puis cuis-le selon le paquet. Égoutte et laisse tiédir.
            2. Coupe le concombre, ciseèle la menthe, mélange avec citron et huile d’olive.
            3. Fais chauffer une poêle à feu moyen-vif.
            4. Poêle le saumon 4 min peau vers le bas, puis 2 min côté chair (sans sel).
            5. Dresse le quinoa, la salade concombre-menthe et le saumon dans l’assiette.
            """,
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
            prepMinutes: 35,
            prep: """
            1. Préchauffe le four à 200°C.
            2. Coupe les pommes de terre en quartiers, mélange avec thym et huile d’olive.
            3. Rôtis 25 min à 200°C jusqu’à doré.
            4. Poêle la dinde 5 min de chaque côté à feu moyen.
            5. Prépare la salade verte et l’avocat en lamelles.
            6. Finis avec citron et huile d’olive, puis dresse dinde, pommes et salade.
            """,
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
            prepMinutes: 30,
            prep: """
            1. Préchauffe le four à 200°C et lance la cuisson du riz basmati.
            2. Coupe poivrons et fenouil, mélange avec huile d’olive et herbes.
            3. Rôtis les légumes 18 min à 200°C.
            4. Poêle le bœuf haché 6 min à feu vif en émiettant bien (sans sauce salée).
            5. Dresse riz, bœuf et légumes, puis parsème d’herbes fraîches.
            """,
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
            prepMinutes: 20,
            prep: """
            1. Arrose le lieu de citron et d’herbes (sans sel).
            2. Poêle le filet 3 min de chaque côté à feu moyen.
            3. Poêle les haricots verts 5 min avec un filet d’huile infusée à l’ail.
            4. Tranche finement le fenouil et le concombre pour la salade.
            5. Dresse poisson, haricots et salade, puis arrose d’huile d’olive et citron.
            """,
            tip: "Poisson blanc le soir aussi possible — très léger en sel.",
            tags: ["poisson", "salade"],
            sub: .init(protocolFit: 89, satiety: 84, antiBloat: 91),
            image: "meal_debloat_white_fish_green_salad"
        )
    ]

    private static let dinnerMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Steak Salade Épinards Pommes",
            slot: .dinner,
            score: 91,
            summary: "Steak grillé, salade épinards-tomate et pommes de terre sautées — dîner viande + salade.",
            items: [
                item("Steak maigre (rumsteck)", "200 g", "Protéine"),
                item("Pommes de terre fermières sautées", "180 g", "Glucide"),
                item("Salade épinards + tomates", "180 g", "Légume"),
                item("Huile d'olive + citron", "1 c. à soupe", "Gras")
            ],
            prepMinutes: 35,
            prep: """
            1. Coupe les pommes de terre en morceaux et fais-les revenir à la poêle avec huile d’olive et herbes jusqu’à doré.
            2. Sors le steak du frigo 10 min avant la cuisson pour qu’il soit moins froid.
            3. Grille le steak 3 min de chaque côté selon l’épaisseur (sel très léger ou aucun).
            4. Compose la salade d’épinards frais et tomates avec citron et huile d’olive.
            5. Laisse reposer le steak 2 min, puis dresse avec pommes de terre et salade.
            """,
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
            prepMinutes: 35,
            prep: """
            1. Préchauffe le four à 200°C.
            2. Marine le poulet 10 min avec citron, herbes et huile infusée à l’ail.
            3. Enfourne le poulet 22 min à 200°C jusqu’à doré.
            4. Pendant la cuisson, coupe roquette, concombre, tomates et avocat.
            5. Compose la salade et arrose de citron + huile d’olive.
            6. Tranche le poulet et sers avec la salade.
            """,
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
            prepMinutes: 30,
            prep: """
            1. Préchauffe le four à 200°C et lance la cuisson du riz basmati.
            2. Coupe brocoli et courgette, mélange avec citron et huile infusée à l’ail.
            3. Rôtis les légumes 15 min à 200°C.
            4. Poêle la dinde 5 min de chaque côté à feu moyen.
            5. Dresse riz, dinde et légumes rôtis dans l’assiette.
            """,
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
            prepMinutes: 30,
            prep: """
            1. Préchauffe le four à 200°C.
            2. Coupe les carottes, mélange avec thym et huile d’olive, rôtis 20 min.
            3. Assaisonne le cabillaud citron-herbes, puis enfourne 14 min à 190°C.
            4. Prépare la salade mâche-concombre avec citron et huile d’olive.
            5. Dresse poisson, carottes et salade dans l’assiette.
            """,
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
            prepMinutes: 35,
            prep: """
            1. Préchauffe le four à 200°C.
            2. Coupe la patate douce, rôtis 22 min à 200°C avec un filet d’huile.
            3. Grille le steak 3 min de chaque côté, puis laisse reposer 2 min.
            4. Prépare la salade roquette-concombre et tranche l’avocat.
            5. Dresse tout sur une grande assiette : steak, patate, salade, avocat.
            """,
            tip: "Sel contrôlé dans la fenêtre OMAD — herbes et citron en priorité.",
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
            prepMinutes: 30,
            prep: """
            1. Cuis le quinoa selon le paquet, égoutte et laisse tiédir.
            2. Grille le poulet 6 min de chaque côté, puis tranche-le.
            3. Coupe tomates, concombre et avocat ; prépare la roquette.
            4. Compose le bowl : quinoa, salade, légumes et poulet.
            5. Arrose d’une vinaigrette citron + huile d’olive maison.
            """,
            tip: "Tout en un bol dense — pas de sauce crémeuse industrielle.",
            tags: ["omad", "salade"],
            sub: .init(protocolFit: 90, satiety: 92, antiBloat: 88),
            image: "meal_debloat_omad_chicken_quinoa_bowl"
        )
    ]

    private static let snackMeals: [MealSuggestionContent] = [
        makeMeal(
            name: "Banane Skyr",
            slot: .snack,
            score: 84,
            summary: "Collation simple — banane potassium et skyr protéiné.",
            items: [
                item("Banane jaune peu tachetée", "1", "Glucide"),
                item("Skyr nature sans lactose", "150 g", "Protéine")
            ],
            prepMinutes: 3,
            prep: """
            1. Coupe la banane en rondelles.
            2. Sers avec le skyr nature sans lactose à côté.
            """,
            tip: "Idéal après le sport — sans boisson dans le repas.",
            tags: ["potassium", "protéine"],
            sub: .init(protocolFit: 84, satiety: 78, antiBloat: 86),
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
            prepMinutes: 8,
            prep: """
            1. Coupe l’ananas frais en tranches ou en cubes.
            2. Émince la dinde rôtie maison (pas de charcuterie salée).
            3. Coupe le concombre en bâtonnets.
            4. Dispose le tout dans une assiette et sers frais.
            """,
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
        summary: String,
        items: [MealSuggestionItem],
        prepMinutes: Int = 15,
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
            prepMinutes: prepMinutes,
            prepSummary: prep,
            coachTip: tip,
            tags: tags,
            imageAssetName: image,
            catalogSummary: summary
        )
    }
}
