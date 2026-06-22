import Foundation

/// Repas actuels vs cible — questionnaire Protocole Origine → plan & hub IA.
enum ProcessMealPlanConfiguration {

    static let defaultTargetMeals = NutritionPlanType.defaultType.targetMealsPerDay

    // MARK: - Parsing questionnaire

    static func parseMealsCount(from choiceId: String?) -> Int? {
        guard let choiceId, !choiceId.isEmpty else { return nil }
        if choiceId == "5plus" { return 5 }
        if let type = NutritionPlanType.from(choiceId: choiceId) {
            return type.targetMealsPerDay
        }
        return Int(choiceId)
    }

    static func readCurrentMeals(from answers: [String: WelcomePlanAnswer]) -> Int? {
        parseMealsCount(from: answers["current_meals_count"]?.choiceIds.first)
    }

    static func readTargetMeals(from answers: [String: WelcomePlanAnswer]) -> Int {
        NutritionPlanType.readTarget(from: answers).targetMealsPerDay
    }

    static func readTargetPlan(from answers: [String: WelcomePlanAnswer]) -> NutritionPlanType {
        NutritionPlanType.readTarget(from: answers)
    }

    static func mealPlanStyle(for targetMeals: Int) -> OriginMealPlanStyle {
        NutritionPlanType.from(targetMeals: targetMeals).mealPlanStyle
    }

    /// Créneaux affichés dans le hub repas IA.
    static func activeSlots(
        targetMealsPerDay: Int,
        mealPlanStyle: OriginMealPlanStyle? = nil
    ) -> [MealTimeSlot] {
        if let mealPlanStyle {
            return NutritionPlanType.from(mealPlanStyle: mealPlanStyle).slots
        }
        return NutritionPlanType.from(targetMeals: targetMealsPerDay).slots
    }

    static func slots(for plan: FaceOriginPlan) -> [MealTimeSlot] {
        plan.nutritionPlanType.slots
    }

    static func label(for mealCount: Int) -> String {
        NutritionPlanType.from(targetMeals: mealCount).label
    }

    static func label(for planType: NutritionPlanType) -> String {
        planType.label
    }

    // MARK: - Plan

    static func enrichNutritionProtocol(
        _ nutritionProtocol: inout OriginNutritionProtocol,
        answers: [String: WelcomePlanAnswer]
    ) {
        let planType = readTargetPlan(from: answers)
        let current = readCurrentMeals(from: answers)
        planType.enrich(&nutritionProtocol, currentMeals: current)
    }

    static func applyProtocol(to nutrition: inout OriginDayNutrition, nutritionProtocol nut: OriginNutritionProtocol) {
        let planType: NutritionPlanType
        if let style = nut.mealPlanStyle {
            planType = NutritionPlanType.from(mealPlanStyle: style)
        } else {
            planType = NutritionPlanType.from(targetMeals: nut.targetMealsPerDay ?? defaultTargetMeals)
        }
        planType.apply(to: &nutrition)
    }

    static func applyTargetMeals(_ target: Int, to plan: inout FaceOriginPlan) {
        NutritionPlanType.from(targetMeals: target).applyToPlan(&plan)
    }

    static func applyPlanType(_ planType: NutritionPlanType, to plan: inout FaceOriginPlan) {
        planType.applyToPlan(&plan)
    }
}

extension FaceOriginPlan {
    var configuredMealSlots: [MealTimeSlot] {
        ProcessMealPlanConfiguration.slots(for: self)
    }
}
