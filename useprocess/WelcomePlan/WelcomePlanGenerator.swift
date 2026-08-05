import Foundation

enum WelcomePlanGenerator {

    @MainActor
    static func generate(
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?
    ) -> FaceOriginPlan {
        let resolvedAnswers = WelcomePlanQuestionBank.mergedAnswersForGeneration(
            userAnswers: answers,
            profile: profile
        )
        let userId = profile?.userId ?? UserScopedStorage.currentUserId() ?? "local-user"
        let baselineScan = FaceScanHistoryStore.shared.latestResult?.markers
            ?? OnboardingFaceMarkersStore.load()

        let assessment = OriginUserAssessment.evaluate(
            answers: resolvedAnswers,
            profile: profile,
            baselineScan: baselineScan
        )

        let faceGoal = primaryGoalLabel(resolvedAnswers)
        let bodyFat = resolvedAnswers["body_fat_feel"]?.choiceIds.first
        let sleepQ = resolvedAnswers["sleep_quality"]?.choiceIds.first
        let supplements = resolvedAnswers["supplements_use"]?.choiceIds.first
        let sessions = assessment.recommendedSessions
        let gender = profile?.gender ?? .male
        let targets = assessment.dailyTargets
        let duration = assessment.duration

        let pillarScores = computePillarScores(answers: resolvedAnswers, assessment: assessment.snapshot)
        let dailyHabits = buildDailyHabits(answers: resolvedAnswers, gender: gender, targets: targets, snapshot: assessment.snapshot)
        let weeklyRhythm = buildWeeklyRhythm(sessions: sessions, targets: targets)
        let nutrition = buildNutritionProtocol(answers: resolvedAnswers, bodyFat: bodyFat, snapshot: assessment.snapshot, targets: targets)
        let sleep = buildSleepProtocol(answers: resolvedAnswers, targets: targets, snapshot: assessment.snapshot)
        let training = buildTrainingProtocol(
            answers: resolvedAnswers,
            profile: profile,
            sessions: sessions,
            gender: gender,
            snapshot: assessment.snapshot,
            location: assessment.trainingLocation
        )
        let posture = buildPostureProtocol(
            answers: resolvedAnswers,
            targets: targets,
            snapshot: assessment.snapshot,
            gender: gender
        )

        let summary = buildExecutiveSummary(
            faceGoal: faceGoal,
            answers: resolvedAnswers,
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
                answers: resolvedAnswers,
                faceGoal: faceGoal,
                duration: duration,
                targets: targets,
                snapshot: assessment.snapshot
            ),
            mindsetNotes: buildMindsetNotes(
                answers: resolvedAnswers,
                supplements: supplements,
                duration: duration,
                snapshot: assessment.snapshot
            ),
            totalWeeks: duration.totalWeeks,
            durationMinWeeks: duration.minWeeks,
            durationMaxWeeks: duration.maxWeeks,
            calendar: OriginProgramCalendar.empty,
            progress: OriginPlanProgress(),
            lifestyleExtras: buildLifestyleExtras(answers: resolvedAnswers, snapshot: assessment.snapshot),
            assessmentSnapshot: assessment.snapshot,
            successCriteria: assessment.successCriteria,
            personalizedTargets: targets
        )

