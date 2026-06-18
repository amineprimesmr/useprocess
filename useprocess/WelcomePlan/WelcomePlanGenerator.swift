import Foundation

enum WelcomePlanGenerator {

    static func generate(
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?
    ) -> FaceOriginPlan {
        let userId = profile?.userId ?? UserScopedStorage.currentUserId() ?? "local-user"
        let faceGoal = primaryGoalLabel(answers)
        let bodyFat = answers["body_fat_feel"]?.choiceIds.first
        let sleepQ = answers["sleep_quality"]?.choiceIds.first
        let supplements = answers["supplements_use"]?.choiceIds.first
        let sessions = sessionsPerWeek(answers)
        let gender = profile?.gender ?? .male

        let pillarScores = computePillarScores(answers: answers)
        let dailyHabits = buildDailyHabits(answers: answers, gender: gender)
        let weeklyRhythm = buildWeeklyRhythm(sessions: sessions, answers: answers)
        let duration = OriginPlanDuration.compute(from: answers)
        let phaseRoadmap = buildPhaseRoadmap(duration: duration, sessions: sessions, answers: answers)
        let nutrition = buildNutritionProtocol(answers: answers, bodyFat: bodyFat)
        let sleep = buildSleepProtocol(answers: answers)
        let training = buildTrainingProtocol(answers: answers, profile: profile, sessions: sessions, gender: gender)
        let posture = buildPostureProtocol(answers: answers)

        let summary = buildExecutiveSummary(
            faceGoal: faceGoal,
            answers: answers,
            sleepQ: sleepQ,
            sessions: sessions,
            duration: duration
        )

        var plan = FaceOriginPlan(
            id: UUID().uuidString,
            userId: userId,
            createdAt: Date(),
            lastUpdated: Date(),
            headline: duration.headlineLabel,
            executiveSummary: summary,
            philosophyNote: FaceOriginPlan.noSupplementsPhilosophy,
            primaryFaceGoal: faceGoal,
            pillarScores: pillarScores,
            dailyHabits: dailyHabits,
            weeklyRhythm: weeklyRhythm,
            phaseRoadmap: phaseRoadmap,
            nutritionProtocol: nutrition,
            sleepProtocol: sleep,
            trainingProtocol: training,
            postureProtocol: posture,
            faceProtocol: buildFaceProtocol(answers: answers, faceGoal: faceGoal, duration: duration),
            mindsetNotes: buildMindsetNotes(answers: answers, supplements: supplements, duration: duration),
            totalWeeks: duration.totalWeeks,
            durationMinWeeks: duration.minWeeks,
            durationMaxWeeks: duration.maxWeeks,
            calendar: OriginProgramCalendar.empty,
            progress: OriginPlanProgress(),
            lifestyleExtras: buildLifestyleExtras(answers: answers)
        )

        plan.calendar = OriginPlanCalendarBuilder.build(from: plan, answers: answers, gender: gender)
        return plan
    }

    private static func buildLifestyleExtras(answers: [String: WelcomePlanAnswer]) -> OriginLifestyleExtras {
        var extras = OriginLifestyleExtras.default
        if choice("screen_before_bed", in: answers) == "yes" {
            extras.stressRegulation.append("Priorité : couper les écrans 60 min avant le coucher")
        }
        if multi("face_concerns", in: answers).contains("dark_circles") {
            extras.bonusProposals.insert("Cernes = sommeil + lymphe : marche + hydratation minérale avant crème", at: 0)
        }
        return extras
    }

