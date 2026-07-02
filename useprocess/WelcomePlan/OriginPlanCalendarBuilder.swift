import Foundation

enum OriginPlanCalendarBuilder {

    private static let weekdayLabels = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]

    static func build(
        from plan: FaceOriginPlan,
        answers: [String: WelcomePlanAnswer],
        gender: Gender
    ) -> OriginProgramCalendar {
        let targets = plan.personalizedTargets ?? .default
        let sessions = plan.trainingProtocol.sessionsPerWeek
        let location = answers["training_location"]?.choiceIds.first
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
        let phaseEnds = duration.phaseWeekEnds
        let injuries = answers["injuries"]?.choiceIds ?? []

        var weeks: [OriginProgramWeek] = []
        var globalDay = 0

        for weekNum in 1...totalWeeks {
            let phase = duration.phaseBlock(for: weekNum, roadmap: plan.phaseRoadmap)
            var days: [OriginProgramDay] = []

            for weekday in 0..<7 {
                let training = trainingForDay(
                    week: weekNum,
                    weekday: weekday,
                    sessions: sessions,
                    gender: gender,
                    phase: phase,
                    plan: plan,
                    phaseEnds: phaseEnds,
                    location: location,
                    injuries: injuries
                )
                let nutrition = nutritionForDay(week: weekNum, plan: plan, phase: phase)

                let dayId = "w\(weekNum)-d\(weekday)"

                days.append(
                    OriginProgramDay(
                        id: dayId,
                        globalDayIndex: globalDay,
                        weekNumber: weekNum,
                        weekdayIndex: weekday,
                        weekdayLabel: weekdayLabels[weekday],
                        title: dayTitle(week: weekNum, weekday: weekday, hasTraining: training != nil),
                        morning: morningTasks(plan: plan, targets: targets, dayId: dayId),
                        nutrition: nutrition,
                        training: training,
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

        return OriginProgramCalendar(startedAt: Date(), weeks: weeks, buildVersion: 8)
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

    // MARK: - Training

    private static func trainingForDay(
        week: Int,
        weekday: Int,
        sessions: Int,
        gender: Gender,
        phase: OriginPlanPhaseBlock,
        plan: FaceOriginPlan,
        phaseEnds: [Int],
        location: String?,
        injuries: [String]
    ) -> OriginDayTraining? {
        let archetype = plan.assessmentSnapshot?.archetype
        if archetype == .stressRecovery && week <= (phaseEnds.first ?? 2) && sessions > 0 {
            return nil
        }

        let slots = trainingSlots(sessionsPerWeek: sessions)
        guard slots.contains(weekday) else { return nil }

        let isDeload = phaseEnds.contains(week)
        let intensityNote = isDeload ? "Semaine deload — charge légère, arrête-toi avant l'échec." : nil
        let sessionIndex = slots.firstIndex(of: weekday) ?? 0
        let progression = progressionFactor(week: week)

        if gender == .female {
            return femaleSession(
                sessionIndex: sessionIndex,
                weekday: weekday,
                week: week,
                plan: plan,
                note: intensityNote,
                location: location,
                progression: progression,
                injuries: injuries
            )
        }
        return maleSession(
            sessionIndex: sessionIndex,
            weekday: weekday,
            week: week,
            plan: plan,
            note: intensityNote,
            location: location,
            progression: progression,
            injuries: injuries
        )
    }

    private static func progressionFactor(week: Int) -> Double {
        1.0 + Double(min(week - 1, 8)) * 0.04
    }

    private static func trainingSlots(sessionsPerWeek: Int) -> [Int] {
        switch sessionsPerWeek {
        case 1: return [2]
        case 2: return [1, 4]
        case 4: return [0, 2, 4, 5]
        case 5...: return [0, 1, 3, 4, 5]
        default: return [0, 2, 4]
        }
    }

    private static func maleSession(
        sessionIndex: Int,
        weekday: Int,
        week: Int,
        plan: FaceOriginPlan,
        note: String?,
        location: String?,
        progression: Double,
        injuries: [String]
    ) -> OriginDayTraining {
        let useHome = usesHomeTrainingTemplates(location: location)
        let templates = useHome ? TrainingProgramCatalog.homeSessions() : TrainingProgramCatalog.gymSessions()
        let idx = sessionIndex % templates.count
        let template = templates[idx]
        let scaled = scaleExercises(template.exercises, factor: progression, injuries: injuries)

        return OriginDayTraining(
            sessionName: template.sessionName,
            durationMinutes: plan.trainingProtocol.sessionDurationMinutes,
            warmup: TrainingProgramCatalog.warmupForSessionIndex(
                sessionIndex,
                weekday: weekday,
                useFemale: false,
                useHome: useHome
            ),
            exercises: scaled,
            cooldown: TrainingProgramCatalog.cooldownForSession(useFemale: false),
            notes: note
        )
    }

    private static func femaleSession(
        sessionIndex: Int,
        weekday: Int,
        week: Int,
        plan: FaceOriginPlan,
        note: String?,
        location: String?,
        progression: Double,
        injuries: [String]
    ) -> OriginDayTraining {
        let templates = TrainingProgramCatalog.femaleSessions()
        let idx = sessionIndex % templates.count
        let template = templates[idx]
        return OriginDayTraining(
            sessionName: template.sessionName,
            durationMinutes: min(plan.trainingProtocol.sessionDurationMinutes, 50),
            warmup: TrainingProgramCatalog.warmupForSessionIndex(sessionIndex, weekday: weekday, useFemale: true),
            exercises: scaleExercises(template.exercises, factor: progression, injuries: injuries),
            cooldown: TrainingProgramCatalog.cooldownForSession(useFemale: true),
            notes: note
        )
    }

    private static func scaleExercises(
        _ exercises: [OriginExercise],
        factor: Double,
        injuries: [String]
    ) -> [OriginExercise] {
        exercises.map { exercise in
            var copy = exercise
            copy.sets = min(5, max(2, Int((Double(exercise.sets) * factor).rounded())))
            if injuries.contains("lower_back"), copy.name.lowercased().contains("deadlift") {
                copy.name = "Hip hinge léger"
                copy.coachingCue = "Dos neutre — amplitude contrôlée"
            }
            if injuries.contains("knees"), copy.name.lowercased().contains("squat") || copy.name.lowercased().contains("fente") {
                copy.coachingCue = "Amplitude sans douleur — genou aligné"
            }
            return copy
        }
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

    private static func dayTitle(week: Int, weekday: Int, hasTraining: Bool) -> String {
        if weekday == 6 { return "Semaine \(week) — Récupération" }
        if hasTraining { return "Semaine \(week) — \(weekdayLabels[weekday]) · Séance" }
        return "Semaine \(week) — \(weekdayLabels[weekday]) · Récup active"
    }

    private static func usesHomeTrainingTemplates(location: String?) -> Bool {
        guard let location else { return false }
        if location == "home" || location == "outdoor" { return true }
        return location == TrainingLocation.home.rawValue
            || location == TrainingLocation.outdoor.rawValue
            || location == TrainingLocation.mixed.rawValue
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
