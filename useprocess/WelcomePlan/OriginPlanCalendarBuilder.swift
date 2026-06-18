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
        let totalWeeks = max(plan.totalWeeks, 1)
        let phaseEnds = OriginPlanDuration(
            minWeeks: plan.durationMinWeeks,
            maxWeeks: plan.durationMaxWeeks,
            totalWeeks: totalWeeks
        ).phaseEnds

        var weeks: [OriginProgramWeek] = []
        var globalDay = 0

        for weekNum in 1...totalWeeks {
            let phase = phaseForWeek(weekNum, totalWeeks: totalWeeks, phaseEnds: phaseEnds)
            var days: [OriginProgramDay] = []

            for weekday in 0..<7 {
                let training = trainingForDay(
                    week: weekNum,
                    weekday: weekday,
                    sessions: sessions,
                    gender: gender,
                    phase: phase,
                    plan: plan,
                    phaseEnds: phaseEnds
                )
                let nutrition = nutritionForDay(
                    week: weekNum,
                    weekday: weekday,
                    phase: phase,
                    plan: plan,
                    answers: answers
                )

                let dayId = "w\(weekNum)-d\(weekday)"

                days.append(
                    OriginProgramDay(
                        id: dayId,
                        globalDayIndex: globalDay,
                        weekNumber: weekNum,
                        weekdayIndex: weekday,
                        weekdayLabel: weekdayLabels[weekday],
                        title: dayTitle(week: weekNum, weekday: weekday, hasTraining: training != nil),
                        morning: morningTasks(plan: plan, phase: phase, weekday: weekday, dayId: dayId),
                        nutrition: nutrition,
                        training: training,
                        posture: postureTasks(plan: plan, phase: phase, weekday: weekday, dayId: dayId),
                        face: faceTasks(plan: plan, phase: phase, dayId: dayId),
                        evening: eveningTasks(plan: plan, answers: answers, dayId: dayId),
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

        return OriginProgramCalendar(startedAt: Date(), weeks: weeks, buildVersion: 5)
    }

    // MARK: - Phase

    private static func phaseForWeek(
        _ week: Int,
        totalWeeks: Int,
        phaseEnds: (p1: Int, p2: Int, p3: Int)
    ) -> OriginPlanPhaseBlock {
        if week <= phaseEnds.p1 {
            return .init(
                id: "p1",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: 1, through: phaseEnds.p1),
                title: "Fondations — Reset biologique",
                objectives: ["Rythme circadien", "Alimentation dense", "Hydratation \(ProcessHydrationGuide.dailyLiters)"],
                habits: ["Couvre-feu lumière", "Repas protéinés", "Marche"]
            )
        }
        if week <= phaseEnds.p2 {
            return .init(
                id: "p2",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: phaseEnds.p1 + 1, through: phaseEnds.p2),
                title: "Hormones & digestion",
                objectives: ["Digestion optimale", "Stress ↓", "Hydratation \(ProcessHydrationGuide.dailyLiters)"],
                habits: ["Minéraux", "Routine soir", "Scan visage"]
            )
        }
        if week <= phaseEnds.p3 {
            return .init(
                id: "p3",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: phaseEnds.p2 + 1, through: phaseEnds.p3),
                title: "Entraînement & composition",
                objectives: ["Progressive overload", "Composition corporelle", "Chaîne postérieure"],
                habits: ["Séances loguées", "Sommeil \(ProcessDailyTargets.sleepHours) h+", "Scan régulier"]
            )
        }
        return .init(
            id: "p4",
            weeksRange: OriginPlanDuration.weeksRangeLabel(from: phaseEnds.p3 + 1, through: totalWeeks),
            title: "Affinage visage & consolidation",
            objectives: ["Affiner si besoin", "Fascias maxillaire et nuque", "Ancrage long terme"],
            habits: ["Bilan photos", "Maintien 80 % bases", "Plan après protocole"]
        )
    }

    // MARK: - Training

    private static func trainingForDay(
        week: Int,
        weekday: Int,
        sessions: Int,
        gender: Gender,
        phase: OriginPlanPhaseBlock,
        plan: FaceOriginPlan,
        phaseEnds: (p1: Int, p2: Int, p3: Int)
    ) -> OriginDayTraining? {
        let slots = trainingSlots(sessionsPerWeek: sessions)
        guard slots.contains(weekday) else { return nil }

        let isDeload = week == phaseEnds.p1 || week == phaseEnds.p2
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
            cooldown: ["Marche lente 3 min"],
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
        var principles = Array(plan.nutritionProtocol.principles.prefix(2))
        if week <= 3 { principles.append("Phase fondations : zéro ultra-transformé") }
        if week >= 7 { principles.append("Ajuster portions selon énergie et composition") }

        return OriginDayNutrition(
            breakfast: "",
            lunch: "",
            dinner: "",
            snack: nil,
            hydration: plan.nutritionProtocol.hydrationGuide,
            principles: principles,
            foodsToday: Array(plan.nutritionProtocol.foodsToPrioritize.prefix(4))
        )
    }

    // MARK: - Daily tasks

    private static func morningTasks(plan: FaceOriginPlan, phase: OriginPlanPhaseBlock, weekday: Int, dayId: String) -> [OriginPlanTask] {
        [
            task("Lumière matinale", "\(ProcessDailyTargets.morningLightMinutes) min soleil ou lumière naturelle", "Hormones", ProcessDailyTargets.morningLightMinutes, dayId: dayId),
            task(ProcessHydrationGuide.dailyTaskTitle, ProcessHydrationGuide.dailyTaskDetail, "Nutrition", nil, dayId: dayId),
            task(
                "Eau froide sur le visage",
                "\(ProcessDailyTargets.coldFaceRinseSeconds) sec — front, joues, contour des yeux. Réveille la lymphe et réduit le gonflement.",
                "Visage",
                nil,
                dayId: dayId
            ),
            task(
                "Alimentation parfaite",
                alimentationParfaiteDetail(plan: plan),
                "Nutrition",
                nil,
                dayId: dayId
            )
        ]
    }

    private static func alimentationParfaiteDetail(plan: FaceOriginPlan) -> String {
        let principles = plan.nutritionProtocol.principles.prefix(2).joined(separator: " · ")
        if principles.isEmpty {
            return "Repas denses, protéines et légumes — valide ton repas du jour."
        }
        return principles
    }

    private static func postureTasks(plan: FaceOriginPlan, phase: OriginPlanPhaseBlock, weekday: Int, dayId: String) -> [OriginPlanTask] {
        [
            task("Marche", plan.postureProtocol.walkingTargets, "Posture", 30, dayId: dayId)
        ]
    }

    private static func faceTasks(plan: FaceOriginPlan, phase: OriginPlanPhaseBlock, dayId: String) -> [OriginPlanTask] {
        []
    }

    private static func eveningTasks(plan: FaceOriginPlan, answers: [String: WelcomePlanAnswer], dayId: String) -> [OriginPlanTask] {
        []
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
