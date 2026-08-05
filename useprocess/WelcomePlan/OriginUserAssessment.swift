import Foundation

// MARK: - Archetypes

enum OriginPlanArchetype: String, Codable, CaseIterable, Identifiable {
    case habitReset
    case recomposition
    case foundationBuild
    case maintenancePolish
    case stressRecovery

    var id: String { rawValue }

    @MainActor
    var label: String {
        switch self {
        case .habitReset: return AppCopy.t("Reset express", en: "Express reset")
        case .recomposition: return AppCopy.t("Recomposition", en: "Recomposition")
        case .foundationBuild: return AppCopy.t("Fondations", en: "Foundations")
        case .maintenancePolish: return AppCopy.t("Affinage", en: "Refinement")
        case .stressRecovery: return AppCopy.t("Récupération stress", en: "Stress recovery")
        }
    }

    @MainActor
    var subtitle: String {
        switch self {
        case .habitReset:
            return AppCopy.t(
                "Habitudes à corriger — composition déjà correcte",
                en: "Habits to fix — composition already solid"
            )
        case .recomposition:
            return AppCopy.t(
                "Perte de masse grasse avant affinage visage",
                en: "Fat loss before facial refinement"
            )
        case .foundationBuild:
            return AppCopy.t(
                "Construction progressive des 4 piliers",
                en: "Progressive build of the 4 pillars"
            )
        case .maintenancePolish:
            return AppCopy.t(
                "Peaufinage posture, fascias et scan",
                en: "Polish posture, fascia, and scan"
            )
        case .stressRecovery:
            return AppCopy.t(
                "Sommeil et cortisol avant tout le reste",
                en: "Sleep and cortisol before everything else"
            )
        }
    }
}

enum OriginPrimaryBlocker: String, Codable {
    case sleep
    case nutrition
    case composition
    case posture
    case stress
    case habits
}

struct OriginSuccessCriterion: Codable, Identifiable, Equatable {
    let id: String
    var label: String
    var detail: String
    var metricKey: String?
    var targetValue: Int?
    var baselineValue: Int?

    init(
        id: String = UUID().uuidString,
        label: String,
        detail: String,
        metricKey: String? = nil,
        targetValue: Int? = nil,
        baselineValue: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.detail = detail
        self.metricKey = metricKey
        self.targetValue = targetValue
        self.baselineValue = baselineValue
    }
}

struct OriginPersonalizedDailyTargets: Codable, Equatable {
    var hydrationLitersPerDay: Int
    var dailySteps: Int
    var sleepHours: Double
    var morningLightMinutes: Int
    var coldFaceRinseSeconds: Int
    var chewsPerBite: Int
    var lymphFaceMassageMinutes: Int
    var outdoorWalkSessionsPerWeek: Int
    var restDaysPerWeek: Int

    static let `default` = OriginPersonalizedDailyTargets(
        hydrationLitersPerDay: ProcessDailyTargets.hydrationLitersPerDay,
        dailySteps: ProcessDailyTargets.dailySteps,
        sleepHours: Double(ProcessDailyTargets.sleepHours),
        morningLightMinutes: ProcessDailyTargets.morningLightMinutes,
        coldFaceRinseSeconds: ProcessDailyTargets.coldFaceRinseSeconds,
        chewsPerBite: ProcessDailyTargets.chewsPerBite,
        lymphFaceMassageMinutes: ProcessDailyTargets.lymphFaceMassageMinutes,
        outdoorWalkSessionsPerWeek: ProcessDailyTargets.outdoorWalkSessionsPerWeek,
        restDaysPerWeek: ProcessDailyTargets.restDaysPerWeek
    )

    var hydrationLabel: String { "\(hydrationLitersPerDay) L" }
}

struct OriginPlanAssessmentSnapshot: Codable, Equatable {
    var archetype: OriginPlanArchetype
    var primaryBlocker: OriginPrimaryBlocker
    var blockerSummary: String
    var bmi: Double?
    var estimatedBodyFatPercent: Double?
    var targetBodyFatPercent: Double
    var bodyFatGap: Double
    var heightCm: Double?
    var weightKg: Double?
    var concernCount: Int
    var habitSeverityScore: Int
    var assessmentVersion: Int
    var trajectoryMode: TrajectoryMode?
    var debloatTargetDays: Int?
    var weightTargetDays: Int?
    var trajectoryTotalDays: Int?

    static let currentVersion = 3
}

// MARK: - Assessment engine

enum OriginUserAssessment {

    struct Result {
        let snapshot: OriginPlanAssessmentSnapshot
        let duration: OriginPlanDuration
        let phaseRoadmap: [OriginPlanPhaseBlock]
        let successCriteria: [OriginSuccessCriterion]
        let dailyTargets: OriginPersonalizedDailyTargets
        let recommendedSessions: Int
        let trainingLocation: String?
    }

