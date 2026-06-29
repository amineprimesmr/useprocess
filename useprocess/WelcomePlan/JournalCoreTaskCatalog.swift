import Foundation

/// Journal simplifié — 4 leviers debloat quotidiens (sans doublons).
enum JournalCoreTaskCatalog {

    static let nutritionTaskIdSuffix = "core.nutrition"

    static func coreTasks(for dayId: String) -> [OriginPlanTask] {
        [
            hydrationTask(dayId: dayId),
            nutritionTask(dayId: dayId),
            morningRoutineTask(dayId: dayId),
            sleepDebloatTask(dayId: dayId)
        ]
    }

    static func extendedTasks(day: OriginProgramDay, plan: FaceOriginPlan) -> [OriginPlanTask] {
        OriginPlanPresenter.visibleJournalTasks(day.posture)
    }

    static func allCompletableTasks(day: OriginProgramDay, plan: FaceOriginPlan) -> [OriginPlanTask] {
        coreTasks(for: day.id) + extendedTasks(day: day, plan: plan)
    }

    static func nutritionTaskId(for dayId: String) -> String {
        "\(dayId).\(nutritionTaskIdSuffix)"
    }

    static func isNutritionSatisfied(plan: FaceOriginPlan, dayId: String) -> Bool {
        guard let slots = plan.progress.validatedMealsBySlot[dayId] else {
            return plan.progress.validatedMeals[dayId] != nil
        }
        return !slots.isEmpty
    }

    // MARK: - Core tasks

    private static func hydrationTask(dayId: String) -> OriginPlanTask {
        journalTask(
            id: "\(dayId).core.hydrate",
            title: ProcessHydrationGuide.dailyTaskTitle,
            detail: "Objectif \(ProcessDailyTargets.hydrationLabel) répartis dans la journée.",
            pillar: "Nutrition"
        )
    }

    private static func nutritionTask(dayId: String) -> OriginPlanTask {
        journalTask(
            id: nutritionTaskId(for: dayId),
            title: "Repas debloat",
            detail: "Valide au moins un repas debloat (section Repas debloat).",
            pillar: "Nutrition"
        )
    }

    private static func morningRoutineTask(dayId: String) -> OriginPlanTask {
        journalTask(
            id: "\(dayId).core.morning",
            title: "Routine matin visage",
            detail: "\(ProcessDailyTargets.morningLightMinutes) min lumière · glaçons sur le visage",
            pillar: "Visage",
            minutes: ProcessDailyTargets.morningLightMinutes + 1
        )
    }

    private static func sleepDebloatTask(dayId: String) -> OriginPlanTask {
        journalTask(
            id: "\(dayId).core.sleep",
            title: "Sommeil debloat",
            detail: "Pas de repas tardif · couvre-feu écrans \(ProcessDailyTargets.screenCurfewMinutes) min · dormir sur le côté",
            pillar: "Sommeil"
        )
    }

    private static func journalTask(
        id: String,
        title: String,
        detail: String,
        pillar: String,
        minutes: Int? = nil
    ) -> OriginPlanTask {
        OriginPlanTask(
            id: id,
            title: title,
            detail: detail,
            pillar: pillar,
            durationMinutes: minutes,
            isOptional: false
        )
    }
}
