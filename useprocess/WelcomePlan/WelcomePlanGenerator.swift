import Foundation

enum WelcomePlanGenerator {

    @MainActor
    static func generate(
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?
    ) -> FaceOriginPlan {
        let userId = profile?.userId ?? UserScopedStorage.currentUserId() ?? "local-user"
        let baselineScan = FaceScanHistoryStore.shared.latestResult?.markers
            ?? OnboardingFaceMarkersStore.load()

        let assessment = OriginUserAssessment.evaluate(
            answers: answers,
            profile: profile,
            baselineScan: baselineScan
        )

        let faceGoal = primaryGoalLabel(answers)
        let bodyFat = answers["body_fat_feel"]?.choiceIds.first
        let sleepQ = answers["sleep_quality"]?.choiceIds.first
        let supplements = answers["supplements_use"]?.choiceIds.first
        let sessions = assessment.recommendedSessions
        let gender = profile?.gender ?? .male
        let targets = assessment.dailyTargets
        let duration = assessment.duration

        let pillarScores = computePillarScores(answers: answers, assessment: assessment.snapshot)
        let dailyHabits = buildDailyHabits(answers: answers, gender: gender, targets: targets, snapshot: assessment.snapshot)
        let weeklyRhythm = buildWeeklyRhythm(sessions: sessions, targets: targets)
        let nutrition = buildNutritionProtocol(answers: answers, bodyFat: bodyFat, snapshot: assessment.snapshot, targets: targets)
        let sleep = buildSleepProtocol(answers: answers, targets: targets, snapshot: assessment.snapshot)
        let training = buildTrainingProtocol(
            answers: answers,
            profile: profile,
            sessions: sessions,
            gender: gender,
            snapshot: assessment.snapshot,
            location: assessment.trainingLocation
        )
        let posture = buildPostureProtocol(
            answers: answers,
            targets: targets,
            snapshot: assessment.snapshot
        )

        let summary = buildExecutiveSummary(
            faceGoal: faceGoal,
            answers: answers,
            sleepQ: sleepQ,
            sessions: sessions,
            duration: duration,
            assessment: assessment
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
            phaseRoadmap: assessment.phaseRoadmap,
            nutritionProtocol: nutrition,
            sleepProtocol: sleep,
            trainingProtocol: training,
            postureProtocol: posture,
            faceProtocol: buildFaceProtocol(
                answers: answers,
                faceGoal: faceGoal,
                duration: duration,
                targets: targets,
                snapshot: assessment.snapshot
            ),
            mindsetNotes: buildMindsetNotes(
                answers: answers,
                supplements: supplements,
                duration: duration,
                snapshot: assessment.snapshot
            ),
            totalWeeks: duration.totalWeeks,
            durationMinWeeks: duration.minWeeks,
            durationMaxWeeks: duration.maxWeeks,
            calendar: OriginProgramCalendar.empty,
            progress: OriginPlanProgress(),
            lifestyleExtras: buildLifestyleExtras(answers: answers, snapshot: assessment.snapshot),
            assessmentSnapshot: assessment.snapshot,
            successCriteria: assessment.successCriteria,
            personalizedTargets: targets
        )

        plan.calendar = OriginPlanCalendarBuilder.build(from: plan, answers: answers, gender: gender)
        return plan
    }