    // MARK: - Helpers

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }

    private static func multi(_ id: String, in answers: [String: WelcomePlanAnswer]) -> [String] {
        answers[id]?.choiceIds ?? []
    }

    private static func primaryGoalLabel(_ answers: [String: WelcomePlanAnswer]) -> String {
        let concerns = multi("face_concerns", in: answers)
        guard !concerns.isEmpty else {
            return "Protocole Origine — transformation globale"
        }
        return concerns.prefix(3).map {
            WelcomePlanQuestionBank.choiceLabel(for: "face_concerns", choiceId: $0)
        }.joined(separator: " · ")
    }

    private static func sessionsPerWeek(_ answers: [String: WelcomePlanAnswer]) -> Int {
        switch choice("sessions_per_week", in: answers) {
        case "1": return 1
        case "2": return 2
        case "3": return 3
        case "4": return 4
        case "5plus": return 5
        default: return 3
        }
    }

    private static func computePillarScores(answers: [String: WelcomePlanAnswer]) -> [OriginPillarScore] {
        var hormones = 70
        var training = 65
        var posture = 60
        var results = 55

        if choice("sleep_quality", in: answers)?.contains("Mauvais") == true ||
            choice("sleep_quality", in: answers)?.contains("Très mauvais") == true {
            hormones -= 20
        }
        if choice("fatigue_frequency", in: answers) == FatigueFrequency.often.rawValue ||
            choice("fatigue_frequency", in: answers) == FatigueFrequency.always.rawValue {
            hormones -= 12
        }
        if choice("screen_before_bed", in: answers) == "yes" { hormones -= 8 }
        if choice("morning_sunlight", in: answers) == "never" || choice("morning_sunlight", in: answers) == "rarely" {
            hormones -= 10
        }

        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            hormones -= 12
            results -= 10
        }
        if choice("processed_food", in: answers) == "few_week" {
            hormones -= 6
        }

        if choice("forward_head", in: answers) == "yes" { posture -= 15 }
        if choice("mouth_breathing", in: answers) == "yes" { posture -= 12 }
        if choice("desk_job", in: answers) == "yes" { posture -= 10 }

        let exp = choice("training_experience", in: answers)
        if exp == ExperienceLevel.debutant.rawValue { training -= 5 }
        if exp == ExperienceLevel.professionnel.rawValue { training += 10 }

        return [
            .init(pillar: "Hormones & système nerveux", score: clamp(hormones), focus: hormones < 60 ? "Sommeil + lumière + stress" : "Consolidation circadienne"),
            .init(pillar: "Entraînement adapté", score: clamp(training), focus: "Progression \(sessionsPerWeek(answers))×/sem"),
            .init(pillar: "Posture & fascias", score: clamp(posture), focus: posture < 55 ? "Chaîne postérieure + mewing" : "Maintenance fasciale"),
            .init(pillar: "Résultats (visage)", score: clamp(results), focus: "Conséquence de la biologie en ordre")
        ]
    }

    private static func clamp(_ v: Int) -> Int { min(95, max(25, v)) }

    private static func buildDailyHabits(answers: [String: WelcomePlanAnswer], gender: Gender) -> [OriginDailyHabit] {
        var habits: [OriginDailyHabit] = [
            .init(id: "sun", title: "Lumière matinale", detail: "\(ProcessDailyTargets.morningLightMinutes) min de lumière naturelle dans l'heure après le réveil.", pillar: "Hormones", timing: "Réveil"),
            .init(id: "cold_face", title: "Eau froide sur le visage", detail: "\(ProcessDailyTargets.coldFaceRinseSeconds) sec au réveil — stimule la lymphe et dégonfle.", pillar: "Visage", timing: "Réveil"),
            .init(id: "nutrition", title: "Alimentation parfaite", detail: "Repas denses, zéro ultra-transformé — valide ton repas du jour.", pillar: "Nutrition", timing: "Journée"),
            .init(id: "walk", title: "Marche", detail: "\(ProcessDailyTargets.dailySteps) pas — mouvement quotidien.", pillar: "Posture", timing: "Journée"),
            .init(id: "hydrate", title: ProcessHydrationGuide.dailyTaskTitle, detail: ProcessHydrationGuide.protocolGuide, pillar: "Nutrition", timing: "Journée")
        ]

        if gender == .female {
            habits.append(.init(id: "cycle", title: "Sync cycle", detail: "Adapter l'intensité selon la phase — moins de stress nerveux en phase lutéale.", pillar: "Entraînement", timing: "Hebdo"))
        }

        if multi("face_concerns", in: answers).contains("dark_circles") {
            habits.append(.init(id: "sleep_face", title: "Sommeil prioritaire visage", detail: "\(ProcessDailyTargets.sleepHours) h par nuit. Les cernes = cortisol + lymphe stagnante.", pillar: "Visage", timing: "Nuit"))
        }

        return habits
    }

    private static func buildWeeklyRhythm(sessions: Int, answers: [String: WelcomePlanAnswer]) -> [OriginWeeklyBlock] {
        [
            .init(id: "w1", title: "Structure hebdo", detail: "\(sessions) séances force + marche quotidienne"),
            .init(id: "w2", title: "Récupération", detail: "\(ProcessDailyTargets.restDaysPerWeek) jours off complets. Sommeil > séance supplémentaire si fatigue."),
            .init(id: "w3", title: "Soleil & nature", detail: "\(ProcessDailyTargets.outdoorWalkSessionsPerWeek) sessions outdoor/sem — lumière + grounding pieds nus.")
        ]
    }

    private static func buildPhaseRoadmap(
        duration: OriginPlanDuration,
        sessions: Int,
        answers: [String: WelcomePlanAnswer]
    ) -> [OriginPlanPhaseBlock] {
        let ends = duration.phaseEnds
        let total = duration.totalWeeks
        return [
            .init(
                id: "p1",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: 1, through: ends.p1),
                title: "Fondations — Reset biologique",
                objectives: [
                    "Stabiliser le rythme circadien (coucher / réveil, marge \(ProcessDailyTargets.sleepScheduleMarginMinutes) min max)",
                    "Alimentation dense sans ultra-transformé",
                    "Mewing en permanence (voir section dédiée)"
                ],
                habits: ["Couvre-feu lumière bleue", "Repas protéinés denses", "Marche \(ProcessDailyTargets.dailySteps) pas"]
            ),
            .init(
                id: "p2",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: ends.p1 + 1, through: ends.p2),
                title: "Hormones & digestion",
                objectives: [
                    "Optimiser la digestion (mastication, repas réguliers)",
                    "Réduire le stress chronique (sommeil, marche)",
                    "Hydratation \(ProcessHydrationGuide.dailyLiters)"
                ],
                habits: ["Minéraux naturels", "Routine soir sans écran", "Scan visage quotidien"]
            ),
            .init(
                id: "p3",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: ends.p2 + 1, through: ends.p3),
                title: "Entraînement & composition",
                objectives: [
                    "\(sessions) séances progressive overload",
                    "Ajustement calories via aliments entiers (pas de shake isolé)",
                    "Travail chaîne postérieure + cou / trapèzes"
                ],
                habits: ["Séances loguées", "Sommeil \(ProcessDailyTargets.sleepHours) h minimum", "Scan visage régulier"]
            ),
            .init(
                id: "p4",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: ends.p3 + 1, through: total),
                title: "Affinage visage & consolidation",
                objectives: [
                    "Affiner masse grasse si objectif",
                    "Libération fascias maxillaire et nuque",
                    "Ancrer les habitudes sur le long terme"
                ],
                habits: ["Bilan photos / scan", "Maintien 80 % des bases", "Plan après le protocole"]
            )
        ]
    }

    private static func buildNutritionProtocol(
        answers: [String: WelcomePlanAnswer],
        bodyFat: String?
    ) -> OriginNutritionProtocol {
        let reduce: [String] = ["Ultra-transformés", "Huiles de graines industrielles", "Sucre ajouté quotidien"]
        var prioritize: [String] = ["Œufs", "Tubercules vapeur", "Fruits modérés"]
        var principles: [String] = [
            "Alimentation dense = moins de volume, plus de nutriments — digestion légère",
            "Zéro complément isolé : cofacteurs viennent des aliments entiers",
            "Électrolytes via sel minéral et laitiers de qualité — pas de sachets"
        ]

        let restrictions = multi("dietary_restrictions", in: answers)
        if restrictions.contains(DietaryRestriction.vegetarian.rawValue) ||
            restrictions.contains(DietaryRestriction.vegan.rawValue) {
            prioritize = ["Œufs", "Laitiers entiers", "Poisson (si pescétarien)", "Tubercules", "Fruits modérés"]
            principles.append("Aliments entiers denses — pas de multivitamines")
        }
        if restrictions.contains(DietaryRestriction.lactoseFree.rawValue) {
            prioritize.removeAll { $0.contains("Laitiers") }
        }

        if bodyFat == "soft" || bodyFat == "high" {
            principles.append("Léger déficit via densité alimentaire — pas de famine (préserve le visage)")
        } else if bodyFat == "very_lean" || bodyFat == "athletic" {
            principles.append("Maintien ou léger surplus via laitiers / tubercules si prise de masse")
        }

        if choice("processed_food", in: answers) == "most_meals" || choice("processed_food", in: answers) == "daily" {
            principles.append("Priorité : remplacer l'industriel par des repas simples faits maison")
        }

        return OriginNutritionProtocol(
            principles: principles,
            dailyStructure: [
                "Repas denses : protéines + tubercule ou légumes cuits",
                "Idées de repas via l'IA dans le journal (pas de menu imposé)",
                "Collation optionnelle si faim réelle : fromage entier ou fruit",
                "Dîner léger si sommeil fragile"
            ],
            foodsToPrioritize: prioritize,
            foodsToReduce: reduce,
            hydrationGuide: ProcessHydrationGuide.protocolGuide,
            mealExamples: [],
        )
    }

    private static func buildSleepProtocol(answers: [String: WelcomePlanAnswer]) -> OriginSleepProtocol {
        let bedtime = answers["bedtime"]?.timeValue ?? "22:30"
        let wake = answers["wake_time"]?.timeValue ?? "07:00"
        let hours = computedSleepHours(bedtime: bedtime, wake: wake)

        var evening: [String] = [
            "Lumière chaude / tamisée 2 h avant le coucher",
            "Dernière caféine avant \(ProcessDailyTargets.caffeineCutoffHour) h",
            "Chambre fraîche (\(ProcessDailyTargets.bedroomTempCelsius) °C), obscurité totale"
        ]
        let morning: [String] = [
            "Réveil même heure (marge \(ProcessDailyTargets.sleepScheduleMarginMinutes) min max, week-end inclus)",
            "Lumière naturelle dans les \(ProcessDailyTargets.morningLightMinutes) min",
            "Eau froide sur le visage \(ProcessDailyTargets.coldFaceRinseSeconds) sec",
            "Hydratation + sel / citron — pas de téléphone au lit"
        ]

        if choice("screen_before_bed", in: answers) == "yes" {
            evening.insert("Mode avion ou téléphone hors chambre \(ProcessDailyTargets.screenCurfewMinutes) min avant", at: 0)
        }

        return OriginSleepProtocol(
            targetHours: hours,
            bedtimeWindow: "Cible \(bedtime) (marge \(ProcessDailyTargets.sleepScheduleMarginMinutes) min)",
            wakeWindow: "Cible \(wake) (marge \(ProcessDailyTargets.sleepScheduleMarginMinutes) min)",
            eveningRoutine: evening,
            morningRoutine: morning
        )
    }

    private static func buildTrainingProtocol(
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?,
        sessions: Int,
        gender: Gender
    ) -> OriginTrainingProtocol {
        let injuries = multi("injuries", in: answers)
        var template: [String] = []

        if gender == .female {
            template = [
                "Séance A : Fessiers / hanches + chaîne postérieure",
                "Séance B (option) : Haut du corps léger + core",
                "Marche quotidienne prioritaire sur le cardio intensif"
            ]
        } else {
            template = [
                "Séance A : Push (épaules, trapèzes, pec) + cou",
                "Séance B : Pull (dos, rear delts) + face pulls",
                "Séance C : Jambes + fessiers + chaîne postérieure"
            ]
        }

        if sessions <= 2 {
            template = Array(template.prefix(2))
        } else if sessions == 1 {
            template = ["Full body 2× mouvements composés + face pulls + marche"]
        }

        var recovery = ["Sommeil > séance extra", "Deload semaine 4 et 8"]
        if injuries.contains("lower_back") {
            recovery.append("Éviter charges axiales lourdes — hip hinge technique d'abord")
        }
        if choice("fatigue_frequency", in: answers) == FatigueFrequency.often.rawValue ||
            choice("fatigue_frequency", in: answers) == FatigueFrequency.always.rawValue {
            recovery.append("RPE 6–7 max — récupération prioritaire si fatigue fréquente")
        }

        return OriginTrainingProtocol(
            sessionsPerWeek: sessions,
            sessionDurationMinutes: sessions <= 2 ? 55 : 45,
            splitOverview: gender == .female
                ? "1–2 séances intensité + marche — cycle menstruel respecté"
                : "3–4 séances — accent clavicules, trapèzes, épaules, chaîne postérieure",
            weeklyTemplate: template,
            recoveryRules: recovery
        )
    }

    private static func buildPostureProtocol(answers: [String: WelcomePlanAnswer]) -> OriginPostureProtocol {
        var checks: [String] = ProcessContinuousHabits.all.map { "\($0.title) — \($0.detail)" }
        if choice("forward_head", in: answers) == "yes" {
            checks.append("Rétraction cervicale chin tucks — 3×15 si tête en avant")
        }

        return OriginPostureProtocol(
            dailyChecks: checks,
            mobilityBlocks: [],
            breathingWork: [],
            walkingTargets: "Objectif \(ProcessDailyTargets.dailySteps) pas — suivi automatique via Santé / HealthKit"
        )
    }

    private static func buildFaceProtocol(
        answers: [String: WelcomePlanAnswer],
        faceGoal: String,
        duration: OriginPlanDuration
    ) -> OriginFaceProtocol {
        var focus = [faceGoal]
        focus.append(contentsOf: multi("face_concerns", in: answers).map {
            WelcomePlanQuestionBank.choiceLabel(for: "face_concerns", choiceId: $0)
        })

        let midScan = max(2, duration.totalWeeks / 3)
        let finalScan = duration.totalWeeks

        return OriginFaceProtocol(
            focusAreas: Array(Set(focus)),
            jawAndTongueWork: [
                "Mastication lente \(ProcessDailyTargets.chewsPerBite)× — viande ferme, aliments durs à mâcher"
            ],
            lymphAndFascia: [
                "Eau froide sur le visage \(ProcessDailyTargets.coldFaceRinseSeconds) sec au réveil",
                "Massage doux sous-orbital vers les oreilles — \(ProcessDailyTargets.lymphFaceMassageMinutes) min",
                "Marche \(ProcessDailyTargets.dailySteps) pas + \(ProcessDailyTargets.hydrationLabel) = drainage lymphatique"
            ],
            scanCadence: "Scan visage semaine 1, \(midScan), \(finalScan) — suivi dans Santé"
        )
    }

    private static func buildMindsetNotes(
        answers: [String: WelcomePlanAnswer],
        supplements: String?,
        duration: OriginPlanDuration
    ) -> [String] {
        var notes = [
            "Ce n'est pas ta génétique — ce sont tes habitudes. \(duration.totalWeeks) semaines posent les fondations.",
            "10 % des actions (sommeil, alimentation dense, mewing + posture) = 90 % du résultat visage.",
            "Pas de raccourci artificiel. La beauté est la conséquence d'une biologie en ordre."
        ]
        if supplements == "many" || supplements == "basic" {
            notes.append("On remplace les compléments par des aliments entiers — œufs, laitiers, viande rouge.")
        }
        if choice("commit_plan", in: answers) == "no" {
            notes.append("Reviens quand tu es prêt à t'engager — les bases demandent de la constance.")
        }
        return notes
    }

    private static func buildExecutiveSummary(
        faceGoal: String,
        answers: [String: WelcomePlanAnswer],
        sleepQ: String?,
        sessions: Int,
        duration: OriginPlanDuration
    ) -> String {
        var parts: [String] = []
        parts.append("Priorités : \(faceGoal).")
        parts.append("Protocole Origine sur \(duration.rangeLabel) (\(duration.totalWeeks) semaines calendrier) — 100 % naturel, zéro pilule.")

        if sleepQ?.contains("Mauvais") == true || sleepQ?.contains("mauvais") == true {
            parts.append("Priorité #1 : sommeil et rythme circadien — sans ça, le visage reste gonflé.")
        }
        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            parts.append("Alimentation industrielle détectée : transition vers repas denses faits maison.")
        }
        parts.append("\(sessions) séances/semaine + marche (HealthKit) + mewing & travail maxillaire.")
        let ends = duration.phaseEnds
        parts.append("\(OriginPlanDuration.weeksRangeLabel(from: 1, through: ends.p1)) = fondations. Le visage suit la biologie, pas l'inverse.")

        return parts.joined(separator: " ")
    }

    static func computedSleepHours(bedtime: String, wake: String) -> Double {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let bed = formatter.date(from: bedtime),
              let wakeDate = formatter.date(from: wake) else {
            return 7.5
        }

        var interval = wakeDate.timeIntervalSince(bed)
        if interval <= 0 { interval += 24 * 3600 }
        let hours = interval / 3600

        if hours < 6 { return 8.0 }
        if hours < 7 { return 7.5 }
        return min(hours, 9.0)
    }
}
