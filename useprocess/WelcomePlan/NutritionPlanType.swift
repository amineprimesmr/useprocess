import Foundation

/// Les 3 structures nutrition du Plan personnalisé.
enum NutritionPlanType: String, Codable, CaseIterable, Identifiable {
    case threeMeals
    case twoMAD
    case omad

    var id: String { rawValue }

    // MARK: - Affichage

    var label: String {
        switch self {
        case .threeMeals: return AppCopy.tSync("3 repas / jour", en: "3 meals / day")
        case .twoMAD: return "2MAD"
        case .omad: return "OMAD"
        }
    }

    var subtitle: String {
        switch self {
        case .threeMeals:
            return AppCopy.tSync(
                "Petit-déj · déjeuner · dîner — classique et tenable",
                en: "Breakfast · lunch · dinner — classic and sustainable"
            )
        case .twoMAD:
            return AppCopy.tSync(
                "2 repas / jour — déjeuner + dîner, sans petit-déjeuner",
                en: "2 meals / day — lunch + dinner, no breakfast"
            )
        case .omad:
            return AppCopy.tSync(
                "1 repas / jour — fenêtre dense 4 à 6 h",
                en: "1 meal / day — dense 4–6 h window"
            )
        }
    }

    var targetMealsPerDay: Int {
        switch self {
        case .threeMeals: return 3
        case .twoMAD: return 2
        case .omad: return 1
        }
    }

    var mealPlanStyle: OriginMealPlanStyle {
        switch self {
        case .threeMeals: return .standard
        case .twoMAD: return .twoMeals
        case .omad: return .omad
        }
    }

    var slots: [MealTimeSlot] {
        switch self {
        case .threeMeals: return [.breakfast, .lunch, .dinner]
        case .twoMAD: return [.lunch, .dinner]
        case .omad: return [.lunch]
        }
    }

    // MARK: - Contenu protocole

    var dailyStructure: [String] {
        switch self {
        case .threeMeals:
            return [
                AppCopy.tSync(
                    "Petit-déjeuner (7–9 h) : eau nature + protéines + fruit",
                    en: "Breakfast (7–9 am): plain water + protein + fruit"
                ),
                AppCopy.tSync(
                    "Déjeuner (12–14 h) : repas principal dense — protéines + féculent complet",
                    en: "Lunch (12–2 pm): dense main meal — protein + whole starch"
                ),
                AppCopy.tSync(
                    "Dîner (18–20 h) : protéines + légumes cuits — sel modéré le soir",
                    en: "Dinner (6–8 pm): protein + cooked veggies — moderate evening salt"
                ),
                AppCopy.tSync(
                    "Repas debloat via l'IA sur chaque créneau",
                    en: "Debloat meals via AI on each slot"
                )
            ]
        case .twoMAD:
            return [
                AppCopy.tSync(
                    "Pas de petit-déjeuner — café ou thé après le premier repas si besoin",
                    en: "No breakfast — coffee or tea after the first meal if needed"
                ),
                AppCopy.tSync(
                    "Déjeuner (12–14 h) : repas dense — protéines + tubercule ou riz complet",
                    en: "Lunch (12–2 pm): dense meal — protein + tuber or brown rice"
                ),
                AppCopy.tSync(
                    "Dîner (18–20 h) : protéines + légumes cuits — plus léger en sel",
                    en: "Dinner (6–8 pm): protein + cooked veggies — lighter on salt"
                ),
                AppCopy.tSync(
                    "Repas debloat via l'IA sur déjeuner et dîner",
                    en: "Debloat meals via AI for lunch and dinner"
                )
            ]
        case .omad:
            return [
                AppCopy.tSync(
                    "1 repas dense par jour — fenêtre de 4 à 6 h (ex. 17 h–21 h)",
                    en: "1 dense meal per day — 4–6 h window (e.g. 5–9 pm)"
                ),
                AppCopy.tSync(
                    "Couvre protéines, tubercule/légumes et lipides en une assiette",
                    en: "Cover protein, tuber/veggies, and fats on one plate"
                ),
                AppCopy.tSync(
                    "Hydratation + minéraux en dehors de la fenêtre repas",
                    en: "Hydration + minerals outside the eating window"
                ),
                AppCopy.tSync(
                    "Repas debloat via l'IA sur le créneau principal",
                    en: "Debloat meal via AI on the main slot"
                )
            ]
        }
    }

