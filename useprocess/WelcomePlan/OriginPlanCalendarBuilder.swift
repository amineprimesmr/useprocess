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
                        posture: postureTasks(plan: plan, targets: targets, dayId: dayId),
                        face: faceTasks(plan: plan, week: weekNum, totalWeeks: totalWeeks, targets: targets, dayId: dayId, weekday: weekday),
                        evening: eveningTasks(plan: plan, answers: answers, targets: targets, dayId: dayId),
                        sleep: OriginDaySleep(
                            targetBedtime: bedtime,
                            targetWake: wake,
                            targetHours: max(hours, targets.sleepHours),
                            eveningActions: Array(plan.sleepProtocol.eveningRoutine.prefix(3)),
                            morningActions: Array(plan.sleepProtocol.morningRoutine.prefix(3))
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

        return OriginProgramCalendar(startedAt: Date(), weeks: weeks, buildVersion: 6)
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
        let intensityNote = isDeload ? "Semaine deload — RPE 5–6, pas de failure." : nil
        let sessionIndex = slots.firstIndex(of: weekday) ?? 0
        let progression = progressionFactor(week: week)

        if gender == .female {
            return femaleSession(
                sessionIndex: sessionIndex,
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
        week: Int,
        plan: FaceOriginPlan,
        note: String?,
        location: String?,
        progression: Double,
        injuries: [String]
    ) -> OriginDayTraining {
        let useHome = location == "home" || location == "outdoor"
        let templates: [(String, [OriginExercise])] = useHome ? homeMaleTemplates() : gymMaleTemplates()
        let idx = sessionIndex % templates.count
        let (name, exercises) = templates[idx]
        let scaled = scaleExercises(exercises, factor: progression, injuries: injuries)

        return OriginDayTraining(
            sessionName: name,
            durationMinutes: plan.trainingProtocol.sessionDurationMinutes,
            warmup: ["5 min marche ou vélo", "Mobilité épaules + hanches 5 min"],
            exercises: scaled,
            cooldown: ["Marche lente 3 min"],
            notes: note
        )
    }

    private static func femaleSession(
        sessionIndex: Int,
        week: Int,
        plan: FaceOriginPlan,
        note: String?,
        location: String?,
        progression: Double,
        injuries: [String]
    ) -> OriginDayTraining {
        let templates: [(String, [OriginExercise])] = [
            ("Fessiers + hanches", [
                ex("Hip thrust", sets: 4, reps: "10–12", group: "Fessiers"),
                ex("Fentes marchées", sets: 3, reps: "10/jambe", group: "Jambes"),
                ex("Abduction hanche", sets: 3, reps: "15", group: "Fessiers"),
                ex("Planche", sets: 3, reps: "45 s", group: "Core")
            ]),
            ("Haut du corps + posture", [
                ex("Tirage vertical", sets: 3, reps: "10–12", group: "Dos"),
                ex("Push-ups inclinés", sets: 3, reps: "8–12", group: "Pecs"),
                ex("Face pulls", sets: 3, reps: "15", group: "Posture"),
                ex("Dead bug", sets: 3, reps: "10/côté", group: "Core")
            ])
        ]
        let idx = sessionIndex % templates.count
        let (name, exercises) = templates[idx]
        return OriginDayTraining(
            sessionName: name,
            durationMinutes: min(plan.trainingProtocol.sessionDurationMinutes, 50),
            warmup: ["Marche 5 min", "Activation fessiers 5 min"],
            exercises: scaleExercises(exercises, factor: progression, injuries: injuries),
            cooldown: ["Étirement fessiers 2 min"],
            notes: note
        )
    }

    private static func gymMaleTemplates() -> [(String, [OriginExercise])] {
        [
            ("Push — épaules, trapèzes, pec", [
                ex("Développé haltères", sets: 4, reps: "8–10", group: "Épaules"),
                ex("Élévations latérales", sets: 3, reps: "12–15", group: "Deltoïdes"),
                ex("Face pulls", sets: 3, reps: "15–20", group: "Posture"),
                ex("Shrugs", sets: 3, reps: "12–15", group: "Trapèzes")
            ]),
            ("Pull — dos, rear delts", [
                ex("Tractions / tirage", sets: 4, reps: "6–10", group: "Dos"),
                ex("Rowing", sets: 3, reps: "8–12", group: "Dos"),
                ex("Face pulls", sets: 3, reps: "15", group: "Posture"),
                ex("Curl marteau", sets: 2, reps: "12", group: "Biceps")
            ]),
            ("Jambes + chaîne postérieure", [
                ex("Squat / goblet squat", sets: 4, reps: "8–10", group: "Jambes"),
                ex("Romanian deadlift", sets: 3, reps: "8–10", group: "Fessiers"),
                ex("Hip thrust", sets: 3, reps: "10–12", group: "Fessiers"),
                ex("Mollets debout", sets: 3, reps: "15", group: "Mollets")
            ])
        ]
    }

    private static func homeMaleTemplates() -> [(String, [OriginExercise])] {
        [
            ("Push maison", [
                ex("Pompes inclinées", sets: 4, reps: "10–15", group: "Pecs"),
                ex("Pike push-ups", sets: 3, reps: "8–12", group: "Épaules"),
                ex("Élévations bouteilles", sets: 3, reps: "15", group: "Deltoïdes"),
                ex("Face pulls élastique", sets: 3, reps: "15", group: "Posture")
            ]),
            ("Pull maison", [
                ex("Tractions / row élastique", sets: 4, reps: "8–12", group: "Dos"),
                ex("Reverse fly élastique", sets: 3, reps: "15", group: "Posture"),
                ex("Superman hold", sets: 3, reps: "30 s", group: "Dos"),
                ex("Planche", sets: 3, reps: "45 s", group: "Core")
            ]),
            ("Jambes maison", [
                ex("Goblet squat", sets: 4, reps: "12–15", group: "Jambes"),
                ex("Fentes", sets: 3, reps: "10/jambe", group: "Jambes"),
                ex("Hip thrust au sol", sets: 3, reps: "15", group: "Fessiers"),
                ex("Mollets marche", sets: 3, reps: "20", group: "Mollets")
            ])
        ]
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

    private static func ex(_ name: String, sets: Int, reps: String, group: String) -> OriginExercise {
        OriginExercise(
            id: UUID().uuidString,
            name: name,
            sets: sets,
            reps: reps,
            restSeconds: 90,
            coachingCue: "Contrôle > ego",
            muscleGroup: group
        )
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
            task("Lumière matinale", "\(targets.morningLightMinutes) min soleil ou lumière naturelle", "Hormones", targets.morningLightMinutes, dayId: dayId),
            task(ProcessHydrationGuide.dailyTaskTitle, "Objectif \(targets.hydrationLabel) dans la journée", "Nutrition", nil, dayId: dayId),
            task(
                "Eau froide sur le visage",
                "\(targets.coldFaceRinseSeconds) sec — front, joues, contour des yeux.",
                "Visage",
                nil,
                dayId: dayId
            ),
            task("Alimentation parfaite", alimentationParfaiteDetail(plan: plan), "Nutrition", nil, dayId: dayId)
        ]
    }

    private static func alimentationParfaiteDetail(plan: FaceOriginPlan) -> String {
        plan.nutritionProtocol.principles.prefix(2).joined(separator: " · ")
            .nilIfEmpty ?? "Repas denses — valide ton repas du jour."
    }

    private static func postureTasks(
        plan: FaceOriginPlan,
        targets: OriginPersonalizedDailyTargets,
        dayId: String
    ) -> [OriginPlanTask] {
        var tasks: [OriginPlanTask] = []
        if let check = plan.postureProtocol.dailyChecks.first {
            tasks.append(task("Posture", check, "Posture", 5, dayId: dayId))
        }
        return tasks
    }

    private static func faceTasks(
        plan: FaceOriginPlan,
        week: Int,
        totalWeeks: Int,
        targets: OriginPersonalizedDailyTargets,
        dayId: String,
        weekday: Int
    ) -> [OriginPlanTask] {
        var tasks: [OriginPlanTask] = [
            task(
                "Massage lymphatique",
                "\(targets.lymphFaceMassageMinutes) min sous les yeux vers les oreilles",
                "Visage",
                targets.lymphFaceMassageMinutes,
                dayId: dayId
            )
        ]

        let scanWeeks = scanWeeksForPlan(totalWeeks: totalWeeks)
        if scanWeeks.contains(week), weekday == 0 {
            tasks.insert(
                task("Scan visage", "Photo debloat — compare avec le baseline", "Visage", 2, dayId: dayId),
                at: 0
            )
        }
        return tasks
    }

    private static func scanWeeksForPlan(totalWeeks: Int) -> Set<Int> {
        if totalWeeks <= 1 { return [1] }
        if totalWeeks <= 3 { return [1, totalWeeks] }
        return [1, max(2, totalWeeks / 2), totalWeeks]
    }

    private static func eveningTasks(
        plan: FaceOriginPlan,
        answers: [String: WelcomePlanAnswer],
        targets: OriginPersonalizedDailyTargets,
        dayId: String
    ) -> [OriginPlanTask] {
        var tasks: [OriginPlanTask] = []

        if answers["screen_before_bed"]?.choiceIds.first == "yes" {
            tasks.append(
                task(
                    "Couvre-feu écrans",
                    "\(ProcessDailyTargets.screenCurfewMinutes) min avant coucher — mode avion",
                    "Sommeil",
                    nil,
                    dayId: dayId
                )
            )
        }

        if answers["alcohol_frequency"]?.choiceIds.first == "often"
            || answers["alcohol_frequency"]?.choiceIds.first == "weekly" {
            tasks.append(
                task("Alcool", "Soir sans alcool — debloat visage garanti", "Nutrition", nil, dayId: dayId)
            )
        }

        return tasks
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