    private static func buildLifestyleExtras(
        answers: [String: WelcomePlanAnswer],
        snapshot: OriginPlanAssessmentSnapshot
    ) -> OriginLifestyleExtras {
        var extras = OriginLifestyleExtras.default
        if choice("screen_before_bed", in: answers) == "yes" {
            extras.stressRegulation.append("Priorité : couper les écrans 60 min avant le coucher")
        }
        if multi("face_concerns", in: answers).contains("dark_circles") {
            extras.bonusProposals.insert("Cernes = sommeil + lymphe : marche + hydratation minérale avant crème", at: 0)
        }
        if choice("alcohol_frequency", in: answers) == "often" || choice("alcohol_frequency", in: answers) == "weekly" {
            extras.stressRegulation.append("Alcool le soir = debloat garanti — réduire en phase 1")
        }
        if snapshot.primaryBlocker == .composition, let gap = snapshot.estimatedBodyFatPercent {
            extras.bonusProposals.insert(
                "Composition ~\(Int(gap.rounded())) % → cible ~\(Int(snapshot.targetBodyFatPercent)) % — densité alimentaire, pas famine",
                at: 0
            )
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

    private static func computePillarScores(
        answers: [String: WelcomePlanAnswer],
        assessment: OriginPlanAssessmentSnapshot
    ) -> [OriginPillarScore] {
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

        if choice("alcohol_frequency", in: answers) == "often" { hormones -= 10 }
        if choice("hydration_level", in: answers) == HydrationLevel.poor.rawValue
            || choice("hydration_level", in: answers) == HydrationLevel.veryPoor.rawValue {
            hormones -= 6; results -= 5
        }

        if assessment.bodyFatGap >= 8 { results -= 15 }
        else if assessment.bodyFatGap >= 4 { results -= 8 }

        return [
            .init(pillar: "Hormones & système nerveux", score: clamp(hormones), focus: hormones < 60 ? "Sommeil + lumière + stress" : "Consolidation circadienne"),
            .init(pillar: "Entraînement adapté", score: clamp(training), focus: "Progression \(OriginUserAssessment.sessionsFromAnswers(answers))×/sem"),
            .init(pillar: "Posture & fascias", score: clamp(posture), focus: posture < 55 ? "Chaîne postérieure + mewing" : "Maintenance fasciale"),
            .init(pillar: "Résultats (visage)", score: clamp(results), focus: assessment.blockerSummary)
        ]
    }

    private static func clamp(_ v: Int) -> Int { min(95, max(25, v)) }

    private static func buildDailyHabits(
        answers: [String: WelcomePlanAnswer],
        gender: Gender,
        targets: OriginPersonalizedDailyTargets,
        snapshot: OriginPlanAssessmentSnapshot
    ) -> [OriginDailyHabit] {
        var habits: [OriginDailyHabit] = [
            .init(id: "sun", title: "Lumière matinale", detail: "\(targets.morningLightMinutes) min de lumière naturelle dans l'heure après le réveil.", pillar: "Hormones", timing: "Réveil"),
            .init(id: "cold_face", title: "Eau froide sur le visage", detail: "\(targets.coldFaceRinseSeconds) sec au réveil — stimule la lymphe et dégonfle.", pillar: "Visage", timing: "Réveil"),
            .init(id: "nutrition", title: "Alimentation parfaite", detail: "Repas denses, zéro ultra-transformé — valide ton repas du jour.", pillar: "Nutrition", timing: "Journée"),
            .init(id: "walk", title: "Marche", detail: "\(targets.dailySteps) pas — mouvement quotidien.", pillar: "Posture", timing: "Journée"),
            .init(id: "hydrate", title: ProcessHydrationGuide.dailyTaskTitle, detail: "Objectif \(targets.hydrationLabel) — répartis dans la journée.", pillar: "Nutrition", timing: "Journée")
        ]

        if gender == .female {
            habits.append(.init(id: "cycle", title: "Sync cycle", detail: "Adapter l'intensité selon la phase — moins de stress nerveux en phase lutéale.", pillar: "Entraînement", timing: "Hebdo"))
        }

        if multi("face_concerns", in: answers).contains("dark_circles") {
            habits.append(.init(id: "sleep_face", title: "Sommeil prioritaire visage", detail: "\(Int(targets.sleepHours)) h par nuit. Les cernes = cortisol + lymphe stagnante.", pillar: "Visage", timing: "Nuit"))
        }

        if snapshot.archetype == .stressRecovery {
            habits.insert(.init(id: "breath", title: "Respiration nasale", detail: "5 min respiration lente — active le parasympathique et baisse le cortisol.", pillar: "Hormones", timing: "Matin & soir"), at: 0)
        }

        return habits
    }

    private static func buildWeeklyRhythm(sessions: Int, targets: OriginPersonalizedDailyTargets) -> [OriginWeeklyBlock] {
        [
            .init(id: "w1", title: "Structure hebdo", detail: "\(sessions) séances force + marche quotidienne"),
            .init(id: "w2", title: "Récupération", detail: "\(targets.restDaysPerWeek) jours off complets. Sommeil > séance supplémentaire si fatigue."),
            .init(id: "w3", title: "Soleil & nature", detail: "\(targets.outdoorWalkSessionsPerWeek) sessions outdoor/sem — lumière + grounding.")
        ]
    }

    private static func buildNutritionProtocol(
        answers: [String: WelcomePlanAnswer],
        bodyFat: String?,
        snapshot: OriginPlanAssessmentSnapshot,
        targets: OriginPersonalizedDailyTargets
    ) -> OriginNutritionProtocol {
        let reduce: [String] = ["Ultra-transformés", "Huiles de graines industrielles", "Sucre ajouté quotidien"]
        var prioritize: [String] = ["Œufs", "Tubercules cuits (rôtis/mijotés)", "Fruits modérés"]
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

        if bodyFat == "soft" || bodyFat == "high" || snapshot.bodyFatGap >= 4 {
            principles.append("Léger déficit via densité alimentaire — pas de famine (préserve le visage)")
        } else if bodyFat == "very_lean" || bodyFat == "athletic" || snapshot.bodyFatGap < 2 {
            principles.append("Maintien ou léger surplus via laitiers / tubercules — pas de restriction")
        }

        if multi("animal_protein", in: answers).contains("none") {
            principles.append("Protéines animales ou œufs à chaque repas principal — carences = peau terne")
        }

        if choice("alcohol_frequency", in: answers) == "often" {
            principles.append("Alcool = debloat garanti — couper en semaine 1")
        }

        if choice("processed_food", in: answers) == "most_meals" || choice("processed_food", in: answers) == "daily" {
            principles.append("Priorité : remplacer l'industriel par des repas simples faits maison")
        }

        var nutrition = OriginNutritionProtocol(
            principles: principles,
            dailyStructure: [
                "Repas denses : protéines + tubercule ou légumes cuits",
                "Idées de repas via l'IA dans le journal (pas de menu imposé)",
                "Collation optionnelle si faim réelle : fromage entier ou fruit",
                "Dîner léger si sommeil fragile"
            ],
            foodsToPrioritize: prioritize,
            foodsToReduce: reduce,
            hydrationGuide: "Objectif \(targets.hydrationLabel)/jour — répartis, pas d'excès le soir (debloat visage)",
            mealExamples: [],
            mealPlanStyle: nil,
            currentMealsPerDay: nil,
            targetMealsPerDay: nil
        )
        ProcessMealPlanConfiguration.enrichNutritionProtocol(&nutrition, answers: answers)

        GutHealthIntelligenceGuide.enrichNutritionProtocol(
            &nutrition,
            answers: answers,
            snapshot: snapshot
        )

        SkinHealthIntelligenceGuide.enrichNutritionForSkin(
            &nutrition,
            answers: answers
        )

        for rule in OriginScriptRulesEngine.nutritionPrinciples(snapshot: snapshot, answers: answers) {
            if !nutrition.principles.contains(rule) {
                nutrition.principles.insert(rule, at: 0)
            }
        }

        return nutrition
    }

    private static func buildSleepProtocol(
        answers: [String: WelcomePlanAnswer],
        targets: OriginPersonalizedDailyTargets,
        snapshot: OriginPlanAssessmentSnapshot
    ) -> OriginSleepProtocol {
        let bedtime = answers["bedtime"]?.timeValue ?? "22:30"
        let wake = answers["wake_time"]?.timeValue ?? "07:00"
        let hours = max(targets.sleepHours, computedSleepHours(bedtime: bedtime, wake: wake))

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

        if GutHealthIntelligenceGuide.needsGutReset(answers: answers, snapshot: snapshot) {
            for note in GutHealthIntelligenceGuide.sleepNotesForGutReset() {
                if !evening.contains(note) {
                    evening.append(note)
                }
            }
        }

        if choice("caffeine_afternoon", in: answers) == "yes" {
            evening.insert("Pas de caféine après \(ProcessDailyTargets.caffeineCutoffHour) h — impact direct sur le debloat matinal", at: 0)
        }

        var sleepProtocol = OriginSleepProtocol(
            targetHours: hours,
            bedtimeWindow: "Cible \(bedtime) (marge \(ProcessDailyTargets.sleepScheduleMarginMinutes) min)",
            wakeWindow: "Cible \(wake) (marge \(ProcessDailyTargets.sleepScheduleMarginMinutes) min)",
            eveningRoutine: evening,
            morningRoutine: morning
        )

        SideSleepIntelligenceGuide.enrichSleepProtocol(&sleepProtocol, answers: answers)

        return sleepProtocol
    }

    private static func buildTrainingProtocol(
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?,
        sessions: Int,
        gender: Gender,
        snapshot: OriginPlanAssessmentSnapshot,
        location: String?
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

        var recovery = ["Sommeil > séance extra", "Deload aux fins de phase"]
        if injuries.contains("lower_back") {
            recovery.append("Éviter charges axiales lourdes — hip hinge technique d'abord")
        }
        if injuries.contains("knees") {
            recovery.append("Genoux : privilégier hip thrust, RDL léger — pas de squat profond douloureux")
        }
        if injuries.contains("shoulders") || injuries.contains("neck") {
            recovery.append("Épaules/nuque : face pulls et mobilité avant charges lourdes")
        }
        if snapshot.archetype == .stressRecovery || snapshot.archetype == .habitReset {
            recovery.append("RPE 6–7 max — récupération prioritaire")
        }
        if choice("fatigue_frequency", in: answers) == FatigueFrequency.often.rawValue ||
            choice("fatigue_frequency", in: answers) == FatigueFrequency.always.rawValue {
            recovery.append("RPE 6–7 max — récupération prioritaire si fatigue fréquente")
        }
        for rule in OriginScriptRulesEngine.trainingConstraints(snapshot: snapshot, answers: answers) {
            if !recovery.contains(rule) { recovery.append(rule) }
        }
        for rule in PostureIntelligenceGuide.trainingPostureNotes(for: answers) {
            if !recovery.contains(rule) { recovery.append(rule) }
        }

        let locationNote: String = {
            switch location {
            case "home": return "Maison — haltères / bandes / poids du corps"
            case "gym": return "Salle — machines + libre"
            case "outdoor": return "Extérieur — parc, anneaux, marche"
            case "mixed": return "Mixte — adapter selon le jour"
            default: return gender == .female
                ? "1–2 séances intensité + marche — cycle menstruel respecté"
                : "3–4 séances — accent clavicules, trapèzes, épaules, chaîne postérieure"
            }
        }()

        return OriginTrainingProtocol(
            sessionsPerWeek: sessions,
            sessionDurationMinutes: sessions <= 2 ? 55 : 45,
            splitOverview: locationNote,
            weeklyTemplate: template,
            recoveryRules: recovery
        )
    }

    private static func buildPostureProtocol(
        answers: [String: WelcomePlanAnswer],
        targets: OriginPersonalizedDailyTargets,
        snapshot: OriginPlanAssessmentSnapshot
    ) -> OriginPostureProtocol {
        let continuous = ProcessContinuousHabits.all.map { "\($0.title) — \($0.detail)" }
        var checks = PostureIntelligenceGuide.dailyChecks(
            answers: answers,
            existingContinuous: continuous
        )

        for rule in OriginScriptRulesEngine.posturePrinciples(snapshot: snapshot, answers: answers) {
            if !checks.contains(rule) {
                checks.append(rule)
            }
        }

        return OriginPostureProtocol(
            dailyChecks: checks,
            mobilityBlocks: postureMobilityBlocks(for: answers),
            breathingWork: PostureIntelligenceGuide.breathingWork(for: answers),
            walkingTargets: "Objectif \(targets.dailySteps) pas + marche consciente (orteils dedans) — HealthKit"
        )
    }

    private static func postureMobilityBlocks(for answers: [String: WelcomePlanAnswer]) -> [String] {
        var blocks = PostureIntelligenceGuide.mobilityBlocks(for: answers)
        ChinRecessionIntelligenceGuide.enrichPostureMobility(&blocks, answers: answers)
        return blocks
    }

    private static func buildFaceProtocol(
        answers: [String: WelcomePlanAnswer],
        faceGoal: String,
        duration: OriginPlanDuration,
        targets: OriginPersonalizedDailyTargets,
        snapshot: OriginPlanAssessmentSnapshot
    ) -> OriginFaceProtocol {
        var focus = [faceGoal]
        focus.append(contentsOf: multi("face_concerns", in: answers).map {
            WelcomePlanQuestionBank.choiceLabel(for: "face_concerns", choiceId: $0)
        })

        let midScan = max(1, duration.totalWeeks / 2)
        let finalScan = duration.totalWeeks

        var faceProtocol = OriginFaceProtocol(
            focusAreas: Array(Set(focus)),
            jawAndTongueWork: [],
            lymphAndFascia: [
                "Eau froide sur le visage \(targets.coldFaceRinseSeconds) sec au réveil",
                "Massage doux sous-orbital — \(targets.lymphFaceMassageMinutes) min",
                "Marche \(targets.dailySteps) pas + \(targets.hydrationLabel) = drainage lymphatique"
            ],
            scanCadence: duration.totalWeeks <= 2
                ? "Scan J1 et J\(finalScan) — comparer le debloat"
                : "Scan semaine 1, \(midScan), \(finalScan) — suivi dans le profil"
        )

        SkinHealthIntelligenceGuide.enrichFaceProtocol(
            &faceProtocol,
            answers: answers,
            coldRinseSeconds: targets.coldFaceRinseSeconds,
            lymphMinutes: targets.lymphFaceMassageMinutes,
            dailySteps: targets.dailySteps,
            hydrationLabel: targets.hydrationLabel
        )

        ChinRecessionIntelligenceGuide.enrichFaceProtocol(
            &faceProtocol,
            answers: answers
        )

        return faceProtocol
    }

    private static func buildMindsetNotes(
        answers: [String: WelcomePlanAnswer],
        supplements: String?,
        duration: OriginPlanDuration,
        snapshot: OriginPlanAssessmentSnapshot
    ) -> [String] {
        var notes = [
            "Profil : \(snapshot.archetype.label) — \(snapshot.blockerSummary)",
            "10 % des actions (sommeil, alimentation dense, mewing + posture) = 90 % du résultat visage.",
            "Pas de raccourci artificiel. La beauté est la conséquence d'une biologie en ordre."
        ]
        if duration.totalWeeks <= 3 {
            notes.insert("Protocole court : exécution stricte > perfection.", at: 1)
        }
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
        duration: OriginPlanDuration,
        assessment: OriginUserAssessment.Result
    ) -> String {
        var parts: [String] = []
        let snapshot = assessment.snapshot

        parts.append("Priorités : \(faceGoal).")
        parts.append("\(snapshot.archetype.label) — \(duration.rangeLabel) (\(duration.totalWeeks) sem. calendrier).")
        parts.append(snapshot.blockerSummary + ".")

        if let bmi = snapshot.bmi {
            parts.append(String(format: "Profil : %.1f m · %.0f kg · IMC %.1f.", (snapshot.heightCm ?? 0) / 100, snapshot.weightKg ?? 0, bmi))
        }
        if let bf = snapshot.estimatedBodyFatPercent {
            parts.append(String(format: "Masse grasse estimée ~%.0f %% → cible ~%.0f %%.", bf, snapshot.targetBodyFatPercent))
        }

        if sleepQ?.contains("Mauvais") == true || sleepQ?.contains("mauvais") == true {
            parts.append("Priorité #1 : sommeil et rythme circadien — sans ça, le visage reste gonflé.")
        }
        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            parts.append("Alimentation industrielle détectée : transition vers repas denses faits maison.")
        }
        let planType = ProcessMealPlanConfiguration.readTargetPlan(from: answers)
        parts.append("Structure repas : \(planType.label).")
        parts.append("\(sessions) séances/semaine + marche (HealthKit) + mewing & travail maxillaire.")
        if let firstPhase = assessment.phaseRoadmap.first {
            parts.append("\(firstPhase.weeksRange) : \(firstPhase.title). Le visage suit la biologie, pas l'inverse.")
        }

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