    static func evaluate(
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?,
        baselineScan: FaceWellnessMarkers? = nil
    ) -> Result {
        let gender = profile?.gender ?? .male
        let height = profile?.height
        let weight = profile?.weight
        let age = profile?.age ?? 28

        let bmi = computeBMI(height: height, weight: weight)
        let preliminaryFeel = answers["body_fat_feel"]?.choiceIds.first
            ?? PlanDurationPersonalizer.inferredBodyFatFeel(profile: profile, bmi: bmi)
        let estimatedBF = estimateBodyFat(
            height: height,
            weight: weight,
            age: age,
            gender: gender,
            subjectiveFeel: preliminaryFeel
        )
        let targetBF = gender == .female ? 20.0 : 14.0
        let bodyFatGap = max(0, estimatedBF - targetBF)

        let signals = PlanDurationPersonalizer.signals(
            profile: profile,
            answers: answers,
            bodyFatGap: bodyFatGap
        )

        let habitSeverity = computeHabitSeverity(answers: answers)
        let concernCount = answers["face_concerns"]?.choiceIds.count ?? 0
        let primaryBlocker = detectPrimaryBlocker(answers: answers, bodyFatGap: bodyFatGap, bmi: bmi)
        let archetype = selectArchetype(
            answers: answers,
            profile: profile,
            signals: signals,
            bmi: bmi,
            bodyFatGap: bodyFatGap,
            habitSeverity: habitSeverity,
            primaryBlocker: primaryBlocker,
            baselineScan: baselineScan
        )

        let duration = computeDuration(
            archetype: archetype,
            bodyFatGap: bodyFatGap,
            habitSeverity: habitSeverity,
            answers: answers,
            concernCount: concernCount,
            signals: signals,
            profile: profile
        )
        let dailyTargets = buildDailyTargets(
            answers: answers,
            profile: profile,
            archetype: archetype,
            bmi: bmi
        )
        let sessions = recommendedSessions(answers: answers, archetype: archetype, bodyFatGap: bodyFatGap)
        let phaseRoadmap = buildPhaseRoadmap(
            archetype: archetype,
            duration: duration,
            sessions: sessions,
            primaryBlocker: primaryBlocker,
            dailyTargets: dailyTargets
        )
        let successCriteria = buildSuccessCriteria(
            archetype: archetype,
            answers: answers,
            baselineScan: baselineScan,
            bodyFatGap: bodyFatGap,
            targetBF: targetBF
        )

        let trajectory = buildTrajectory(
            profile: profile,
            signals: signals,
            habitSeverity: habitSeverity
        )

        let snapshot = OriginPlanAssessmentSnapshot(
            archetype: archetype,
            primaryBlocker: primaryBlocker,
            blockerSummary: blockerSummary(for: primaryBlocker, bodyFatGap: bodyFatGap),
            bmi: bmi,
            estimatedBodyFatPercent: estimatedBF,
            targetBodyFatPercent: targetBF,
            bodyFatGap: bodyFatGap,
            heightCm: height,
            weightKg: weight,
            concernCount: concernCount,
            habitSeverityScore: habitSeverity,
            assessmentVersion: OriginPlanAssessmentSnapshot.currentVersion,
            trajectoryMode: trajectory.mode,
            debloatTargetDays: trajectory.debloatDays,
            weightTargetDays: trajectory.weightDays,
            trajectoryTotalDays: trajectory.totalDays
        )

        return Result(
            snapshot: snapshot,
            duration: duration,
            phaseRoadmap: phaseRoadmap,
            successCriteria: successCriteria,
            dailyTargets: dailyTargets,
            recommendedSessions: sessions,
            trainingLocation: answers["training_location"]?.choiceIds.first
        )
    }

    // MARK: - Body composition

    static func computeBMI(height: Double?, weight: Double?) -> Double? {
        guard let height, let weight, height > 0 else { return nil }
        let m = height / 100.0
        return weight / (m * m)
    }

    static func estimateBodyFat(
        height: Double?,
        weight: Double?,
        age: Int,
        gender: Gender,
        subjectiveFeel: String?
    ) -> Double {
        var estimated: Double?

        if let height, let weight, height > 0, weight > 0 {
            let comp = BodyCompositionEstimate.calculate(
                height: height,
                weight: weight,
                age: age,
                gender: gender
            )
            estimated = comp.bodyFatPercentage
        }

        let subjective = subjectiveBodyFatPercent(feel: subjectiveFeel)

        if let estimated, let subjective {
            return (estimated * 0.65) + (subjective * 0.35)
        }
        return estimated ?? subjective ?? (gender == .female ? 24 : 18)
    }

    private static func subjectiveBodyFatPercent(feel: String?) -> Double? {
        switch feel {
        case "very_lean": return 10
        case "athletic": return 14
        case "normal": return 18
        case "soft": return 23
        case "high": return 28
        default: return nil
        }
    }

    // MARK: - Scoring

    private static func computeHabitSeverity(answers: [String: WelcomePlanAnswer]) -> Int {
        var score = 0
        if choice("processed_food", in: answers) == "daily" { score += 25 }
        else if choice("processed_food", in: answers) == "most_meals" { score += 18 }
        else if choice("processed_food", in: answers) == "few_week" { score += 8 }

        let sleep = choice("sleep_quality", in: answers) ?? ""
        if sleep.contains("Très mauvais") { score += 25 }
        else if sleep.contains("Mauvais") { score += 18 }
        else if sleep.contains("Moyen") { score += 8 }

        if choice("screen_before_bed", in: answers) == "yes" { score += 10 }
        if choice("caffeine_afternoon", in: answers) == "yes" { score += 8 }
        if choice("alcohol_frequency", in: answers) == "often" { score += 12 }
        else if choice("alcohol_frequency", in: answers) == "weekly" { score += 6 }

        let hydration = choice("hydration_level", in: answers) ?? ""
        if hydration == HydrationLevel.poor.rawValue || hydration == HydrationLevel.veryPoor.rawValue {
            score += 8
        }

        if choice("morning_sunlight", in: answers) == "never" || choice("morning_sunlight", in: answers) == "rarely" {
            score += 8
        }
        return min(100, score)
    }

