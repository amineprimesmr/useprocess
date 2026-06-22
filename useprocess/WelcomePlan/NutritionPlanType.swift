import Foundation

/// Les 3 structures nutrition du Protocole Origine.
enum NutritionPlanType: String, Codable, CaseIterable, Identifiable {
    case threeMeals
    case twoMAD
    case omad

    var id: String { rawValue }

    // MARK: - Affichage

    var label: String {
        switch self {
        case .threeMeals: return "3 repas / jour"
        case .twoMAD: return "2MAD"
        case .omad: return "OMAD"
        }
    }

    var subtitle: String {
        switch self {
        case .threeMeals:
            return "Petit-déj · déjeuner · dîner — classique et tenable"
        case .twoMAD:
            return "2 repas / jour — déjeuner + dîner, sans petit-déjeuner"
        case .omad:
            return "1 repas / jour — fenêtre dense 4 à 6 h"
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
                "Petit-déjeuner (7–9 h) : protéines + fruit ou tubercule cuit",
                "Déjeuner (12–14 h) : repas principal dense — protéines + féculent complet",
                "Dîner (18–20 h) : protéines + légumes cuits — sel modéré le soir",
                "Idées repas via l'IA sur chaque créneau"
            ]
        case .twoMAD:
            return [
                "Pas de petit-déjeuner — café ou thé après le premier repas si besoin",
                "Déjeuner (12–14 h) : repas dense — protéines + tubercule ou riz complet",
                "Dîner (18–20 h) : protéines + légumes cuits — plus léger en sel",
                "Idées repas via l'IA sur déjeuner et dîner"
            ]
        case .omad:
            return [
                "1 repas dense par jour — fenêtre de 4 à 6 h (ex. 17 h–21 h)",
                "Couvre protéines, tubercule/légumes et lipides en une assiette",
                "Hydratation + minéraux en dehors de la fenêtre repas",
                "Idée repas via l'IA sur le créneau principal"
            ]
        }
    }

    var mealExamples: [String] {
        switch self {
        case .threeMeals:
            return [
                "Petit-déj : œufs brouillés + patate douce + beurre",
                "Déj : steak + patate vapeur + salade cuite",
                "Dîner : poisson + courgettes + huile d'olive"
            ]
        case .twoMAD:
            return [
                "Déj : poulet rôti + riz complet + légumes cuits",
                "Dîner : saumon + brocoli + beurre — sel léger"
            ]
        case .omad:
            return [
                "Repas unique : steak 250 g + grande patate + salade + beurre + fruit"
            ]
        }
    }

    var corePrinciples: [String] {
        switch self {
        case .threeMeals:
            return [
                "3 repas espacés — pas de grignotage entre les prises",
                "Chaque repas = protéines + glucides complets + légumes cuits"
            ]
        case .twoMAD:
            return [
                "2MAD — deux repas denses, fenêtre jeûne matinal naturelle",
                "Densifie chaque prise : ne pas compenser en volume le petit-déj manquant"
            ]
        case .omad:
            return [
                "OMAD — une fenêtre repas, le reste hydratation seule",
                "Repas unique très dense — protéines prioritaires pour le visage"
            ]
        }
    }

    /// Consignes IA par créneau (prompt coach repas).
    func slotGuidance(for slot: MealTimeSlot) -> String {
        switch self {
        case .threeMeals:
            switch slot {
            case .breakfast:
                return "Petit-déjeuner léger-dense : œufs, fromage entier ou yaourt + tubercule/fruit. Pas de céréales industrielles."
            case .lunch:
                return "Déjeuner = repas le plus copieux : protéine animale ou œufs + féculent complet + légumes cuits."
            case .dinner:
                return "Dîner plus léger en sel : protéines + légumes cuits. Éviter festin salé tardif (debloat visage)."
            case .snack:
                return "Collation rare — fruit ou fromage entier si faim réelle."
            }
        case .twoMAD:
            switch slot {
            case .lunch:
                return "Premier repas 2MAD — dense : protéines généreuses + tubercule/riz complet + légumes."
            case .dinner:
                return "Second repas 2MAD — protéines + légumes cuits, sel modéré le soir."
            default:
                return "Créneau hors protocole 2MAD — privilégie déjeuner ou dîner."
            }
        case .omad:
            return "Repas OMAD unique — très dense : protéine principale + tubercule + légumes + lipides qualité. Tout en une assiette."
        }
    }

    var aiStructureHint: String {
        switch self {
        case .threeMeals:
            return "Protocole 3 repas/jour — petit-déj protéiné, déj dense, dîner léger en sel."
        case .twoMAD:
            return "Protocole 2MAD — 2 repas (déjeuner + dîner), pas de petit-déjeuner."
        case .omad:
            return "Protocole OMAD — 1 seul repas dense dans une fenêtre de 4–6 h."
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
            return "Transition repas : \(current) → \(target) / jour — réduis progressivement sur 1 à 2 semaines"
        }
        return "Structure repas : \(target) prises / jour — densifie chaque repas (protéines + tubercule/légumes)"
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