        plan.calendar = OriginPlanCalendarBuilder.build(from: plan, answers: resolvedAnswers, gender: gender)
        return plan
    }

    private static func buildLifestyleExtras(
        answers: [String: WelcomePlanAnswer],
        snapshot: OriginPlanAssessmentSnapshot
    ) -> OriginLifestyleExtras {
        var extras = OriginLifestyleExtras.default
        if choice("screen_before_bed", in: answers) == "yes" {
            extras.stressRegulation.append(AppCopy.tSync("Priorité : couper les écrans 60 min avant le coucher", en: "Priority: cut screens 60 min before bed"))
        }
        if multi("face_concerns", in: answers).contains("dark_circles") {
            extras.bonusProposals.insert(AppCopy.tSync("Cernes = sommeil + lymphe : marche + hydratation minérale avant crème", en: "Under-eyes = sleep + lymph: walk + mineral hydration before cream"), at: 0)
        }
        if choice("alcohol_frequency", in: answers) == "often" || choice("alcohol_frequency", in: answers) == "weekly" {
            extras.stressRegulation.append(AppCopy.tSync("Alcool le soir = debloat garanti — réduire en phase 1", en: "Evening alcohol = guaranteed bloat — cut in phase 1"))
        }
        if snapshot.primaryBlocker == .composition, let gap = snapshot.estimatedBodyFatPercent {
            extras.bonusProposals.insert(
                AppCopy.tSync(
                    "Composition ~\(Int(gap.rounded())) % → cible ~\(Int(snapshot.targetBodyFatPercent)) % — densité alimentaire, pas famine",
                    en: "Composition ~\(Int(gap.rounded()))% → target ~\(Int(snapshot.targetBodyFatPercent))% — food density, not starvation"
                ),
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
            return AppCopy.tSync(
                "Plan personnalisé — transformation globale",
                en: "Personalized plan — full transformation"
            )
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
            .init(
                pillar: AppCopy.tSync("Hormones & système nerveux", en: "Hormones & nervous system"),
                score: clamp(hormones),
                focus: hormones < 60
                    ? AppCopy.tSync("Sommeil + lumière + stress", en: "Sleep + light + stress")
                    : AppCopy.tSync("Consolidation circadienne", en: "Circadian consolidation")
            ),
            .init(
                pillar: AppCopy.tSync("Entraînement adapté", en: "Adapted training"),
                score: clamp(training),
                focus: AppCopy.tSync(
                    "Progression \(OriginUserAssessment.sessionsFromAnswers(answers))×/sem",
                    en: "Progression \(OriginUserAssessment.sessionsFromAnswers(answers))×/wk"
                )
            ),
            .init(
                pillar: AppCopy.tSync("Posture & fascias", en: "Posture & fascia"),
                score: clamp(posture),
                focus: posture < 55
                    ? AppCopy.tSync("Chaîne postérieure + mewing", en: "Posterior chain + mewing")
                    : AppCopy.tSync("Maintenance fasciale", en: "Fascia maintenance")
            ),
            .init(
                pillar: AppCopy.tSync("Résultats (visage)", en: "Results (face)"),
                score: clamp(results),
                focus: assessment.blockerSummary
            )
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
            .init(
                id: "sun",
                title: AppCopy.tSync("Lumière matinale", en: "Morning light"),
                detail: AppCopy.tSync(
                    "\(targets.morningLightMinutes) min de lumière naturelle dans l'heure après le réveil.",
                    en: "\(targets.morningLightMinutes) min of natural light within an hour of waking."
                ),
                pillar: AppCopy.tSync("Hormones", en: "Hormones"),
                timing: AppCopy.tSync("Réveil", en: "Wake")
            ),
            .init(
                id: "cold_face",
                title: AppCopy.tSync("Eau froide sur le visage", en: "Cold water on the face"),
                detail: AppCopy.tSync(
                    "\(targets.coldFaceRinseSeconds) sec au réveil — stimule la lymphe et dégonfle.",
                    en: "\(targets.coldFaceRinseSeconds) sec on waking — boosts lymph and debloats."
                ),
                pillar: AppCopy.tSync("Visage", en: "Face"),
                timing: AppCopy.tSync("Réveil", en: "Wake")
            ),
            .init(
                id: "nutrition",
                title: AppCopy.tSync("Alimentation parfaite", en: "Solid nutrition"),
                detail: AppCopy.tSync(
                    "Repas denses, zéro ultra-transformé — valide ton repas du jour.",
                    en: "Dense meals, zero ultra-processed — log your meal for the day."
                ),
                pillar: AppCopy.tSync("Nutrition", en: "Nutrition"),
                timing: AppCopy.tSync("Journée", en: "Daytime")
            ),
            .init(
                id: "walk",
                title: AppCopy.tSync("Marche", en: "Walk"),
                detail: AppCopy.tSync(
                    "\(targets.dailySteps) pas — mouvement quotidien.",
                    en: "\(targets.dailySteps) steps — daily movement."
                ),
                pillar: AppCopy.tSync("Posture", en: "Posture"),
                timing: AppCopy.tSync("Journée", en: "Daytime")
            ),
            .init(
                id: "hydrate",
                title: ProcessHydrationGuide.dailyTaskTitle,
                detail: AppCopy.tSync(
                    "Objectif \(targets.hydrationLabel) — répartis dans la journée.",
                    en: "Goal \(targets.hydrationLabel) — spread across the day."
                ),
                pillar: AppCopy.tSync("Nutrition", en: "Nutrition"),
                timing: AppCopy.tSync("Journée", en: "Daytime")
            )
        ]

        if gender == .female {
            habits.append(.init(
                id: "cycle",
                title: AppCopy.tSync("Sync cycle", en: "Cycle sync"),
                detail: AppCopy.tSync(
                    "Adapter l'intensité selon la phase — moins de stress nerveux en phase lutéale.",
                    en: "Match intensity to your phase — less nervous stress in luteal."
                ),
                pillar: AppCopy.tSync("Entraînement", en: "Training"),
                timing: AppCopy.tSync("Hebdo", en: "Weekly")
            ))
        }

        if multi("face_concerns", in: answers).contains("dark_circles") {
            habits.append(.init(
                id: "sleep_face",
                title: AppCopy.tSync("Sommeil prioritaire visage", en: "Face-first sleep"),
                detail: AppCopy.tSync(
                    "\(Int(targets.sleepHours)) h par nuit. Les cernes = cortisol + lymphe stagnante.",
                    en: "\(Int(targets.sleepHours)) h per night. Under-eyes = cortisol + stagnant lymph."
                ),
                pillar: AppCopy.tSync("Visage", en: "Face"),
                timing: AppCopy.tSync("Nuit", en: "Night")
            ))
        }

        return habits
    }

    private static func buildWeeklyRhythm(sessions: Int, targets: OriginPersonalizedDailyTargets) -> [OriginWeeklyBlock] {
        [
            .init(
                id: "w1",
                title: AppCopy.tSync("Structure hebdo", en: "Weekly structure"),
                detail: AppCopy.tSync(
                    "\(sessions) séances force + marche quotidienne",
                    en: "\(sessions) strength sessions + daily walks"
                )
            ),
            .init(
                id: "w2",
                title: AppCopy.tSync("Récupération", en: "Recovery"),
                detail: AppCopy.tSync(
                    "\(targets.restDaysPerWeek) jours off complets. Sommeil > séance supplémentaire si fatigue.",
                    en: "\(targets.restDaysPerWeek) full rest days. Sleep > extra session if fatigued."
                )
            ),
            .init(
                id: "w3",
                title: AppCopy.tSync("Soleil & nature", en: "Sun & nature"),
                detail: AppCopy.tSync(
                    "\(targets.outdoorWalkSessionsPerWeek) sessions outdoor/sem — lumière + grounding.",
                    en: "\(targets.outdoorWalkSessionsPerWeek) outdoor sessions/wk — light + grounding."
                )
            )
        ]
    }

    private static func buildNutritionProtocol(
        answers: [String: WelcomePlanAnswer],
        bodyFat: String?,
        snapshot: OriginPlanAssessmentSnapshot,
        targets: OriginPersonalizedDailyTargets
    ) -> OriginNutritionProtocol {
        let reduce: [String] = [
            AppCopy.tSync("Ultra-transformés", en: "Ultra-processed"),
            AppCopy.tSync("Huiles de graines industrielles", en: "Industrial seed oils"),
            AppCopy.tSync("Sucre ajouté quotidien", en: "Daily added sugar")
        ]
        var prioritize: [String] = [
            AppCopy.tSync("Œufs", en: "Eggs"),
            AppCopy.tSync("Tubercules cuits (rôtis/mijotés)", en: "Cooked tubers (roasted/stewed)"),
            AppCopy.tSync("Fruits modérés", en: "Moderate fruit")
        ]
        var principles: [String] = [
            AppCopy.tSync(
                "Alimentation dense = moins de volume, plus de nutriments — digestion légère",
                en: "Dense food = less volume, more nutrients — light digestion"
            ),
            AppCopy.tSync(
                "Zéro complément isolé : cofacteurs viennent des aliments entiers",
                en: "Zero isolated supplements: cofactors come from whole foods"
            ),
            AppCopy.tSync(
                "Électrolytes via sel minéral et laitiers de qualité — pas de sachets",
                en: "Electrolytes via mineral salt and quality dairy — no packets"
            )
        ]

        let restrictions = multi("dietary_restrictions", in: answers)
        if restrictions.contains(DietaryRestriction.vegetarian.rawValue) ||
            restrictions.contains(DietaryRestriction.vegan.rawValue) {
            prioritize = [
                AppCopy.tSync("Œufs", en: "Eggs"),
                AppCopy.tSync("Laitiers entiers", en: "Full-fat dairy"),
                AppCopy.tSync("Poisson (si pescétarien)", en: "Fish (if pescatarian)"),
                AppCopy.tSync("Tubercules", en: "Tubers"),
                AppCopy.tSync("Fruits modérés", en: "Moderate fruit")
            ]
            principles.append(AppCopy.tSync(
                "Aliments entiers denses — pas de multivitamines",
                en: "Dense whole foods — no multivitamins"
            ))
        }
        if restrictions.contains(DietaryRestriction.lactoseFree.rawValue) {
            prioritize.removeAll {
                $0.contains("Laitiers") || $0.localizedCaseInsensitiveContains("dairy")
            }
        }

        if bodyFat == "soft" || bodyFat == "high" || snapshot.bodyFatGap >= 4 {
            principles.append(AppCopy.tSync(
                "Léger déficit via densité alimentaire — pas de famine (préserve le visage)",
                en: "Light deficit via food density — no crash dieting (protects the face)"
            ))
        } else if bodyFat == "very_lean" || bodyFat == "athletic" || snapshot.bodyFatGap < 2 {
            principles.append(AppCopy.tSync(
                "Maintien ou léger surplus via laitiers / tubercules — pas de restriction",
                en: "Maintain or slight surplus via dairy / tubers — no restriction"
            ))
        }

        if multi("animal_protein", in: answers).contains("none") {
            principles.append(AppCopy.tSync(
                "Protéines animales ou œufs à chaque repas principal — carences = peau terne",
                en: "Animal protein or eggs at every main meal — deficiencies = dull skin"
            ))
        }

        if choice("alcohol_frequency", in: answers) == "often" {
            principles.append(AppCopy.tSync(
                "Alcool = debloat garanti — couper en semaine 1",
                en: "Alcohol = guaranteed bloat — cut in week 1"
            ))
        }

        if choice("processed_food", in: answers) == "most_meals" || choice("processed_food", in: answers) == "daily" {
            principles.append(AppCopy.tSync(
                "Priorité : remplacer l'industriel par des repas simples faits maison",
                en: "Priority: replace ultra-processed with simple home-cooked meals"
            ))
        }

        var nutrition = OriginNutritionProtocol(
            principles: principles,
            dailyStructure: [
                AppCopy.tSync(
                    "Repas denses : protéines + tubercule ou légumes cuits",
                    en: "Dense meals: protein + tuber or cooked vegetables"
                ),
                AppCopy.tSync(
                    "Idées de repas via l'IA dans le journal (pas de menu imposé)",
                    en: "Meal ideas via AI in the journal (no fixed menu)"
                ),
                AppCopy.tSync(
                    "Collation optionnelle si faim réelle : fromage entier ou fruit",
                    en: "Optional snack if truly hungry: full-fat cheese or fruit"
                ),
                AppCopy.tSync(
                    "Dîner léger si sommeil fragile",
                    en: "Lighter dinner if sleep is fragile"
                )
            ],
            foodsToPrioritize: prioritize,
            foodsToReduce: reduce,
            hydrationGuide: AppCopy.tSync(
                "Objectif \(targets.hydrationLabel)/jour — répartis, pas d'excès le soir (debloat visage)",
                en: "Goal \(targets.hydrationLabel)/day — spread out, no excess at night (face debloat)"
            ),
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
            AppCopy.tSync(
                "Lumière chaude / tamisée 2 h avant le coucher",
                en: "Warm / dim light 2 h before bed"
            ),
            AppCopy.tSync(
                "Dernière caféine avant \(ProcessDailyTargets.caffeineCutoffHour) h",
                en: "Last caffeine before \(ProcessDailyTargets.caffeineCutoffHour):00"
            ),
            AppCopy.tSync(
                "Chambre fraîche (\(ProcessDailyTargets.bedroomTempCelsius) °C), obscurité totale",
                en: "Cool room (\(ProcessDailyTargets.bedroomTempCelsius) °C), total darkness"
            )
        ]
        let morning: [String] = [
            AppCopy.tSync(
                "Réveil même heure (marge \(ProcessDailyTargets.sleepScheduleMarginMinutes) min max, week-end inclus)",
                en: "Wake at the same time (\(ProcessDailyTargets.sleepScheduleMarginMinutes) min max margin, weekends included)"
            ),
            AppCopy.tSync(
                "\(ProcessDailyTargets.warmWaterOnWakeML) ml d'eau tiède au réveil",
                en: "\(ProcessDailyTargets.warmWaterOnWakeML) ml warm water on waking"
            ),
            AppCopy.tSync(
                "Circuit lymphatique — sauts, genoux, bras alternés (\(FaceMorningRoutineCatalog.lymphCircuitMinutesLabel))",
                en: "Lymph circuit — jumps, knees, alternating arms (\(FaceMorningRoutineCatalog.lymphCircuitMinutesLabel))"
            ),
            AppCopy.tSync(
                "Glaçons sur le visage \(ProcessDailyTargets.coldFaceRinseSeconds) s",
                en: "Ice on the face \(ProcessDailyTargets.coldFaceRinseSeconds) s"
            ),
            AppCopy.tSync(
                "Hydratation + sel / citron — pas de téléphone au lit",
                en: "Hydration + salt / lemon — no phone in bed"
            )
        ]

        if choice("screen_before_bed", in: answers) == "yes" {
            evening.insert(
                AppCopy.tSync(
                    "Mode avion ou téléphone hors chambre \(ProcessDailyTargets.screenCurfewMinutes) min avant",
                    en: "Airplane mode or phone out of the room \(ProcessDailyTargets.screenCurfewMinutes) min before"
                ),
                at: 0
            )
        }

        if GutHealthIntelligenceGuide.needsGutReset(answers: answers, snapshot: snapshot) {
            for note in GutHealthIntelligenceGuide.sleepNotesForGutReset() {
                if !evening.contains(note) {
                    evening.append(note)
                }
            }
        }

        if choice("caffeine_afternoon", in: answers) == "yes" {
            evening.insert(
                AppCopy.tSync(
                    "Pas de caféine après \(ProcessDailyTargets.caffeineCutoffHour) h — impact direct sur le debloat matinal",
                    en: "No caffeine after \(ProcessDailyTargets.caffeineCutoffHour):00 — direct impact on morning debloat"
                ),
                at: 0
            )
        }

        var sleepProtocol = OriginSleepProtocol(
            targetHours: hours,
            bedtimeWindow: AppCopy.tSync(
                "Cible \(bedtime) (marge \(ProcessDailyTargets.sleepScheduleMarginMinutes) min)",
                en: "Target \(bedtime) (\(ProcessDailyTargets.sleepScheduleMarginMinutes) min margin)"
            ),
            wakeWindow: AppCopy.tSync(
                "Cible \(wake) (marge \(ProcessDailyTargets.sleepScheduleMarginMinutes) min)",
                en: "Target \(wake) (\(ProcessDailyTargets.sleepScheduleMarginMinutes) min margin)"
            ),
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
                AppCopy.tSync(
                    "Séance A : Fessiers / hanches + chaîne postérieure",
                    en: "Session A: Glutes / hips + posterior chain"
                ),
                AppCopy.tSync(
                    "Séance B (option) : Haut du corps léger + core",
                    en: "Session B (optional): Light upper body + core"
                ),
                AppCopy.tSync(
                    "Marche quotidienne prioritaire sur le cardio intensif",
                    en: "Daily walking prioritized over intense cardio"
                )
            ]
        } else {
            template = [
                AppCopy.tSync(
                    "Séance A : Push (épaules, trapèzes, pec) + cou",
                    en: "Session A: Push (shoulders, traps, chest) + neck"
                ),
                AppCopy.tSync(
                    "Séance B : Pull (dos, rear delts) + face pulls",
                    en: "Session B: Pull (back, rear delts) + face pulls"
                ),
                AppCopy.tSync(
                    "Séance C : Jambes + fessiers + chaîne postérieure",
                    en: "Session C: Legs + glutes + posterior chain"
                )
            ]
        }

        if sessions <= 2 {
            template = Array(template.prefix(2))
        } else if sessions == 1 {
            template = [
                AppCopy.tSync(
                    "Full body 2× mouvements composés + face pulls + marche",
                    en: "Full body 2× compound moves + face pulls + walking"
                )
            ]
        }

        var recovery = [
            AppCopy.tSync("Sommeil > séance extra", en: "Sleep > extra session"),
            AppCopy.tSync("Deload aux fins de phase", en: "Deload at phase ends")
        ]
        if injuries.contains("lower_back") {
            recovery.append(AppCopy.tSync(
                "Éviter charges axiales lourdes — hip hinge technique d'abord",
                en: "Avoid heavy axial loading — hip-hinge technique first"
            ))
        }
        if injuries.contains("knees") {
            recovery.append(AppCopy.tSync(
                "Genoux : privilégier hip thrust, RDL léger — pas de squat profond douloureux",
                en: "Knees: prefer hip thrust, light RDL — no painful deep squats"
            ))
        }
        if injuries.contains("shoulders") || injuries.contains("neck") {
            recovery.append(AppCopy.tSync(
                "Épaules/nuque : face pulls et mobilité avant charges lourdes",
                en: "Shoulders/neck: face pulls and mobility before heavy loads"
            ))
        }
        if snapshot.archetype == .stressRecovery || snapshot.archetype == .habitReset {
            recovery.append(AppCopy.tSync(
                "RPE 6–7 max — récupération prioritaire",
                en: "RPE 6–7 max — recovery first"
            ))
        }
        if choice("fatigue_frequency", in: answers) == FatigueFrequency.often.rawValue ||
            choice("fatigue_frequency", in: answers) == FatigueFrequency.always.rawValue {
            recovery.append(AppCopy.tSync(
                "RPE 6–7 max — récupération prioritaire si fatigue fréquente",
                en: "RPE 6–7 max — recovery first if fatigue is frequent"
            ))
        }
        for rule in OriginScriptRulesEngine.trainingConstraints(snapshot: snapshot, answers: answers) {
            if !recovery.contains(rule) { recovery.append(rule) }
        }
        for rule in PostureIntelligenceGuide.trainingPostureNotes(for: answers) {
            if !recovery.contains(rule) { recovery.append(rule) }
        }

        let locationNote: String = {
            switch location {
            case "home":
                return AppCopy.tSync(
                    "Maison — haltères / bandes / poids du corps",
                    en: "Home — dumbbells / bands / bodyweight"
                )
            case "gym":
                return AppCopy.tSync(
                    "Salle — machines + libre",
                    en: "Gym — machines + free weights"
                )
            case "outdoor":
                return AppCopy.tSync(
                    "Extérieur — parc, anneaux, marche",
                    en: "Outdoors — park, rings, walking"
                )
            case "mixed":
                return AppCopy.tSync(
                    "Mixte — adapter selon le jour",
                    en: "Mixed — adapt by day"
                )
            default:
                return gender == .female
                    ? AppCopy.tSync(
                        "1–2 séances intensité + marche — cycle menstruel respecté",
                        en: "1–2 intensity sessions + walking — menstrual cycle respected"
                    )
                    : AppCopy.tSync(
                        "3–4 séances — accent clavicules, trapèzes, épaules, chaîne postérieure",
                        en: "3–4 sessions — focus clavicles, traps, shoulders, posterior chain"
                    )
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
        snapshot: OriginPlanAssessmentSnapshot,
        gender: Gender
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
            mobilityBlocks: postureMobilityBlocks(for: answers, gender: gender),
            breathingWork: PostureIntelligenceGuide.breathingWork(for: answers),
            walkingTargets: AppCopy.tSync(
                "Objectif \(targets.dailySteps) pas + marche consciente (orteils dedans) — HealthKit",
                en: "Goal \(targets.dailySteps) steps + mindful walking (toes in) — HealthKit"
            )
        )
    }

    private static func postureMobilityBlocks(for answers: [String: WelcomePlanAnswer], gender: Gender) -> [String] {
        var blocks = PostureIntelligenceGuide.mobilityBlocks(for: answers, gender: gender)
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

        var faceProtocol = OriginFaceProtocol(
            focusAreas: Array(Set(focus)),
            jawAndTongueWork: [],
            lymphAndFascia: FaceMorningRoutineCatalog.buildSteps(targets: targets),
            scanCadence: ""
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

        faceProtocol.lymphAndFascia = FaceMorningRoutineCatalog.buildSteps(targets: targets)

        return faceProtocol
    }

    private static func buildMindsetNotes(
        answers: [String: WelcomePlanAnswer],
        supplements: String?,
        duration: OriginPlanDuration,
        snapshot: OriginPlanAssessmentSnapshot
    ) -> [String] {
        var notes = [
            AppCopy.tSync(
                "Profil : \(snapshot.archetype.label) — \(snapshot.blockerSummary)",
                en: "Profile: \(snapshot.archetype.label) — \(snapshot.blockerSummary)"
            ),
            AppCopy.tSync(
                "10 % des actions (sommeil, alimentation dense, mewing + posture) = 90 % du résultat visage.",
                en: "10% of actions (sleep, dense nutrition, mewing + posture) = 90% of face results."
            ),
            AppCopy.tSync(
                "Pas de raccourci artificiel. La beauté est la conséquence d'une biologie en ordre.",
                en: "No artificial shortcuts. Beauty is the consequence of ordered biology."
            )
        ]
        if duration.totalWeeks <= 3 {
            notes.insert(
                AppCopy.tSync(
                    "Plan court : exécution stricte > perfection.",
                    en: "Short plan: strict execution > perfection."
                ),
                at: 1
            )
        }
        if supplements == "many" || supplements == "basic" {
            notes.append(AppCopy.tSync(
                "On remplace les compléments par des aliments entiers — œufs, laitiers, viande rouge.",
                en: "We replace supplements with whole foods — eggs, dairy, red meat."
            ))
        }
        if choice("commit_plan", in: answers) == "no" {
            notes.append(AppCopy.tSync(
                "Reviens quand tu es prêt à t'engager — les bases demandent de la constance.",
                en: "Come back when you're ready to commit — the basics need consistency."
            ))
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

        parts.append(AppCopy.tSync("Priorités : \(faceGoal).", en: "Priorities: \(faceGoal)."))
        parts.append(AppCopy.tSync(
            "\(snapshot.archetype.label) — \(duration.rangeLabel) (\(duration.totalWeeks) sem. calendrier).",
            en: "\(snapshot.archetype.label) — \(duration.rangeLabel) (\(duration.totalWeeks) wk calendar)."
        ))
        parts.append(snapshot.blockerSummary + ".")

        if let bmi = snapshot.bmi {
            parts.append(AppCopy.tSync(
                String(format: "Profil : %.1f m · %.0f kg · IMC %.1f.", (snapshot.heightCm ?? 0) / 100, snapshot.weightKg ?? 0, bmi),
                en: String(format: "Profile: %.1f m · %.0f kg · BMI %.1f.", (snapshot.heightCm ?? 0) / 100, snapshot.weightKg ?? 0, bmi)
            ))
        }
        if let bf = snapshot.estimatedBodyFatPercent {
            parts.append(AppCopy.tSync(
                String(format: "Masse grasse estimée ~%.0f %% → cible ~%.0f %%.", bf, snapshot.targetBodyFatPercent),
                en: String(format: "Estimated body fat ~%.0f%% → target ~%.0f%%.", bf, snapshot.targetBodyFatPercent)
            ))
        }

        if sleepQ?.contains("Mauvais") == true || sleepQ?.contains("mauvais") == true {
            parts.append(AppCopy.tSync(
                "Priorité #1 : sommeil et rythme circadien — sans ça, le visage reste gonflé.",
                en: "Priority #1: sleep and circadian rhythm — without it, the face stays puffy."
            ))
        }
        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            parts.append(AppCopy.tSync(
                "Alimentation industrielle détectée : transition vers repas denses faits maison.",
                en: "Ultra-processed diet detected: transition to dense home-cooked meals."
            ))
        }
        let planType = ProcessMealPlanConfiguration.readTargetPlan(from: answers)
        parts.append(AppCopy.tSync(
            "Structure repas : \(planType.label).",
            en: "Meal structure: \(planType.label)."
        ))
        parts.append(AppCopy.tSync(
            "\(sessions) séances/semaine + marche (HealthKit) + mewing & travail maxillaire.",
            en: "\(sessions) sessions/week + walking (HealthKit) + mewing & maxillary work."
        ))
        if let firstPhase = assessment.phaseRoadmap.first {
            parts.append(AppCopy.tSync(
                "\(firstPhase.weeksRange) : \(firstPhase.title). Le visage suit la biologie, pas l'inverse.",
                en: "\(firstPhase.weeksRange): \(firstPhase.title). The face follows biology, not the reverse."
            ))
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