    private static func detectPrimaryBlocker(
        answers: [String: WelcomePlanAnswer],
        bodyFatGap: Double,
        bmi: Double?
    ) -> OriginPrimaryBlocker {
        if bodyFatGap >= 8 || (bmi ?? 0) >= 28 {
            return .composition
        }

        let sleep = choice("sleep_quality", in: answers) ?? ""
        let fatigue = choice("fatigue_frequency", in: answers)
        let concerns = multi("face_concerns", in: answers)
        if (sleep.contains("Mauvais") || sleep.contains("Très mauvais")) &&
            (concerns.contains("dark_circles") || concerns.contains("acne") || concerns.contains("puffiness")) {
            return .stress
        }
        if sleep.contains("Mauvais") || sleep.contains("Très mauvais") || fatigue == FatigueFrequency.always.rawValue {
            return .sleep
        }
        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            return .nutrition
        }
        if choice("forward_head", in: answers) == "yes" || choice("mouth_breathing", in: answers) == "yes" {
            return .posture
        }
        if bodyFatGap >= 4 {
            return .composition
        }
        return .habits
    }

    private static func selectArchetype(
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?,
        signals: PlanDurationPersonalizer.ProfileSignals,
        bmi: Double?,
        bodyFatGap: Double,
        habitSeverity: Int,
        primaryBlocker: OriginPrimaryBlocker,
        baselineScan: FaceWellnessMarkers?
    ) -> OriginPlanArchetype {
        let feel = choice("body_fat_feel", in: answers) ?? signals.inferredBodyFatFeel
        let consistency = choice("consistency_history", in: answers)
        let scanPuffiness = baselineScan?.puffinessScore ?? 0
        let weightGap = signals.weightGapKg ?? 99
        let leanBMI = (bmi ?? 25) < 26

        if primaryBlocker == .stress || primaryBlocker == .sleep {
            if bodyFatGap < 6 && (bmi ?? 22) < 27 {
                return .stressRecovery
            }
        }

        // Profil sportif proche de la cible → debloat express, pas recomposition longue.
        if signals.isDebloatFocused && weightGap <= 6 && leanBMI && signals.isSporty {
            if habitSeverity >= 35 || scanPuffiness >= 50 {
                return .habitReset
            }
            return .maintenancePolish
        }

        if bodyFatGap >= 8 || (bmi ?? 0) >= 27 || feel == "high" {
            return .recomposition
        }

        if (feel == "very_lean" || feel == "athletic") && bodyFatGap < 4 && habitSeverity < 40 {
            return .maintenancePolish
        }

        if bodyFatGap < 5 && habitSeverity >= 15 && leanBMI {
            return .habitReset
        }

        if consistency == "first_time" || consistency == "weeks" {
            return .foundationBuild
        }

        if bodyFatGap >= 6 {
            return .recomposition
        }

        if signals.isDebloatFocused && weightGap <= 8 {
            return .habitReset
        }

        return .foundationBuild
    }

    // MARK: - Duration

    private static func computeDuration(
        archetype: OriginPlanArchetype,
        bodyFatGap: Double,
        habitSeverity: Int,
        answers: [String: WelcomePlanAnswer],
        concernCount: Int,
        signals: PlanDurationPersonalizer.ProfileSignals,
        profile: UnifiedUserProfile?
    ) -> OriginPlanDuration {
        let trajectory = buildTrajectory(
            profile: profile,
            signals: signals,
            habitSeverity: habitSeverity
        )

        var minW: Int
        var maxW: Int

        switch archetype {
        case .habitReset:
            if signals.isLean && (signals.weightGapKg ?? 99) <= 5 {
                minW = 1
                maxW = habitSeverity >= 45 ? 2 : 1
            } else {
                minW = 1
                maxW = habitSeverity >= 50 ? 3 : 2
            }
        case .maintenancePolish:
            if signals.isLean && (signals.weightGapKg ?? 99) <= 5 {
                minW = 2
                maxW = 3
            } else {
                minW = 2
                maxW = 4
            }
        case .stressRecovery:
            minW = 4
            maxW = 8
        case .foundationBuild:
            minW = 8
            maxW = 12
        case .recomposition:
            if bodyFatGap >= 12 {
                minW = 16
                maxW = 20
            } else if bodyFatGap >= 8 {
                minW = 10
                maxW = 14
            } else if signals.isLean {
                minW = 5
                maxW = 8
            } else {
                minW = 8
                maxW = 12
            }
        }

        if choice("consistency_history", in: answers) == "first_time" {
            minW += 1
            maxW += 2
        }
        if concernCount >= 3 && archetype != .habitReset {
            maxW += 1
        }
        if habitSeverity >= 60 && archetype != .habitReset {
            minW += 1
            maxW += 1
        }

        let trajectoryWeeks = max(1, Int(ceil(Double(trajectory.debloatDays) / 7.0)))
        let phaseWeeks = max(1, Int(ceil(Double(trajectory.planPhaseOneDays) / 7.0)))

        minW = min(minW, phaseWeeks)
        maxW = min(maxW, trajectoryWeeks)

        if let weekCap = PlanDurationPersonalizer.weightGapWeekCap(
            weightGap: signals.weightGapKg,
            signals: signals
        ) {
            maxW = min(maxW, weekCap)
            minW = min(minW, maxW)
        }

        let sportReduction = PlanDurationPersonalizer.sportWeekReduction(signals: signals)
        if sportReduction > 0 && archetype != .foundationBuild {
            minW = max(1, minW - sportReduction)
            maxW = max(minW, maxW - sportReduction)
        }

        minW = min(max(1, minW), 20)
        maxW = min(max(minW, maxW), 24)
        let totalWeeks = trajectoryWeeks

        return OriginPlanDuration(minWeeks: minW, maxWeeks: max(totalWeeks, minW), totalWeeks: totalWeeks, archetype: archetype)
    }

    static func buildTrajectory(
        profile: UnifiedUserProfile?,
        signals: PlanDurationPersonalizer.ProfileSignals,
        habitSeverity: Int,
        now: Date = Date()
    ) -> TrajectoryTimeline {
        let debloatDays = PlanDurationPersonalizer.debloatDays(
            signals: signals,
            habitSeverity: habitSeverity
        )
        let weightDays = weightTargetDays(profile: profile, signals: signals)
        let weightLabel: String?
        if let ideal = profile?.idealWeight, ideal > 0 {
            weightLabel = "\(Int(ideal.rounded())) kg"
        } else {
            weightLabel = nil
        }

        return PlanDurationPersonalizer.computeTimeline(
            signals: signals,
            weightDays: weightDays,
            debloatDays: debloatDays,
            hasWeightGoal: weightDays != nil,
            weightLabel: weightLabel,
            now: now
        )
    }

    private static func weightTargetDays(
        profile: UnifiedUserProfile?,
        signals: PlanDurationPersonalizer.ProfileSignals
    ) -> Int? {
        guard let current = profile?.weight, current > 0,
              let ideal = profile?.idealWeight, ideal > 0 else { return nil }
        let delta = abs(current - ideal)
        guard delta >= 0.5 else { return nil }

        var weeklyRate = profile?.goalPace?.weightEstimationWeeklyRate ?? 0.7
        if let age = profile?.age, age <= 25 {
            weeklyRate = max(weeklyRate, 0.85)
        }
        if delta <= 3 { weeklyRate *= 1.18 }
        else if delta <= 6 { weeklyRate *= 1.12 }
        else if delta <= 10 { weeklyRate *= 1.08 }

        if let level = profile?.experienceLevel {
            switch level {
            case .intermediaire: weeklyRate *= 1.07
            case .amateur: weeklyRate *= 1.14
            case .professionnel: weeklyRate *= 1.2
            default: break
            }
        }
        if (profile?.sessionsPerWeek ?? 0) >= 3 { weeklyRate *= 1.08 }
        if let age = profile?.age {
            if age <= 22 { weeklyRate *= 1.12 }
            else if age <= 28 { weeklyRate *= 1.08 }
        }

        return PlanDurationPersonalizer.onboardingWeightGoalDays(
            delta: delta,
            weeklyRate: weeklyRate,
            signals: signals
        )
    }

    // MARK: - Daily targets

    private static func buildDailyTargets(
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?,
        archetype: OriginPlanArchetype,
        bmi: Double?
    ) -> OriginPersonalizedDailyTargets {
        var targets = OriginPersonalizedDailyTargets.default

        if let weight = profile?.weight, weight > 0 {
            let liters = Int((weight * 0.033).rounded())
            targets.hydrationLitersPerDay = min(4, max(ProcessDailyTargets.hydrationLitersPerDay, liters))
        }

        if choice("hydration_level", in: answers) == HydrationLevel.poor.rawValue
            || choice("hydration_level", in: answers) == HydrationLevel.veryPoor.rawValue {
            targets.hydrationLitersPerDay = min(4, targets.hydrationLitersPerDay + 1)
        }

        switch archetype {
        case .habitReset, .stressRecovery:
            targets.dailySteps = 7000
        case .recomposition:
            targets.dailySteps = 9000
        case .maintenancePolish:
            targets.dailySteps = 6500
        default:
            break
        }

        let sleep = choice("sleep_quality", in: answers) ?? ""
        if sleep.contains("Mauvais") || sleep.contains("Très mauvais") {
            targets.sleepHours = 8.5
        }

        if choice("desk_job", in: answers) == "yes" {
            targets.dailySteps = max(targets.dailySteps, 8500)
        }

        if (bmi ?? 22) >= 28 {
            targets.dailySteps = max(targets.dailySteps, 9000)
        }

        return targets
    }

    private static func recommendedSessions(
        answers: [String: WelcomePlanAnswer],
        archetype: OriginPlanArchetype,
        bodyFatGap: Double
    ) -> Int {
        let chosen = sessionsFromAnswers(answers)
        switch archetype {
        case .habitReset, .maintenancePolish:
            return min(chosen, 2)
        case .stressRecovery:
            return min(chosen, 3)
        case .recomposition:
            return max(chosen, bodyFatGap >= 8 ? 3 : 2)
        case .foundationBuild:
            return chosen
        }
    }

    static func sessionsFromAnswers(_ answers: [String: WelcomePlanAnswer]) -> Int {
        switch choice("sessions_per_week", in: answers) {
        case "1": return 1
        case "2": return 2
        case "3": return 3
        case "4": return 4
        case "5plus": return 5
        default: return 3
        }
    }

    // MARK: - Phases

    private static func buildPhaseRoadmap(
        archetype: OriginPlanArchetype,
        duration: OriginPlanDuration,
        sessions: Int,
        primaryBlocker: OriginPrimaryBlocker,
        dailyTargets: OriginPersonalizedDailyTargets
    ) -> [OriginPlanPhaseBlock] {
        let ends = duration.phaseWeekEnds
        let total = duration.totalWeeks

        switch archetype {
        case .habitReset:
            return habitResetPhases(ends: ends, total: total, dailyTargets: dailyTargets, blocker: primaryBlocker)
        case .maintenancePolish:
            return maintenancePhases(ends: ends, total: total, sessions: sessions)
        case .stressRecovery:
            return stressRecoveryPhases(ends: ends, total: total, dailyTargets: dailyTargets)
        case .recomposition:
            return recompositionPhases(ends: ends, total: total, sessions: sessions, dailyTargets: dailyTargets)
        case .foundationBuild:
            return foundationPhases(ends: ends, total: total, sessions: sessions, dailyTargets: dailyTargets)
        }
    }

    private static func habitResetPhases(
        ends: [Int],
        total: Int,
        dailyTargets: OriginPersonalizedDailyTargets,
        blocker: OriginPrimaryBlocker
    ) -> [OriginPlanPhaseBlock] {
        let p1End = ends.first ?? min(1, total)
        var phases: [OriginPlanPhaseBlock] = [
            .init(
                id: "express",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: 1, through: p1End),
                title: AppCopy.tSync("Reset debloat express", en: "Express debloat reset"),
                objectives: [
                    blockerObjective(blocker),
                    AppCopy.tSync("Dîner léger en sel — fini le gonflement matinal", en: "Light low-salt dinner — end morning puffiness"),
                    AppCopy.tSync("Hydratation \(dailyTargets.hydrationLabel) répartie dans la journée", en: "Hydration \(dailyTargets.hydrationLabel) spread across the day")
                ],
                habits: [AppCopy.tSync("Scan visage J1 et J\(p1End)", en: "Face scan D1 and D\(p1End)"), AppCopy.tSync("Repas structurés", en: "Structured meals"), AppCopy.tSync("Sommeil \(Int(dailyTargets.sleepHours)) h", en: "Sleep \(Int(dailyTargets.sleepHours)) h")]
            )
        ]
        if total > p1End {
            phases.append(
                .init(
                    id: "consolidate",
                    weeksRange: OriginPlanDuration.weeksRangeLabel(from: p1End + 1, through: total),
                    title: AppCopy.tSync("Consolidation", en: "Consolidation"),
                    objectives: [
                        AppCopy.tSync("Ancrer les nouvelles habitudes", en: "Lock in the new habits"),
                        AppCopy.tSync("Comparer scan J1 vs fin du plan personnalisé", en: "Compare D1 scan vs end of personalized plan"),
                        AppCopy.tSync("Passer en mode maintenance si scores OK", en: "Switch to maintenance if scores look good")
                    ],
                    habits: [AppCopy.tSync("Maintien 80 % des bases", en: "Keep 80% of the basics"), AppCopy.tSync("Scan comparatif", en: "Comparative scan"), AppCopy.tSync("Routine soir verrouillée", en: "Evening routine locked in")]
                )
            )
        }
        return phases
    }

    private static func recompositionPhases(
        ends: [Int],
        total: Int,
        sessions: Int,
        dailyTargets: OriginPersonalizedDailyTargets
    ) -> [OriginPlanPhaseBlock] {
        let e = paddedEnds(ends, count: 4, total: total)
        return [
            .init(
                id: "reset",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: 1, through: e[0]),
                title: AppCopy.tSync("Reset biologique", en: "Biological reset"),
                objectives: [
                    AppCopy.tSync("Stabiliser sommeil et rythme circadien", en: "Stabilize sleep and circadian rhythm"),
                    AppCopy.tSync("Alimentation dense — pas de famine (préserve le visage)", en: "Dense nutrition — no crash dieting (protects the face)"),
                    AppCopy.tSync("Éliminer ultra-transformé et huiles de graines", en: "Cut ultra-processed food and seed oils")
                ],
                habits: [AppCopy.tSync("Couvre-feu lumière", en: "Light curfew"), AppCopy.tSync("Repas protéinés denses", en: "Dense protein meals"), AppCopy.tSync("\(dailyTargets.dailySteps) pas/jour", en: "\(dailyTargets.dailySteps) steps/day")]
            ),
            .init(
                id: "recomp",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[0] + 1, through: e[1]),
                title: AppCopy.tSync("Recomposition", en: "Recomposition"),
                objectives: [
                    AppCopy.tSync("Déficit léger via densité alimentaire", en: "Light deficit via food density"),
                    AppCopy.tSync("\(sessions) séances/semaine progressive overload", en: "\(sessions) sessions/week progressive overload"),
                    AppCopy.tSync("Sel modéré le soir pour debloat visage", en: "Moderate evening salt for face debloat")
                ],
                habits: [AppCopy.tSync("Séances loguées", en: "Logged sessions"), AppCopy.tSync("Scan visage bi-hebdo", en: "Biweekly face scan"), AppCopy.tSync("Dîner protéines + légumes cuits", en: "Dinner: protein + cooked veggies")]
            ),
            .init(
                id: "face",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[1] + 1, through: e[2]),
                title: AppCopy.tSync("Affinage visage", en: "Face refinement"),
                objectives: [
                    AppCopy.tSync("Fascias maxillaire et nuque", en: "Maxillary and neck fascia"),
                    AppCopy.tSync("Mewing + mastication consciente", en: "Mewing + mindful chewing"),
                    AppCopy.tSync("Affiner selon scan et énergie", en: "Refine based on scan and energy")
                ],
                habits: [AppCopy.tSync("Massage lymphatique", en: "Lymphatic massage"), AppCopy.tSync("Posture active", en: "Active posture"), AppCopy.tSync("Scan comparatif", en: "Comparative scan")]
            ),
            .init(
                id: "anchor",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[2] + 1, through: total),
                title: AppCopy.tSync("Consolidation", en: "Consolidation"),
                objectives: [
                    AppCopy.tSync("Ancrer composition et habitudes", en: "Lock composition and habits"),
                    AppCopy.tSync("Maintien 80 % des bases", en: "Keep 80% of the basics"),
                    AppCopy.tSync("Plan de maintien", en: "Maintenance plan")
                ],
                habits: [AppCopy.tSync("Bilan scan final", en: "Final scan review"), AppCopy.tSync("Routine automatique", en: "Automatic routine"), AppCopy.tSync("Mode maintenance", en: "Maintenance mode")]
            )
        ]
    }

    private static func foundationPhases(
        ends: [Int],
        total: Int,
        sessions: Int,
        dailyTargets: OriginPersonalizedDailyTargets
    ) -> [OriginPlanPhaseBlock] {
        let e = paddedEnds(ends, count: 4, total: total)
        return [
            .init(
                id: "p1",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: 1, through: e[0]),
                title: AppCopy.tSync("Fondations — Reset biologique", en: "Foundations — Biological reset"),
                objectives: [AppCopy.tSync("Rythme circadien", en: "Circadian rhythm"), AppCopy.tSync("Alimentation dense", en: "Dense nutrition"), AppCopy.tSync("Hydratation \(dailyTargets.hydrationLabel)", en: "Hydration \(dailyTargets.hydrationLabel)")],
                habits: [AppCopy.tSync("Couvre-feu lumière", en: "Light curfew"), AppCopy.tSync("Repas protéinés", en: "Protein meals"), AppCopy.tSync("Marche \(dailyTargets.dailySteps) pas", en: "Walk \(dailyTargets.dailySteps) steps")]
            ),
            .init(
                id: "p2",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[0] + 1, through: e[1]),
                title: AppCopy.tSync("Hormones & digestion", en: "Hormones & digestion"),
                objectives: [AppCopy.tSync("Digestion optimale", en: "Optimal digestion"), AppCopy.tSync("Stress ↓", en: "Stress ↓"), AppCopy.tSync("Mastication \(dailyTargets.chewsPerBite)×", en: "Chewing \(dailyTargets.chewsPerBite)×")],
                habits: [AppCopy.tSync("Minéraux naturels", en: "Natural minerals"), AppCopy.tSync("Routine soir", en: "Evening routine"), AppCopy.tSync("Scan visage", en: "Face scan")]
            ),
            .init(
                id: "p3",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[1] + 1, through: e[2]),
                title: AppCopy.tSync("Entraînement & composition", en: "Training & composition"),
                objectives: [AppCopy.tSync("\(sessions) séances progressive overload", en: "\(sessions) progressive-overload sessions"), AppCopy.tSync("Chaîne postérieure", en: "Posterior chain"), AppCopy.tSync("Composition corporelle", en: "Body composition")],
                habits: [AppCopy.tSync("Séances loguées", en: "Logged sessions"), AppCopy.tSync("Sommeil \(Int(dailyTargets.sleepHours)) h+", en: "Sleep \(Int(dailyTargets.sleepHours)) h+"), AppCopy.tSync("Scan régulier", en: "Regular scan")]
            ),
            .init(
                id: "p4",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[2] + 1, through: total),
                title: AppCopy.tSync("Affinage visage & consolidation", en: "Face refinement & consolidation"),
                objectives: [AppCopy.tSync("Affiner si besoin", en: "Refine if needed"), AppCopy.tSync("Fascias maxillaire", en: "Maxillary fascia"), AppCopy.tSync("Ancrage long terme", en: "Long-term anchoring")],
                habits: [AppCopy.tSync("Bilan scan", en: "Scan review"), AppCopy.tSync("Maintien 80 % bases", en: "Keep 80% basics"), AppCopy.tSync("Plan de maintien", en: "Maintenance plan")]
            )
        ]
    }

    private static func stressRecoveryPhases(
        ends: [Int],
        total: Int,
        dailyTargets: OriginPersonalizedDailyTargets
    ) -> [OriginPlanPhaseBlock] {
        let e = paddedEnds(ends, count: 3, total: total)
        return [
            .init(
                id: "sleep",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: 1, through: e[0]),
                title: AppCopy.tSync("Sommeil & cortisol", en: "Sleep & cortisol"),
                objectives: [
                    AppCopy.tSync("Priorité absolue : \(Int(dailyTargets.sleepHours)) h de sommeil", en: "Absolute priority: \(Int(dailyTargets.sleepHours)) h of sleep"),
                    AppCopy.tSync("Couvre-feu écrans \(ProcessDailyTargets.screenCurfewMinutes) min", en: "Screen curfew \(ProcessDailyTargets.screenCurfewMinutes) min")
                ],
                habits: [AppCopy.tSync("Pas de caféine après \(ProcessDailyTargets.caffeineCutoffHour) h", en: "No caffeine after \(ProcessDailyTargets.caffeineCutoffHour):00"), AppCopy.tSync("Chambre \(ProcessDailyTargets.bedroomTempCelsius) °C", en: "Room \(ProcessDailyTargets.bedroomTempCelsius) °C"), AppCopy.tSync("Scan visage", en: "Face scan")]
            ),
            .init(
                id: "digest",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[0] + 1, through: e[1]),
                title: AppCopy.tSync("Digestion & debloat", en: "Digestion & debloat"),
                objectives: [AppCopy.tSync("Repas denses anti-inflammatoires", en: "Dense anti-inflammatory meals"), AppCopy.tSync("Sel modéré le soir", en: "Moderate evening salt"), AppCopy.tSync("Hydratation \(dailyTargets.hydrationLabel)", en: "Hydration \(dailyTargets.hydrationLabel)")],
                habits: [AppCopy.tSync("Dîner léger", en: "Light dinner"), AppCopy.tSync("Marche post-repas", en: "Post-meal walk"), AppCopy.tSync("Scan comparatif", en: "Comparative scan")]
            ),
            .init(
                id: "build",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[1] + 1, through: total),
                title: AppCopy.tSync("Construction progressive", en: "Progressive build"),
                objectives: [AppCopy.tSync("Introduire entraînement léger", en: "Introduce light training"), AppCopy.tSync("Posture et mewing", en: "Posture and mewing"), AppCopy.tSync("Consolidation visage", en: "Face consolidation")],
                habits: [AppCopy.tSync("2 séances max", en: "2 sessions max"), AppCopy.tSync("Routine soir", en: "Evening routine"), AppCopy.tSync("Scan final", en: "Final scan")]
            )
        ]
    }

    private static func maintenancePhases(
        ends: [Int],
        total: Int,
        sessions: Int
    ) -> [OriginPlanPhaseBlock] {
        let e = paddedEnds(ends, count: 2, total: total)
        return [
            .init(
                id: "polish",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: 1, through: e[0]),
                title: AppCopy.tSync("Affinage posture & fascias", en: "Posture & fascia polish"),
                objectives: [AppCopy.tSync("Mewing intensif", en: "Intensive mewing"), AppCopy.tSync("Travail SCM / nuque", en: "SCM / neck work"), AppCopy.tSync("Massage lymphatique", en: "Lymphatic massage")],
                habits: [AppCopy.tSync("Mastication consciente", en: "Mindful chewing"), AppCopy.tSync("Scan visage", en: "Face scan"), AppCopy.tSync("\(sessions) séances légères", en: "\(sessions) light sessions")]
            ),
            .init(
                id: "maintain",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[0] + 1, through: total),
                title: AppCopy.tSync("Maintenance", en: "Maintenance"),
                objectives: [AppCopy.tSync("Verrouiller les bases", en: "Lock the basics"), AppCopy.tSync("Scan comparatif", en: "Comparative scan"), AppCopy.tSync("Mode long terme", en: "Long-term mode")],
                habits: [AppCopy.tSync("80 % des bases", en: "80% of the basics"), AppCopy.tSync("Scan final", en: "Final scan"), AppCopy.tSync("Routine automatique", en: "Automatic routine")]
            )
        ]
    }

    private static func paddedEnds(_ ends: [Int], count: Int, total: Int) -> [Int] {
        var result = ends
        while result.count < count {
            let last = result.last ?? total
            let next = min(total, last + max(1, total / count))
            result.append(next)
        }
        return Array(result.prefix(count))
    }

    private static func blockerObjective(_ blocker: OriginPrimaryBlocker) -> String {
        switch blocker {
        case .sleep: return AppCopy.tSync("Sommeil réparateur en priorité", en: "Restorative sleep first")
        case .nutrition: return AppCopy.tSync(
            "Remplacer l'industriel par repas denses faits maison",
            en: "Replace ultra-processed food with dense home-cooked meals"
        )
        case .composition: return AppCopy.tSync(
            "Recomposition progressive — pas de famine",
            en: "Progressive recomposition — no crash dieting"
        )
        case .posture: return AppCopy.tSync(
            "Posture cervicale + mewing quotidien",
            en: "Neck posture + daily mewing"
        )
        case .stress: return AppCopy.tSync(
            "Baisser cortisol — sommeil et respiration d'abord",
            en: "Lower cortisol — sleep and breathing first"
        )
        case .habits: return AppCopy.tSync(
            "Reset habitudes debloat (sel, hydratation, repas)",
            en: "Reset debloat habits (salt, hydration, meals)"
        )
        }
    }

    private static func blockerSummary(for blocker: OriginPrimaryBlocker, bodyFatGap: Double) -> String {
        switch blocker {
        case .composition:
            return AppCopy.tSync(
                "Écart masse grasse ~\(Int(bodyFatGap.rounded())) pts vs cible — recomposition avant affinage max",
                en: "Body-fat gap ~\(Int(bodyFatGap.rounded())) pts vs target — recomp before max refinement"
            )
        case .sleep: return AppCopy.tSync(
            "Sommeil fragile — sans ça le visage reste gonflé",
            en: "Fragile sleep — without it the face stays puffy"
        )
        case .nutrition: return AppCopy.tSync(
            "Alimentation industrielle — transition vers repas denses",
            en: "Ultra-processed diet — transition to dense meals"
        )
        case .posture: return AppCopy.tSync(
            "Posture et respiration impactent direct la structure faciale",
            en: "Posture and breathing directly impact facial structure"
        )
        case .stress: return AppCopy.tSync(
            "Stress chronique — cortisol élevé, cernes et rétention d'eau",
            en: "Chronic stress — high cortisol, under-eyes, and water retention"
        )
        case .habits: return AppCopy.tSync(
            "Habitudes à corriger — composition déjà proche de la cible",
            en: "Habits to fix — composition already near target"
        )
        }
    }

    // MARK: - Success criteria

    private static func buildSuccessCriteria(
        archetype: OriginPlanArchetype,
        answers: [String: WelcomePlanAnswer],
        baselineScan: FaceWellnessMarkers?,
        bodyFatGap: Double,
        targetBF: Double
    ) -> [OriginSuccessCriterion] {
        var criteria: [OriginSuccessCriterion] = []

        if let scan = baselineScan {
            criteria.append(
                .init(
                    label: AppCopy.tSync("Gonflement visage", en: "Face puffiness"),
                    detail: AppCopy.tSync("Réduire le score puffiness vs baseline", en: "Lower puffiness score vs baseline"),
                    metricKey: "puffinessScore",
                    targetValue: max(20, scan.puffinessScore - 15),
                    baselineValue: scan.puffinessScore
                )
            )
            criteria.append(
                .init(
                    label: AppCopy.tSync("Teint / peau", en: "Complexion / skin"),
                    detail: AppCopy.tSync("Améliorer skinClarity (score plus bas = mieux)", en: "Improve skinClarity (lower score = better)"),
                    metricKey: "skinClarityScore",
                    targetValue: max(15, scan.skinClarityScore - 12),
                    baselineValue: scan.skinClarityScore
                )
            )
        } else {
            criteria.append(
                .init(
                    label: AppCopy.tSync("Scan baseline", en: "Baseline scan"),
                    detail: AppCopy.tSync("Faire un scan visage en semaine 1 pour calibrer le suivi", en: "Do a face scan in week 1 to calibrate tracking"),
                    metricKey: "baselineScan"
                )
            )
        }

        if bodyFatGap >= 4 {
            criteria.append(
                .init(
                    label: AppCopy.tSync("Composition", en: "Composition"),
                    detail: AppCopy.tSync("Viser ~\(Int(targetBF)) % masse grasse (estimation)", en: "Target ~\(Int(targetBF))% body fat (estimate)"),
                    metricKey: "bodyFatPercent",
                    targetValue: Int(targetBF.rounded())
                )
            )
        }

        if multi("face_concerns", in: answers).contains("dark_circles") {
            criteria.append(
                .init(
                    label: AppCopy.tSync("Cernes", en: "Under-eyes"),
                    detail: AppCopy.tSync("underEyeFatigue en baisse sur 2+ scans", en: "underEyeFatigue down across 2+ scans"),
                    metricKey: "underEyeFatigueScore",
                    baselineValue: baselineScan?.underEyeFatigueScore
                )
            )
        }

        switch archetype {
        case .habitReset:
            criteria.append(
                .init(label: AppCopy.tSync("Habitudes", en: "Habits"), detail: AppCopy.tSync("7 jours consécutifs repas validés + sommeil cible", en: "7 consecutive days of logged meals + target sleep"))
            )
        case .recomposition:
            criteria.append(
                .init(label: AppCopy.tSync("Consistance", en: "Consistency"), detail: AppCopy.tSync("80 % des tâches journal complétées sur 4 semaines", en: "80% of journal tasks completed over 4 weeks"))
            )
        default:
            criteria.append(
                .init(label: AppCopy.tSync("Plan", en: "Plan"), detail: AppCopy.tSync("Finir les phases avec scan comparatif positif", en: "Finish phases with a positive comparative scan"))
            )
        }

        return criteria
    }

    // MARK: - Answer helpers

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }

    private static func multi(_ id: String, in answers: [String: WelcomePlanAnswer]) -> [String] {
        answers[id]?.choiceIds ?? []
    }
}
