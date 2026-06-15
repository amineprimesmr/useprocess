import Foundation

enum OriginPlanCalendarBuilder {

    private static let weekdayLabels = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]

    static func build(
        from plan: FaceOriginPlan,
        answers: [String: WelcomePlanAnswer],
        gender: Gender
    ) -> OriginProgramCalendar {
        let sessions = plan.trainingProtocol.sessionsPerWeek
        let bedtime = answers["bedtime"]?.timeValue ?? plan.sleepProtocol.bedtimeWindow.replacingOccurrences(of: "Cible ", with: "").components(separatedBy: " ").first ?? "22:30"
        let wake = answers["wake_time"]?.timeValue ?? plan.sleepProtocol.wakeWindow.replacingOccurrences(of: "Cible ", with: "").components(separatedBy: " ").first ?? "07:00"
        let hours = WelcomePlanGenerator.computedSleepHours(bedtime: bedtime, wake: wake)

        var weeks: [OriginProgramWeek] = []
        var globalDay = 0

        for weekNum in 1...13 {
            let phase = phaseForWeek(weekNum)
            var days: [OriginProgramDay] = []

            for weekday in 0..<7 {
                let training = trainingForDay(
                    week: weekNum,
                    weekday: weekday,
                    sessions: sessions,
                    gender: gender,
                    phase: phase,
                    plan: plan
                )
                let nutrition = nutritionForDay(
                    week: weekNum,
                    weekday: weekday,
                    phase: phase,
                    plan: plan,
                    answers: answers
                )

                days.append(
                    OriginProgramDay(
                        id: "w\(weekNum)-d\(weekday)",
                        globalDayIndex: globalDay,
                        weekNumber: weekNum,
                        weekdayIndex: weekday,
                        weekdayLabel: weekdayLabels[weekday],
                        title: dayTitle(week: weekNum, weekday: weekday, hasTraining: training != nil),
                        morning: morningTasks(plan: plan, phase: phase, weekday: weekday),
                        nutrition: nutrition,
                        training: training,
                        posture: postureTasks(plan: plan, phase: phase, weekday: weekday),
                        face: faceTasks(plan: plan, phase: phase),
                        evening: eveningTasks(plan: plan, answers: answers),
                        sleep: OriginDaySleep(
                            targetBedtime: bedtime,
                            targetWake: wake,
                            targetHours: hours,
                            eveningActions: Array(plan.sleepProtocol.eveningRoutine.prefix(3)),
                            morningActions: Array(plan.sleepProtocol.morningRoutine.prefix(3))
                        ),
                        mindset: weekNum <= 3
                            ? "Semaine \(weekNum) : les bases d'abord. Pas d'optimisation prématurée."
                            : "Semaine \(weekNum) : \(phase.title). Consistance > intensité."
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

        return OriginProgramCalendar(startedAt: Date(), weeks: weeks)
    }

    // MARK: - Phase

    private static func phaseForWeek(_ week: Int) -> OriginPlanPhaseBlock {
        switch week {
        case 1...3:
            return .init(id: "p1", weeksRange: "Semaines 1–3", title: "Fondations — Reset biologique", objectives: ["Rythme circadien", "Alimentation dense", "Mewing (langue au palais)"], habits: ["Couvre-feu lumière", "Repas protéinés", "Marche"])
        case 4...6:
            return .init(id: "p2", weeksRange: "Semaines 4–6", title: "Hormones & digestion", objectives: ["Digestion optimale", "Stress ↓", "Hydratation minérale"], habits: ["Bouillon", "Routine soir", "Mobilité"])
        case 7...10:
            return .init(id: "p3", weeksRange: "Semaines 7–10", title: "Entraînement & composition", objectives: ["Progressive overload", "Composition corporelle", "Chaîne postérieure"], habits: ["Séances loguées", "Sommeil 7,5 h+", "Scan mensuel"])
        default:
            return .init(id: "p4", weeksRange: "Semaines 11–13", title: "Affinage visage & consolidation", objectives: ["Affiner si besoin", "Fascias maxillaire / SCM / nuque", "Ancrage long terme"], habits: ["Bilan photos", "Maintien 80 % bases", "Plan post-13 sem"])
        }
    }

    // MARK: - Training

    private static func trainingForDay(
        week: Int,
        weekday: Int,
        sessions: Int,
        gender: Gender,
        phase: OriginPlanPhaseBlock,
        plan: FaceOriginPlan
    ) -> OriginDayTraining? {
        let slots = trainingSlots(sessionsPerWeek: sessions)
        guard slots.contains(weekday) else { return nil }

        let isDeload = week == 4 || week == 8
        let intensityNote = isDeload ? "Semaine deload — RPE 5–6, pas de failure." : nil
        let sessionIndex = slots.firstIndex(of: weekday) ?? 0

        if gender == .female {
            return femaleSession(sessionIndex: sessionIndex, week: week, plan: plan, note: intensityNote)
        }
        return maleSession(sessionIndex: sessionIndex, week: week, plan: plan, note: intensityNote)
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

    private static func maleSession(sessionIndex: Int, week: Int, plan: FaceOriginPlan, note: String?) -> OriginDayTraining {
        let templates: [(String, [OriginExercise])] = [
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
        let idx = sessionIndex % templates.count
        let (name, exercises) = templates[idx]
        return OriginDayTraining(
            sessionName: name,
            durationMinutes: plan.trainingProtocol.sessionDurationMinutes,
            warmup: ["5 min marche ou vélo", "Mobilité épaules + hanches 5 min"],
            exercises: exercises,
            cooldown: ["Étirement psoas 2 min", "Respiration nasale 2 min"],
            notes: note
        )
    }

    private static func femaleSession(sessionIndex: Int, week: Int, plan: FaceOriginPlan, note: String?) -> OriginDayTraining {
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
            exercises: exercises,
            cooldown: ["Étirement fessiers 2 min"],
            notes: note
        )
    }

    private static func ex(_ name: String, sets: Int, reps: String, group: String) -> OriginExercise {
        OriginExercise(id: UUID().uuidString, name: name, sets: sets, reps: reps, restSeconds: 90, coachingCue: "Contrôle > ego", muscleGroup: group)
    }

    // MARK: - Nutrition

    private static func nutritionForDay(
        week: Int,
        weekday: Int,
        phase: OriginPlanPhaseBlock,
        plan: FaceOriginPlan,
        answers: [String: WelcomePlanAnswer]
    ) -> OriginDayNutrition {
        let examples = plan.nutritionProtocol.mealExamples
        let e0 = examples.indices.contains(0) ? examples[0] : "Œufs + patate douce"
        let e1 = examples.indices.contains(1) ? examples[1] : "Steak + tubercule vapeur"
        let e2 = examples.indices.contains(2) ? examples[2] : "Poisson + légumes cuits"
        let isTrainingDay = weekday == 0 || weekday == 2 || weekday == 4

        var principles = Array(plan.nutritionProtocol.principles.prefix(2))
        if week <= 3 { principles.append("Phase fondations : zéro ultra-transformé") }
        if week >= 7 { principles.append("Ajuster portions selon énergie et composition") }

        return OriginDayNutrition(
            breakfast: e0,
            lunch: e1,
            dinner: isTrainingDay ? e1 : e2,
            snack: weekday == 5 ? "Fromage entier + miel" : "Fruit modéré (1 max)",
            hydration: plan.nutritionProtocol.hydrationGuide,
            principles: principles,
            foodsToday: Array(plan.nutritionProtocol.foodsToPrioritize.prefix(4))
        )
    }

    // MARK: - Daily tasks

    private static func morningTasks(plan: FaceOriginPlan, phase: OriginPlanPhaseBlock, weekday: Int) -> [OriginPlanTask] {
        var tasks: [OriginPlanTask] = [
            task("Lumière matinale", "10–20 min soleil ou lumière naturelle", "Hormones", 15),
            task("Hydratation + sel/citron", "Réveil mineral — pas café immédiat", "Nutrition", 2),
            task("Mewing matinal", "Langue au palais, lèvres closes, respiration nasale — 5 min actif", "Posture", 5)
        ]
        if weekday == 0 {
            tasks.append(task("Bilan semaine", "5 min : sommeil, digestion, visage, énergie", "Mindset", 5))
        }
        return tasks
    }

    private static func postureTasks(plan: FaceOriginPlan, phase: OriginPlanPhaseBlock, weekday: Int) -> [OriginPlanTask] {
        var tasks = plan.postureProtocol.mobilityBlocks.prefix(2).enumerated().map { i, block in
            task("Mobilité \(i + 1)", block, "Posture", 5)
        }
        tasks.append(task("Marche", plan.postureProtocol.walkingTargets, "Posture", 30))
        if weekday == 3 || weekday == 6 {
            tasks.append(task("Respiration", plan.postureProtocol.breathingWork.first ?? "Box breathing 3 min", "Posture", 3))
        }
        return tasks
    }

    private static func faceTasks(plan: FaceOriginPlan, phase: OriginPlanPhaseBlock) -> [OriginPlanTask] {
        [
            task("Mastication lente", "20–30 mâchées par bouchée — stimulation maxillaire + digestion", "Maxillaire", nil),
            task("Mewing actif", plan.faceProtocol.jawAndTongueWork.first ?? "5 min langue au palais", "Maxillaire", 5),
            task("Déglution consciente", "3 déglutions correctes — langue seule, posture droite", "Maxillaire", 2),
            task("Drainage lymphatique", plan.faceProtocol.lymphAndFascia.first ?? "Massage sous-orbital 1 min", "Maxillaire", 1)
        ]
    }

    private static func eveningTasks(plan: FaceOriginPlan, answers: [String: WelcomePlanAnswer]) -> [OriginPlanTask] {
        var tasks: [OriginPlanTask] = [
            task("Routine sommeil", "Lumière chaude, préparation coucher", "Sommeil", 20)
        ]
        if answers["screen_before_bed"]?.choiceIds.first == "yes" {
            tasks.insert(task("Couvre-feu écran", "Zéro écran 60 min avant le coucher", "Sommeil", nil), at: 0)
        }
        return tasks
    }

    private static func task(_ title: String, _ detail: String, _ pillar: String, _ minutes: Int?) -> OriginPlanTask {
        OriginPlanTask(id: UUID().uuidString, title: title, detail: detail, pillar: pillar, durationMinutes: minutes, isOptional: false)
    }

    private static func dayTitle(week: Int, weekday: Int, hasTraining: Bool) -> String {
        if weekday == 6 { return "Semaine \(week) — Récupération & review" }
        if hasTraining { return "Semaine \(week) — \(weekdayLabels[weekday]) · Séance" }
        return "Semaine \(week) — \(weekdayLabels[weekday]) · Récup active"
    }
}
