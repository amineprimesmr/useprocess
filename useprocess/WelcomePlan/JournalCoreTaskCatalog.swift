import Foundation

/// Journal simplifié — leviers debloat quotidiens (sans doublons).
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
            detail: AppCopy.tSync(
                "Objectif \(ProcessDailyTargets.hydrationLabel) répartis dans la journée.",
                en: "Goal \(ProcessDailyTargets.hydrationLabel) spread across the day."
            ),
            pillar: AppCopy.tSync("Nutrition", en: "Nutrition")
        )
    }

    private static func nutritionTask(dayId: String) -> OriginPlanTask {
        journalTask(
            id: nutritionTaskId(for: dayId),
            title: AppCopy.tSync("Repas debloat", en: "Debloat meal"),
            detail: AppCopy.tSync(
                "Valide au moins un repas debloat (section Repas debloat).",
                en: "Validate at least one debloat meal (Today's debloat meals section)."
            ),
            pillar: AppCopy.tSync("Nutrition", en: "Nutrition")
        )
    }

    private static func morningRoutineTask(dayId: String) -> OriginPlanTask {
        journalTask(
            id: "\(dayId).core.morning",
            title: AppCopy.tSync("Circuit lymphatique", en: "Lymphatic circuit"),
            detail: FaceMorningRoutineCatalog.journalSummary,
            pillar: AppCopy.tSync("Visage", en: "Face"),
            minutes: FaceMorningRoutineCatalog.estimatedMinutes(targets: .default)
        )
    }

    private static func sleepDebloatTask(dayId: String) -> OriginPlanTask {
        journalTask(
            id: "\(dayId).core.sleep",
            title: AppCopy.tSync("Sommeil debloat", en: "Debloat sleep"),
            detail: AppCopy.tSync(
                "Pas de repas tardif · couvre-feu écrans \(ProcessDailyTargets.screenCurfewMinutes) min · dormir sur le côté",
                en: "No late meal · screen curfew \(ProcessDailyTargets.screenCurfewMinutes) min · sleep on your side"
            ),
            pillar: AppCopy.tSync("Sommeil", en: "Sleep")
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
