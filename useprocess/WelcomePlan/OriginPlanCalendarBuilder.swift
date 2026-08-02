import Foundation

enum OriginPlanCalendarBuilder {

    private static let weekdayLabels = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]

    static func build(
        from plan: FaceOriginPlan,
        answers: [String: WelcomePlanAnswer],
        gender: Gender
    ) -> OriginProgramCalendar {
        let targets = plan.personalizedTargets ?? .default
        let bedtime = answers["bedtime"]?.timeValue ?? "22:30"
        let wake = answers["wake_time"]?.timeValue ?? "07:00"
        let hours = WelcomePlanGenerator.computedSleepHours(bedtime: bedtime, wake: wake)
        let totalWeeks = max(plan.totalWeeks, 1)
        let duration = OriginPlanDuration(
            minWeeks: plan.durationMinWeeks,
            maxWeeks: plan.durationMaxWeeks,
            totalWeeks: totalWeeks,
            archetype: plan.assessmentSnapshot?.archetype
        )

        var weeks: [OriginProgramWeek] = []
        var globalDay = 0

        for weekNum in 1...totalWeeks {
            let phase = duration.phaseBlock(for: weekNum, roadmap: plan.phaseRoadmap)
            var days: [OriginProgramDay] = []

            for weekday in 0..<7 {
                // Plus de séances muscu (push/pull/legs) — le cardio du jour vit dans l’UI Accueil.
                let nutrition = nutritionForDay(week: weekNum, plan: plan, phase: phase)

                let dayId = "w\(weekNum)-d\(weekday)"

                days.append(
                    OriginProgramDay(
                        id: dayId,
                        globalDayIndex: globalDay,
                        weekNumber: weekNum,
                        weekdayIndex: weekday,
                        weekdayLabel: weekdayLabels[weekday],
                        title: dayTitle(week: weekNum, weekday: weekday),
                        morning: morningTasks(plan: plan, targets: targets, dayId: dayId),
                        nutrition: nutrition,
                        training: nil,
                        posture: OriginPlanDailyTaskCatalog.postureTasks(plan: plan, dayId: dayId),
                        face: [],
                        evening: [],
                        sleep: OriginDaySleep(
                            targetBedtime: bedtime,
                            targetWake: wake,
                            targetHours: max(hours, targets.sleepHours),
                            eveningActions: sleepEveningActions(plan: plan, answers: answers),
                            morningActions: Array(plan.sleepProtocol.morningRoutine.prefix(4))
                        ),
                        mindset: mindsetForWeek(weekNum, phase: phase, archetype: plan.assessmentSnapshot?.archetype)
                    )
                )
                globalDay += 1
            }

            weeks.append(
                OriginProgramWeek(
                    id: "week-\(weekNum)",
                    weekNumber: weekNum,
                    theme: phase.title,
                    phaseTitle: phase.weeksRange,
                    focus: phase.objectives.first ?? plan.primaryFaceGoal,
                    days: days
                )
            )
        }

        return OriginProgramCalendar(startedAt: Date(), weeks: weeks, buildVersion: 10)
    }

    private static func sleepEveningActions(
        plan: FaceOriginPlan,
        answers: [String: WelcomePlanAnswer]
    ) -> [String] {
        let checklist = SideSleepIntelligenceGuide.checklistEveningTasks(
            answers: answers,
            sleepProtocol: plan.sleepProtocol
        )
        if !checklist.isEmpty {
            return checklist
        }
        return Array(plan.sleepProtocol.eveningRoutine.prefix(5))
    }

    // MARK: - Nutrition

    private static func nutritionForDay(
        week: Int,
        plan: FaceOriginPlan,
        phase: OriginPlanPhaseBlock
    ) -> OriginDayNutrition {
        var principles = Array(plan.nutritionProtocol.principles.prefix(3))
        if week == 1 { principles.append("Semaine 1 : zéro ultra-transformé") }
        if phase.id == "recomp" || phase.title.contains("Recomposition") {
            principles.append("Déficit léger via densité — dîner léger en sel")
        }

        return OriginDayNutrition(
            breakfast: "",
            lunch: "",
            dinner: "",
            snack: nil,
            hydration: plan.nutritionProtocol.hydrationGuide,
            principles: principles,
            foodsToday: Array(plan.nutritionProtocol.foodsToPrioritize.prefix(4))
        ).configured(from: plan.nutritionProtocol)
    }

    // MARK: - Daily tasks

    private static func morningTasks(
        plan: FaceOriginPlan,
        targets: OriginPersonalizedDailyTargets,
        dayId: String
    ) -> [OriginPlanTask] {
        [
            task(
                ProcessHydrationGuide.dailyTaskTitle,
                "Objectif \(targets.hydrationLabel) dans la journée",
                "Nutrition",
                nil,
                dayId: dayId
            )
        ]
    }

    private static func mindsetForWeek(
        _ week: Int,
        phase: OriginPlanPhaseBlock,
        archetype: OriginPlanArchetype?
    ) -> String {
        if week == 1 {
            return "Semaine 1 : exécution stricte. \(phase.objectives.first ?? "Les bases d'abord.")"
        }
        if archetype == .habitReset {
            return "Semaine \(week) : reset debloat — consistance > perfection."
        }
        return "Semaine \(week) : \(phase.title). Consistance > intensité."
    }

    private static func task(_ title: String, _ detail: String, _ pillar: String, _ minutes: Int?, dayId: String) -> OriginPlanTask {
        OriginPlanTask(
            id: "\(dayId).\(stableSlug(title))",
            title: title,
            detail: detail,
            pillar: pillar,
            durationMinutes: minutes,
            isOptional: false
        )
    }

    private static func stableSlug(_ title: String) -> String {
        title
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "·", with: "")
            .replacingOccurrences(of: "'", with: "")
    }

    private static func dayTitle(week: Int, weekday: Int) -> String {
        if weekday == 6 { return "Semaine \(week) — Récupération" }
        return "Semaine \(week) — \(weekdayLabels[weekday]) · Cardio & circuit"
    }
}

private extension OriginDayNutrition {
    func configured(from nutritionProtocol: OriginNutritionProtocol) -> OriginDayNutrition {
        var copy = self
        ProcessMealPlanConfiguration.applyProtocol(to: &copy, nutritionProtocol: nutritionProtocol)
        return copy
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