    var mealExamples: [String] {
        switch self {
        case .threeMeals:
            return [
                AppCopy.tSync(
                    "Petit-déj : grand verre d'eau + œufs + banane ou avocat",
                    en: "Breakfast: large glass of water + eggs + banana or avocado"
                ),
                AppCopy.tSync(
                    "Déj : steak grillé + pommes de terre rôties + légumes poêlés",
                    en: "Lunch: grilled steak + roasted potatoes + sautéed veggies"
                ),
                AppCopy.tSync(
                    "Dîner : poisson + courgettes + huile d'olive",
                    en: "Dinner: fish + zucchini + olive oil"
                )
            ]
        case .twoMAD:
            return [
                AppCopy.tSync(
                    "Déj : poulet rôti + riz complet + légumes cuits",
                    en: "Lunch: roast chicken + brown rice + cooked veggies"
                ),
                AppCopy.tSync(
                    "Dîner : saumon + courgette + huile d'olive — sel léger",
                    en: "Dinner: salmon + zucchini + olive oil — light salt"
                )
            ]
        case .omad:
            return [
                AppCopy.tSync(
                    "Repas unique : steak 250 g + grande patate + salade + huile d'olive + fruit",
                    en: "Single meal: 250 g steak + large potato + salad + olive oil + fruit"
                )
            ]
        }
    }

    var corePrinciples: [String] {
        switch self {
        case .threeMeals:
            return [
                AppCopy.tSync(
                    "3 repas espacés — pas de grignotage entre les prises",
                    en: "3 spaced meals — no snacking between"
                ),
                AppCopy.tSync(
                    "Chaque repas = protéines + glucides complets + légumes cuits",
                    en: "Each meal = protein + whole carbs + cooked veggies"
                )
            ]
        case .twoMAD:
            return [
                AppCopy.tSync(
                    "2MAD — deux repas denses, fenêtre jeûne matinal naturelle",
                    en: "2MAD — two dense meals, natural morning fast window"
                ),
                AppCopy.tSync(
                    "Densifie chaque prise : ne pas compenser en volume le petit-déj manquant",
                    en: "Densify each meal: don't compensate volume for the missing breakfast"
                )
            ]
        case .omad:
            return [
                AppCopy.tSync(
                    "OMAD — une fenêtre repas, le reste hydratation seule",
                    en: "OMAD — one eating window, hydration only otherwise"
                ),
                AppCopy.tSync(
                    "Repas unique très dense — protéines prioritaires pour le visage",
                    en: "Very dense single meal — protein first for the face"
                )
            ]
        }
    }

    /// Consignes IA par créneau (prompt coach repas).
    func slotGuidance(for slot: MealTimeSlot) -> String {
        switch self {
        case .threeMeals:
            switch slot {
            case .breakfast:
                return AppCopy.tSync(
                    "Petit-déjeuner simple : grand verre d'eau nature, œufs + fruit ou avocat. Électrolytes seulement après forte transpiration.",
                    en: "Simple breakfast: large glass of plain water, eggs + fruit or avocado. Electrolytes only after heavy sweating."
                )
            case .lunch:
                return AppCopy.tSync(
                    "Déjeuner = repas le plus copieux : protéine animale ou œufs + féculent complet + légumes cuits.",
                    en: "Lunch = biggest meal: animal protein or eggs + whole starch + cooked veggies."
                )
            case .dinner:
                return AppCopy.tSync(
                    "Dîner plus léger en sel : protéines + légumes cuits. Éviter festin salé tardif (debloat visage).",
                    en: "Dinner lighter on salt: protein + cooked veggies. Avoid late salty feasts (face debloat)."
                )
            case .snack:
                return AppCopy.tSync(
                    "Collation rare — fruit ou skyr sans lactose si faim réelle.",
                    en: "Rare snack — fruit or lactose-free skyr if truly hungry."
                )
            }
        case .twoMAD:
            switch slot {
            case .lunch:
                return AppCopy.tSync(
                    "Premier repas 2MAD — dense : protéines généreuses + tubercule/riz complet + légumes.",
                    en: "First 2MAD meal — dense: generous protein + tuber/brown rice + veggies."
                )
            case .dinner:
                return AppCopy.tSync(
                    "Second repas 2MAD — protéines + légumes cuits, sel modéré le soir.",
                    en: "Second 2MAD meal — protein + cooked veggies, moderate evening salt."
                )
            default:
                return AppCopy.tSync(
                    "Créneau hors protocole 2MAD — privilégie déjeuner ou dîner.",
                    en: "Slot outside 2MAD protocol — prefer lunch or dinner."
                )
            }
        case .omad:
            return AppCopy.tSync(
                "Repas OMAD unique — très dense : protéine principale + tubercule + légumes + lipides qualité. Tout en une assiette.",
                en: "Single OMAD meal — very dense: main protein + tuber + veggies + quality fats. All on one plate."
            )
        }
    }

