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
        let phaseRoadmap = buildPhaseRoadmap(sessions: sessions, answers: answers)
        let nutrition = buildNutritionProtocol(answers: answers, bodyFat: bodyFat)
        let sleep = buildSleepProtocol(answers: answers)
        let training = buildTrainingProtocol(answers: answers, profile: profile, sessions: sessions, gender: gender)
        let posture = buildPostureProtocol(answers: answers)
        let face = buildFaceProtocol(answers: answers, faceGoal: faceGoal)
        let mindset = buildMindsetNotes(answers: answers, supplements: supplements)

        let summary = buildExecutiveSummary(
            faceGoal: faceGoal,
            answers: answers,
            sleepQ: sleepQ,
            sessions: sessions
        )

        var plan = FaceOriginPlan(
            id: UUID().uuidString,
            userId: userId,
            createdAt: Date(),
            lastUpdated: Date(),
            headline: "Protocole Origine — 13 semaines",
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
            faceProtocol: face,
            mindsetNotes: mindset,
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
            .init(id: "sun", title: "Lumière matinale", detail: "10–20 min de soleil ou lumière naturelle dans l'heure après le réveil — ancre le cortisol.", pillar: "Hormones", timing: "Réveil"),
            .init(id: "tongue", title: "Mewing (langue au palais)", detail: "Langue entière contre le palais, lèvres closes, respiration nasale. 5 min de mewing actif + posture passive toute la journée.", pillar: "Posture", timing: "Matin + journée"),
            .init(id: "chew", title: "Mastication lente", detail: "20–30 mâchées par bouchée. Stimule le maxillaire et la digestion — pas de complément.", pillar: "Maxillaire", timing: "Repas"),
            .init(id: "walk", title: "Marche décompresse", detail: "Minimum 6 000 pas — idéalement 8 000+. Drainage lymphatique naturel.", pillar: "Posture", timing: "Journée"),
            .init(id: "hydrate", title: "Hydratation minérale", detail: "Eau + aliments riches en minéraux (bouillon os, sel de qualité, fruits) — pas que de l'eau plate.", pillar: "Nutrition", timing: "Journée")
        ]

        if choice("screen_before_bed", in: answers) == "yes" {
            habits.append(.init(id: "digital", title: "Couvre-feu écran", detail: "Zéro écran 60 min avant le coucher. Lumière chaude ou bougie.", pillar: "Hormones", timing: "Soir"))
        }

        if gender == .female {
            habits.append(.init(id: "cycle", title: "Sync cycle", detail: "Adapter l'intensité selon la phase — moins de stress nerveux en phase lutéale.", pillar: "Entraînement", timing: "Hebdo"))
        }

        if multi("face_concerns", in: answers).contains("dark_circles") {
            habits.append(.init(id: "sleep_face", title: "Sommeil prioritaire visage", detail: "7,5–8,5 h visées. Les cernes = cortisol + lymphe stagnante, pas un crème miracle.", pillar: "Visage", timing: "Nuit"))
        }

        return habits
    }

    private static func buildWeeklyRhythm(sessions: Int, answers: [String: WelcomePlanAnswer]) -> [OriginWeeklyBlock] {
        [
            .init(id: "w1", title: "Structure hebdo", detail: "\(sessions) séances force + marche quotidienne + 1 session mobilité/posture 20 min"),
            .init(id: "w2", title: "Récupération", detail: "1–2 jours off complets. Sommeil > séance supplémentaire si fatigue."),
            .init(id: "w3", title: "Soleil & nature", detail: "2–3 sessions outdoor minimum — lumière + grounding pieds nus si possible."),
            .init(id: "w4", title: "Review", detail: "Dimanche : 5 min bilan — sommeil, digestion, mewing / tension maxillaire, énergie.")
        ]
    }

    private static func buildPhaseRoadmap(sessions: Int, answers: [String: WelcomePlanAnswer]) -> [OriginPlanPhaseBlock] {
        [
            .init(
                id: "p1",
                weeksRange: "Semaines 1–3",
                title: "Fondations — Reset biologique",
                objectives: [
                    "Stabiliser le rythme circadien (coucher / réveil fixes ±30 min)",
                    "Alimentation dense sans ultra-transformé",
                    "Mewing (langue au palais) + respiration nasale"
                ],
                habits: ["Couvre-feu lumière bleue", "Repas protéinés denses", "Marche 6k+ pas"]
            ),
            .init(
                id: "p2",
                weeksRange: "Semaines 4–6",
                title: "Hormones & digestion",
                objectives: [
                    "Optimiser la digestion (mastication, repas réguliers)",
                    "Réduire le stress chronique (respiration, marche)",
                    "Hydratation minérale via aliments"
                ],
                habits: ["Bouillon / minéraux naturels", "Routine soir sans écran", "Mobilité thoracique 10 min/j"]
            ),
            .init(
                id: "p3",
                weeksRange: "Semaines 7–10",
                title: "Entraînement & composition",
                objectives: [
                    "\(sessions) séances progressive overload",
                    "Ajustement calories via aliments entiers (pas de shake isolé)",
                    "Travail chaîne postérieure + cou / trapèzes"
                ],
                habits: ["Séances loguées", "Sommeil 7,5 h minimum", "Scan visage mensuel"]
            ),
            .init(
                id: "p4",
                weeksRange: "Semaines 11–13",
                title: "Affinage visage & consolidation",
                objectives: [
                    "Affiner masse grasse si objectif",
                    "Libération fascias maxillaire / SCM / nuque",
                    "Ancrer les habitudes sur le long terme"
                ],
                habits: ["Bilan photos / scan", "Maintien 80 % des bases", "Plan post-13 semaines"]
            )
        ]
    }

    private static func buildNutritionProtocol(
        answers: [String: WelcomePlanAnswer],
        bodyFat: String?
    ) -> OriginNutritionProtocol {
        var reduce: [String] = ["Ultra-transformés", "Huiles de graines industrielles", "Sucre ajouté quotidien"]
        var prioritize: [String] = ["Œufs", "Viande rouge / abats (foie 1×/sem)", "Tubercules vapeur", "Fruits modérés (1/jour max)"]
        var principles: [String] = [
            "Alimentation dense = moins de volume, plus de nutriments — digestion légère",
            "Zéro complément isolé : cofacteurs viennent des aliments entiers",
            "Électrolytes via bouillon, sel minéral, laitiers de qualité — pas de sachets"
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
                "Petit-déjeuner : protéines + graisses (œufs, fromage entier)",
                "Déjeuner : viande / poisson + tubercule + fruit",
                "Collation optionnelle : miel + fromage ou fruit",
                "Dîner : protéines + légumes cuits — léger le soir si sommeil fragile"
            ],
            foodsToPrioritize: prioritize,
            foodsToReduce: reduce,
            hydrationGuide: "Eau + minéraux alimentaires. Bouillon d'os 3–4×/sem. Sel de qualité. Pas de boisson sucrée.",
            mealExamples: [
                "Œufs au beurre + patate douce",
                "Steak + patate vapeur + beurre",
                "Foie de bœuf + salade cuite au beurre",
                "Fromage entier + miel + fruit"
            ]
        )
    }

    private static func buildSleepProtocol(answers: [String: WelcomePlanAnswer]) -> OriginSleepProtocol {
        let bedtime = answers["bedtime"]?.timeValue ?? "22:30"
        let wake = answers["wake_time"]?.timeValue ?? "07:00"
        let hours = computedSleepHours(bedtime: bedtime, wake: wake)

        var evening: [String] = [
            "Lumière chaude / tamisée 2 h avant le coucher",
            "Dernière caféine avant 14 h",
            "Chambre fraîche (~18 °C), obscurité totale"
        ]
        let morning: [String] = [
            "Réveil même heure ±30 min (week-end inclus)",
            "Lumière naturelle dans les 30 min",
            "Hydratation + sel / citron — pas de téléphone au lit"
        ]

        if choice("screen_before_bed", in: answers) == "yes" {
            evening.insert("Mode avion ou téléphone hors chambre 60 min avant", at: 0)
        }
        if choice("alcohol_frequency", in: answers) == "weekly" || choice("alcohol_frequency", in: answers) == "often" {
            evening.append("Alcool max 1×/sem — casse le sommeil profond et gonfle le visage")
        }

        return OriginSleepProtocol(
            targetHours: hours,
            bedtimeWindow: "Cible \(bedtime) (±30 min)",
            wakeWindow: "Cible \(wake) (±30 min)",
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
        var mobility = [
            "Étirement psoas + fléchisseurs hanche 5 min/j",
            "Extension thoracique sur foam roller ou serviette roulée",
            "Renforcement scapulaire (face pulls, Y raises)"
        ]
        if choice("forward_head", in: answers) == "yes" {
            mobility.insert("Rétraction cervicale chin tucks — 3×15/j", at: 0)
        }

        return OriginPostureProtocol(
            dailyChecks: [
                "Mewing au repos — langue entière au palais",
                "Lèvres closes, respiration nasale",
                "Oreilles au-dessus des épaules (pas de forward head)"
            ],
            mobilityBlocks: mobility,
            breathingWork: ["Box breathing 4-4-4-4 — 3 min matin", "Respiration nasale à l'effort modéré"],
            walkingTargets: "Objectif 8 000+ pas/j — suivi automatique via Santé / HealthKit"
        )
    }

    private static func buildFaceProtocol(answers: [String: WelcomePlanAnswer], faceGoal: String) -> OriginFaceProtocol {
        var focus = [faceGoal]
        focus.append(contentsOf: multi("face_concerns", in: answers).map {
            WelcomePlanQuestionBank.choiceLabel(for: "face_concerns", choiceId: $0)
        })

        return OriginFaceProtocol(
            focusAreas: Array(Set(focus)),
            jawAndTongueWork: [
                "Mewing actif 5 min — langue au palais, lèvres closes, dents légèrement en contact",
                "Mewing passif toute la journée (posture linguale au repos)",
                "Déglution correcte — langue seule, sans pousser avec les lèvres ou les joues",
                "Mastication lente 20–30× — viande ferme, crudités cuites al dente",
                "Gomme xylitol modérée si besoin — pas de chewing excessif"
            ],
            lymphAndFascia: [
                "Marche + hydratation minérale = drainage lymphatique naturel",
                "Massage doux sous-orbital vers les oreilles — 1 min/j",
                "Libération SCM / nuque si forward head (fascias faciaux)"
            ],
            scanCadence: "Scan TrueDepth semaine 1, 4, 8, 13 — corrélations auto dans Santé"
        )
    }

    private static func buildMindsetNotes(answers: [String: WelcomePlanAnswer], supplements: String?) -> [String] {
        var notes = [
            "Ce n'est pas ta génétique — c'est tes habitudes. 13 semaines = fondations.",
            "10 % des actions (sommeil, alimentation dense, mewing + posture) = 90 % du résultat visage.",
            "Pas de raccourci artificiel. La beauté est la conséquence d'une biologie en ordre."
        ]
        if supplements == "many" || supplements == "basic" {
            notes.append("On remplace les compléments par des aliments entiers — foie, œufs, laitiers, bouillon.")
        }
        if choice("commit_13_weeks", in: answers) == "no" {
            notes.append("Reviens quand tu es prêt à t'engager — les bases demandent de la constance.")
        }
        return notes
    }

    private static func buildExecutiveSummary(
        faceGoal: String,
        answers: [String: WelcomePlanAnswer],
        sleepQ: String?,
        sessions: Int
    ) -> String {
        var parts: [String] = []
        parts.append("Priorités : \(faceGoal).")
        parts.append("Plan 13 semaines Protocole Origine — 100 % naturel, zéro pilule.")

        if sleepQ?.contains("Mauvais") == true || sleepQ?.contains("mauvais") == true {
            parts.append("Priorité #1 : sommeil et rythme circadien — sans ça, le visage reste gonflé.")
        }
        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            parts.append("Alimentation industrielle détectée : transition vers repas denses faits maison.")
        }
        parts.append("\(sessions) séances/semaine + marche (HealthKit) + mewing & travail maxillaire.")
        parts.append("Semaines 1–3 = fondations. Le visage suit la biologie, pas l'inverse.")

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
