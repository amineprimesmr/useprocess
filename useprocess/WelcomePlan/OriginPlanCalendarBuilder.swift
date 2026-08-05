import Foundation

enum OriginPlanCalendarBuilder {

    private static var weekdayLabels: [String] {
        [
            AppCopy.tSync("Lundi", en: "Monday"),
            AppCopy.tSync("Mardi", en: "Tuesday"),
            AppCopy.tSync("Mercredi", en: "Wednesday"),
            AppCopy.tSync("Jeudi", en: "Thursday"),
            AppCopy.tSync("Vendredi", en: "Friday"),
            AppCopy.tSync("Samedi", en: "Saturday"),
            AppCopy.tSync("Dimanche", en: "Sunday")
        ]
    }

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
        let labels = weekdayLabels

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
                        weekdayLabel: labels[weekday],
                        title: dayTitle(week: weekNum, weekday: weekday, labels: labels),
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
        if week == 1 {
            principles.append(AppCopy.tSync(
                "Semaine 1 : zéro ultra-transformé",
                en: "Week 1: zero ultra-processed"
            ))
        }
        if phase.id == "recomp" || phase.title.contains("Recomposition") {
            principles.append(AppCopy.tSync(
                "Déficit léger via densité — dîner léger en sel",
                en: "Light deficit via density — low-salt dinner"
            ))
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
                AppCopy.tSync(
                    "Objectif \(targets.hydrationLabel) dans la journée",
                    en: "Goal \(targets.hydrationLabel) across the day"
                ),
                AppCopy.tSync("Nutrition", en: "Nutrition"),
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
            let fallback = AppCopy.tSync("Les bases d'abord.", en: "Basics first.")
            return AppCopy.tSync(
                "Semaine 1 : exécution stricte. \(phase.objectives.first ?? fallback)",
                en: "Week 1: strict execution. \(phase.objectives.first ?? fallback)"
            )
        }
        if archetype == .habitReset {
            return AppCopy.tSync(
                "Semaine \(week) : reset debloat — consistance > perfection.",
                en: "Week \(week): debloat reset — consistency > perfection."
            )
        }
        return AppCopy.tSync(
            "Semaine \(week) : \(phase.title). Consistance > intensité.",
            en: "Week \(week): \(phase.title). Consistency > intensity."
        )
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

    private static func dayTitle(week: Int, weekday: Int, labels: [String]) -> String {
        if weekday == 6 {
            return AppCopy.tSync(
                "Semaine \(week) — Récupération",
                en: "Week \(week) — Recovery"
            )
        }
        return AppCopy.tSync(
            "Semaine \(week) — \(labels[weekday]) · Cardio & circuit",
            en: "Week \(week) — \(labels[weekday]) · Cardio & circuit"
        )
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