    var aiStructureHint: String {
        switch self {
        case .threeMeals:
            return AppCopy.tSync(
                "Protocole 3 repas/jour — petit-déj protéiné, déj dense, dîner léger en sel.",
                en: "3 meals/day protocol — protein breakfast, dense lunch, low-salt dinner."
            )
        case .twoMAD:
            return AppCopy.tSync(
                "Protocole 2MAD — 2 repas (déjeuner + dîner), pas de petit-déjeuner.",
                en: "2MAD protocol — 2 meals (lunch + dinner), no breakfast."
            )
        case .omad:
            return AppCopy.tSync(
                "Protocole OMAD — 1 seul repas dense dans une fenêtre de 4–6 h.",
                en: "OMAD protocol — 1 dense meal in a 4–6 h window."
            )
        }
    }

    // MARK: - Parsing

    static let defaultType: NutritionPlanType = .threeMeals

    static func from(choiceId: String?) -> NutritionPlanType? {
        guard let choiceId, !choiceId.isEmpty else { return nil }
        switch choiceId {
        case "1": return .omad
        case "2": return .twoMAD
        case "3": return .threeMeals
        case "4": return .threeMeals // legacy « 3 repas + collation »
        default: return nil
        }
    }

    static func from(targetMeals: Int) -> NutritionPlanType {
        switch targetMeals {
        case 1: return .omad
        case 2: return .twoMAD
        default: return .threeMeals
        }
    }

    static func from(mealPlanStyle: OriginMealPlanStyle) -> NutritionPlanType {
        switch mealPlanStyle {
        case .omad: return .omad
        case .twoMeals: return .twoMAD
        case .standard: return .threeMeals
        }
    }

    static func readTarget(from answers: [String: WelcomePlanAnswer]) -> NutritionPlanType {
        if let type = from(choiceId: answers["target_meals_count"]?.choiceIds.first) {
            return type
        }
        let meals = ProcessMealPlanConfiguration.parseMealsCount(
            from: answers["target_meals_count"]?.choiceIds.first
        ) ?? defaultType.targetMealsPerDay
        return from(targetMeals: meals)
    }

    static func readCurrentMeals(from answers: [String: WelcomePlanAnswer]) -> Int? {
        ProcessMealPlanConfiguration.parseMealsCount(
            from: answers["current_meals_count"]?.choiceIds.first
        )
    }

    // MARK: - Application plan

    func enrich(
        _ nutritionProtocol: inout OriginNutritionProtocol,
        currentMeals: Int?,
        extraPrinciples: [String] = []
    ) {
        nutritionProtocol.targetMealsPerDay = targetMealsPerDay
        nutritionProtocol.mealPlanStyle = mealPlanStyle
        nutritionProtocol.dailyStructure = dailyStructure
        nutritionProtocol.mealExamples = mealExamples
        nutritionProtocol.currentMealsPerDay = currentMeals

        for principle in corePrinciples.reversed() {
            if !nutritionProtocol.principles.contains(where: { $0 == principle }) {
                nutritionProtocol.principles.insert(principle, at: 0)
            }
        }

        if let transition = Self.transitionPrinciple(current: currentMeals, target: targetMealsPerDay) {
            if !nutritionProtocol.principles.contains(where: { $0 == transition }) {
                nutritionProtocol.principles.insert(transition, at: 0)
            }
        }

        for principle in extraPrinciples where !nutritionProtocol.principles.contains(principle) {
            nutritionProtocol.principles.append(principle)
        }
    }

    func apply(to nutrition: inout OriginDayNutrition) {
        nutrition.mealPlanStyle = mealPlanStyle
        nutrition.omadMeal = nil
        nutrition.breakfast = ""
        nutrition.lunch = ""
        nutrition.dinner = ""
        nutrition.snack = nil
    }

    func applyToPlan(_ plan: inout FaceOriginPlan) {
        enrich(&plan.nutritionProtocol, currentMeals: plan.nutritionProtocol.currentMealsPerDay)
        for weekIndex in plan.calendar.weeks.indices {
            for dayIndex in plan.calendar.weeks[weekIndex].days.indices {
                apply(to: &plan.calendar.weeks[weekIndex].days[dayIndex].nutrition)
            }
        }
        plan.lastUpdated = Date()
    }

    private static func transitionPrinciple(current: Int?, target: Int) -> String? {
        guard let current, current != target else { return nil }
        if current > target {
            return AppCopy.tSync(
                "Transition repas : \(current) → \(target) / jour — réduis progressivement sur 1 à 2 semaines",
                en: "Meal transition: \(current) → \(target) / day — taper gradually over 1–2 weeks"
            )
        }
        return AppCopy.tSync(
            "Structure repas : \(target) prises / jour — densifie chaque repas (protéines + tubercule/légumes)",
            en: "Meal structure: \(target) intakes / day — densify each meal (protein + tuber/veggies)"
        )
    }
}

extension FaceOriginPlan {
    var nutritionPlanType: NutritionPlanType {
        if let style = nutritionProtocol.mealPlanStyle {
            return NutritionPlanType.from(mealPlanStyle: style)
        }
        return NutritionPlanType.from(targetMeals: nutritionProtocol.targetMealsPerDay ?? 3)
    }
}
