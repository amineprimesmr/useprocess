import Foundation

// MARK: - Archetypes

enum OriginPlanArchetype: String, Codable, CaseIterable, Identifiable {
    case habitReset
    case recomposition
    case foundationBuild
    case maintenancePolish
    case stressRecovery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .habitReset: return "Reset express"
        case .recomposition: return "Recomposition"
        case .foundationBuild: return "Fondations"
        case .maintenancePolish: return "Affinage"
        case .stressRecovery: return "Récupération stress"
        }
    }

    var subtitle: String {
        switch self {
        case .habitReset:
            return "Habitudes à corriger — composition déjà correcte"
        case .recomposition:
            return "Perte de masse grasse avant affinage visage"
        case .foundationBuild:
            return "Construction progressive des 4 piliers"
        case .maintenancePolish:
            return "Peaufinage posture, fascias et scan"
        case .stressRecovery:
            return "Sommeil et cortisol avant tout le reste"
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

    static let currentVersion = 1
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
        let estimatedBF = estimateBodyFat(
            height: height,
            weight: weight,
            age: age,
            gender: gender,
            subjectiveFeel: answers["body_fat_feel"]?.choiceIds.first
        )
        let targetBF = gender == .female ? 20.0 : 14.0
        let bodyFatGap = max(0, estimatedBF - targetBF)

        let habitSeverity = computeHabitSeverity(answers: answers)
        let concernCount = answers["face_concerns"]?.choiceIds.count ?? 0
        let primaryBlocker = detectPrimaryBlocker(answers: answers, bodyFatGap: bodyFatGap, bmi: bmi)
        let archetype = selectArchetype(
            answers: answers,
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
            concernCount: concernCount
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
            assessmentVersion: OriginPlanAssessmentSnapshot.currentVersion
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
        bmi: Double?,
        bodyFatGap: Double,
        habitSeverity: Int,
        primaryBlocker: OriginPrimaryBlocker,
        baselineScan: FaceWellnessMarkers?
    ) -> OriginPlanArchetype {
        let feel = choice("body_fat_feel", in: answers)
        let consistency = choice("consistency_history", in: answers)
        let scanPuffiness = baselineScan?.puffinessScore ?? 0

        if primaryBlocker == .stress || primaryBlocker == .sleep {
            if bodyFatGap < 6 && (bmi ?? 22) < 27 {
                return .stressRecovery
            }
        }

        if bodyFatGap >= 8 || (bmi ?? 0) >= 27 || feel == "high" {
            return .recomposition
        }

        if (feel == "very_lean" || feel == "athletic") && bodyFatGap < 3 && habitSeverity < 35 {
            return .maintenancePolish
        }

        if bodyFatGap < 4 && habitSeverity >= 20 && (bmi ?? 22) >= 18.5 && (bmi ?? 22) <= 26 {
            if scanPuffiness >= 55 || habitSeverity >= 40 {
                return .habitReset
            }
            return .habitReset
        }

        if consistency == "first_time" || consistency == "weeks" {
            return .foundationBuild
        }

        if bodyFatGap >= 4 {
            return .recomposition
        }

        return .foundationBuild
    }

    // MARK: - Duration

    private static func computeDuration(
        archetype: OriginPlanArchetype,
        bodyFatGap: Double,
        habitSeverity: Int,
        answers: [String: WelcomePlanAnswer],
        concernCount: Int
    ) -> OriginPlanDuration {
        var minW: Int
        var maxW: Int

        switch archetype {
        case .habitReset:
            minW = 1
            maxW = habitSeverity >= 50 ? 3 : 2
        case .maintenancePolish:
            minW = 2
            maxW = 4
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
                minW = 12
                maxW = 16
            } else {
                minW = 8
                maxW = 12
            }
        }

        if choice("consistency_history", in: answers) == "first_time" {
            minW += 1
            maxW += 2
        }
        if concernCount >= 3 {
            maxW += 1
        }
        if habitSeverity >= 60 && archetype != .habitReset {
            minW += 1
            maxW += 1
        }

        minW = min(max(1, minW), 20)
        maxW = min(max(minW, maxW), 24)
        let total = min(maxW, max(minW, (minW + maxW + 1) / 2))

        return OriginPlanDuration(minWeeks: minW, maxWeeks: maxW, totalWeeks: total, archetype: archetype)
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
            targets.hydrationLitersPerDay = min(4, max(2, liters))
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
                title: "Reset debloat express",
                objectives: [
                    blockerObjective(blocker),
                    "Dîner léger en sel — fini le gonflement matinal",
                    "Hydratation \(dailyTargets.hydrationLabel) répartie dans la journée"
                ],
                habits: ["Scan visage J1 et J\(p1End)", "Repas structurés", "Sommeil \(Int(dailyTargets.sleepHours)) h"]
            )
        ]
        if total > p1End {
            phases.append(
                .init(
                    id: "consolidate",
                    weeksRange: OriginPlanDuration.weeksRangeLabel(from: p1End + 1, through: total),
                    title: "Consolidation",
                    objectives: [
                        "Ancrer les nouvelles habitudes",
                        "Comparer scan J1 vs fin de protocole",
                        "Passer en mode maintenance si scores OK"
                    ],
                    habits: ["Maintien 80 % des bases", "Scan comparatif", "Routine soir verrouillée"]
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
                title: "Reset biologique",
                objectives: [
                    "Stabiliser sommeil et rythme circadien",
                    "Alimentation dense — pas de famine (préserve le visage)",
                    "Éliminer ultra-transformé et huiles de graines"
                ],
                habits: ["Couvre-feu lumière", "Repas protéinés denses", "\(dailyTargets.dailySteps) pas/jour"]
            ),
            .init(
                id: "recomp",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[0] + 1, through: e[1]),
                title: "Recomposition",
                objectives: [
                    "Déficit léger via densité alimentaire",
                    "\(sessions) séances/semaine progressive overload",
                    "Sel modéré le soir pour debloat visage"
                ],
                habits: ["Séances loguées", "Scan visage bi-hebdo", "Dîner protéines + légumes cuits"]
            ),
            .init(
                id: "face",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[1] + 1, through: e[2]),
                title: "Affinage visage",
                objectives: [
                    "Fascias maxillaire et nuque",
                    "Mewing + mastication consciente",
                    "Affiner selon scan et énergie"
                ],
                habits: ["Massage lymphatique", "Posture active", "Scan comparatif"]
            ),
            .init(
                id: "anchor",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[2] + 1, through: total),
                title: "Consolidation",
                objectives: [
                    "Ancrer composition et habitudes",
                    "Maintien 80 % des bases",
                    "Plan après protocole"
                ],
                habits: ["Bilan scan final", "Routine automatique", "Mode maintenance"]
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
                title: "Fondations — Reset biologique",
                objectives: ["Rythme circadien", "Alimentation dense", "Hydratation \(dailyTargets.hydrationLabel)"],
                habits: ["Couvre-feu lumière", "Repas protéinés", "Marche \(dailyTargets.dailySteps) pas"]
            ),
            .init(
                id: "p2",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[0] + 1, through: e[1]),
                title: "Hormones & digestion",
                objectives: ["Digestion optimale", "Stress ↓", "Mastication \(dailyTargets.chewsPerBite)×"],
                habits: ["Minéraux naturels", "Routine soir", "Scan visage"]
            ),
            .init(
                id: "p3",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[1] + 1, through: e[2]),
                title: "Entraînement & composition",
                objectives: ["\(sessions) séances progressive overload", "Chaîne postérieure", "Composition corporelle"],
                habits: ["Séances loguées", "Sommeil \(Int(dailyTargets.sleepHours)) h+", "Scan régulier"]
            ),
            .init(
                id: "p4",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[2] + 1, through: total),
                title: "Affinage visage & consolidation",
                objectives: ["Affiner si besoin", "Fascias maxillaire", "Ancrage long terme"],
                habits: ["Bilan scan", "Maintien 80 % bases", "Plan après protocole"]
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
                title: "Sommeil & cortisol",
                objectives: [
                    "Priorité absolue : \(Int(dailyTargets.sleepHours)) h de sommeil",
                    "Couvre-feu écrans \(ProcessDailyTargets.screenCurfewMinutes) min"
                ],
                habits: ["Pas de caféine après \(ProcessDailyTargets.caffeineCutoffHour) h", "Chambre \(ProcessDailyTargets.bedroomTempCelsius) °C", "Scan visage"]
            ),
            .init(
                id: "digest",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[0] + 1, through: e[1]),
                title: "Digestion & debloat",
                objectives: ["Repas denses anti-inflammatoires", "Sel modéré le soir", "Hydratation \(dailyTargets.hydrationLabel)"],
                habits: ["Dîner léger", "Marche post-repas", "Scan comparatif"]
            ),
            .init(
                id: "build",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[1] + 1, through: total),
                title: "Construction progressive",
                objectives: ["Introduire entraînement léger", "Posture et mewing", "Consolidation visage"],
                habits: ["2 séances max", "Routine soir", "Scan final"]
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
                title: "Affinage posture & fascias",
                objectives: ["Mewing intensif", "Travail SCM / nuque", "Massage lymphatique"],
                habits: ["Mastication consciente", "Scan visage", "\(sessions) séances légères"]
            ),
            .init(
                id: "maintain",
                weeksRange: OriginPlanDuration.weeksRangeLabel(from: e[0] + 1, through: total),
                title: "Maintenance",
                objectives: ["Verrouiller les bases", "Scan comparatif", "Mode long terme"],
                habits: ["80 % des bases", "Scan final", "Routine automatique"]
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
        case .sleep: return "Sommeil réparateur en priorité"
        case .nutrition: return "Remplacer l'industriel par repas denses faits maison"
        case .composition: return "Recomposition progressive — pas de famine"
        case .posture: return "Posture cervicale + mewing quotidien"
        case .stress: return "Baisser cortisol — sommeil et respiration d'abord"
        case .habits: return "Reset habitudes debloat (sel, hydratation, repas)"
        }
    }

    private static func blockerSummary(for blocker: OriginPrimaryBlocker, bodyFatGap: Double) -> String {
        switch blocker {
        case .composition:
            return "Écart masse grasse ~\(Int(bodyFatGap.rounded())) pts vs cible — recomposition avant affinage max"
        case .sleep: return "Sommeil fragile — sans ça le visage reste gonflé"
        case .nutrition: return "Alimentation industrielle — transition vers repas denses"
        case .posture: return "Posture et respiration impactent direct la structure faciale"
        case .stress: return "Stress chronique — cortisol élevé, cernes et rétention d'eau"
        case .habits: return "Habitudes à corriger — composition déjà proche de la cible"
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
                    label: "Gonflement visage",
                    detail: "Réduire le score puffiness vs baseline",
                    metricKey: "puffinessScore",
                    targetValue: max(20, scan.puffinessScore - 15),
                    baselineValue: scan.puffinessScore
                )
            )
            criteria.append(
                .init(
                    label: "Teint / peau",
                    detail: "Améliorer skinClarity (score plus bas = mieux)",
                    metricKey: "skinClarityScore",
                    targetValue: max(15, scan.skinClarityScore - 12),
                    baselineValue: scan.skinClarityScore
                )
            )
        } else {
            criteria.append(
                .init(
                    label: "Scan baseline",
                    detail: "Faire un scan visage en semaine 1 pour calibrer le suivi",
                    metricKey: "baselineScan"
                )
            )
        }

        if bodyFatGap >= 4 {
            criteria.append(
                .init(
                    label: "Composition",
                    detail: "Viser ~\(Int(targetBF)) % masse grasse (estimation)",
                    metricKey: "bodyFatPercent",
                    targetValue: Int(targetBF.rounded())
                )
            )
        }

        if multi("face_concerns", in: answers).contains("dark_circles") {
            criteria.append(
                .init(
                    label: "Cernes",
                    detail: "underEyeFatigue en baisse sur 2+ scans",
                    metricKey: "underEyeFatigueScore",
                    baselineValue: baselineScan?.underEyeFatigueScore
                )
            )
        }

        switch archetype {
        case .habitReset:
            criteria.append(
                .init(label: "Habitudes", detail: "7 jours consécutifs repas validés + sommeil cible")
            )
        case .recomposition:
            criteria.append(
                .init(label: "Consistance", detail: "80 % des tâches journal complétées sur 4 semaines")
            )
        default:
            criteria.append(
                .init(label: "Protocole", detail: "Finir les phases avec scan comparatif positif")
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
