import Foundation

/// Contexte agrégé injecté dans chaque appel Claude (profil, santé, scans, onboarding).
struct CoachUserContext: Codable, Sendable {
    struct ProfileBlock: Codable, Sendable {
        var firstName: String?
        var age: Int?
        var gender: String?
        var heightCm: Double?
        var weightKg: Double?
        var idealWeightKg: Double?
        var weightGoal: String?
        var goalPace: String?
        var sports: [String]
        var activityLevel: String?
        var experienceLevel: String?
        var sessionsPerWeek: Int?
        var nutritionQuality: String?
        var weightManagementExperience: String?
        var sleepQuality: String?
        var hasCompletedOnboarding: Bool
    }

    struct HealthBlock: Codable, Sendable {
        var steps: Int?
        var activeCalories: Double?
        var sleepHours: Double?
        var hrv: Double?
        var restingHR: Double?
        var baselineHRV: Double?
        var baselineSleepNeed: Double?
        var daysOfHealthData: Int?
        var hasAppleWatch: Bool?
    }

    struct BodyScanBlock: Codable, Sendable {
        var postureScore: Int?
        var confidence: Int?
        var shoulderScore: Int?
        var spineScore: Int?
        var asymmetries: [String]
        var topPriorities: [String]
        var faceUnderEyeFatigue: Int?
        var facePuffiness: Int?
        var scanDate: String?
        var aiEnhanced: Bool?
    }

    struct OnboardingFaceBlock: Codable, Sendable {
        var skinClarity: Int?
        var underEyeFatigue: Int?
        var puffiness: Int?
        var jawTension: Int?
        var relativeScore: Int? = nil
        var confidence: Int? = nil
        var baselineSamples: Int? = nil
        var puffinessDelta: Int? = nil
        var underEyeFatigueDelta: Int? = nil
        var jawTensionDelta: Int? = nil
        var skinClarityDelta: Int? = nil
    }

    struct FaceScanHistoryEntry: Codable, Sendable {
        var puffiness: Int
        var underEyeFatigue: Int
        var jawTension: Int
        var skinClarity: Int? = nil
        var stressLoad: Int? = nil
        var relativeScore: Int?
        var confidence: Int?
        var puffinessDelta: Int?
        var underEyeFatigueDelta: Int?
        var skinClarityDelta: Int? = nil
        var stressLoadDelta: Int? = nil
        var aiSummary: String? = nil
        var createdAt: String
    }

    struct ScanHistoryEntry: Codable, Sendable {
        var postureScore: Int
        var createdAt: String
        var aiEnhanced: Bool
    }

    struct DebloatTrajectoryBlock: Codable, Sendable {
        var currentStreak: Int
        var todayScore: Double
        var todayVerdict: String?
        var trend: String
        var velocityLabel: String
        var recentDays: [DebloatDayEntry]
    }

    struct DebloatDayEntry: Codable, Sendable {
        var dayKey: String
        var score: Double
        var verdict: String
        var yesCount: Int
        var puffinessDelta: Int?
        var hasScan: Bool
    }

    var generatedAt: String
    var profile: ProfileBlock?
    var health: HealthBlock?
    var lastBodyScan: BodyScanBlock?
    var onboardingFace: OnboardingFaceBlock?
    var latestFaceScan: OnboardingFaceBlock?
    var recentFaceScans: [FaceScanHistoryEntry]?
    var recentScans: [ScanHistoryEntry]?
    var planDayTitle: String?
    var planWeek: Int?
    var planProgressTasks: Int?
    var planTotalDays: Int?
    var planElapsedDays: Int?
    var planValidatedDays: Int?
    var planRemainingDays: Int?
    var planTrajectoryMode: String?
    var planActiveMilestone: String?
    var activityStatus: String?
    var activityStatusGuidance: String?
    var debloatTrajectory: DebloatTrajectoryBlock?
}

enum UserContextBuilder {

    @MainActor
    static func build(
        profile: UnifiedUserProfile?,
        healthManager: HealthManager? = nil
    ) -> CoachUserContext {
        let healthManager = healthManager ?? .shared
        let latestScan = BodyScanHistoryStore.shared.latestResult
        let onboardingFace = OnboardingFaceMarkersStore.load()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var ctx = CoachUserContext(
            generatedAt: formatter.string(from: Date()),
            profile: nil,
            health: nil,
            lastBodyScan: nil,
            onboardingFace: nil
        )

        if let profile {
            ctx.profile = .init(
                firstName: profile.firstName.isEmpty ? nil : profile.firstName,
                age: profile.age > 0 ? profile.age : nil,
                gender: profile.gender.rawValue,
                heightCm: profile.height > 0 ? profile.height : nil,
                weightKg: profile.weight > 0 ? profile.weight : nil,
                idealWeightKg: profile.idealWeight,
                weightGoal: profile.weightGoal?.rawValue,
                goalPace: profile.goalPace?.rawValue,
                sports: profile.sports.map(\.name),
                activityLevel: profile.activityLevel.rawValue,
                experienceLevel: profile.experienceLevel?.rawValue,
                sessionsPerWeek: profile.sessionsPerWeek,
                nutritionQuality: profile.nutritionProfile?.nutritionQuality?.rawValue,
                weightManagementExperience: profile.nutritionProfile?.weightManagementExperience?.rawValue,
                sleepQuality: profile.sleepProfile?.sleepQuality?.rawValue,
                hasCompletedOnboarding: profile.hasCompletedOnboarding
            )
        }

        let snap = healthManager.todaySnapshot
        let baselines = healthManager.baselines
        ctx.health = .init(
            steps: snap.effort.steps > 0 ? snap.effort.steps : nil,
            activeCalories: snap.effort.activeEnergyBurned > 0 ? snap.effort.activeEnergyBurned : nil,
            sleepHours: snap.sleep.sleepDuration > 0 ? snap.sleep.sleepDuration : nil,
            hrv: snap.vitals.hrv > 0 ? snap.vitals.hrv : nil,
            restingHR: snap.vitals.restingHeartRate > 0 ? snap.vitals.restingHeartRate : nil,
            baselineHRV: baselines.hrv > 0 ? baselines.hrv : nil,
            baselineSleepNeed: baselines.sleepNeedHours > 0 ? baselines.sleepNeedHours : nil,
            daysOfHealthData: baselines.daysOfData > 0 ? baselines.daysOfData : nil,
            hasAppleWatch: healthManager.hasAppleWatch
        )

        if let scan = latestScan {
            ctx.lastBodyScan = .init(
                postureScore: scan.postureScore,
                confidence: Int(scan.confidence * 100),
                shoulderScore: scan.metrics.shoulderAlignmentScore,
                spineScore: scan.metrics.spineAlignmentScore,
                asymmetries: scan.asymmetries,
                topPriorities: scan.musclePriorities.prefix(3).map { "\($0.name): \($0.reason)" },
                faceUnderEyeFatigue: scan.faceMarkers?.underEyeFatigueScore,
                facePuffiness: scan.faceMarkers?.puffinessScore,
                scanDate: formatter.string(from: scan.createdAt),
                aiEnhanced: scan.aiEnhanced
            )
        }

        if let face = onboardingFace {
            ctx.onboardingFace = .init(
                skinClarity: face.skinClarityScore,
                underEyeFatigue: face.underEyeFatigueScore,
                puffiness: face.puffinessScore,
                jawTension: face.jawTensionScore
            )
        }

        if let latestFace = FaceScanHistoryStore.shared.latestResult {
            let m = latestFace.markers
            let rel = latestFace.relativeSignals
            ctx.latestFaceScan = .init(
                skinClarity: m.skinClarityScore,
                underEyeFatigue: m.underEyeFatigueScore,
                puffiness: m.puffinessScore,
                jawTension: m.jawTensionScore,
                relativeScore: latestFace.relativeFaceDayScore,
                confidence: latestFace.scanConfidence,
                baselineSamples: latestFace.baselineSampleCount,
                puffinessDelta: rel?.puffinessDelta,
                underEyeFatigueDelta: rel?.underEyeFatigueDelta,
                jawTensionDelta: rel?.jawTensionDelta,
                skinClarityDelta: rel?.skinClarityDelta
            )
        }

        let faceHistory = FaceScanHistoryStore.shared.recentResults(limit: 14)
        if !faceHistory.isEmpty {
            ctx.recentFaceScans = faceHistory.map {
                let m = $0.markers
                let rel = $0.relativeSignals
                let analysis = CoachEngine.parsedFaceAnalysis(for: $0)
                return CoachUserContext.FaceScanHistoryEntry(
                    puffiness: m.puffinessScore,
                    underEyeFatigue: m.underEyeFatigueScore,
                    jawTension: m.jawTensionScore,
                    skinClarity: m.skinClarityScore,
                    stressLoad: FaceScanIndicators.stressLoad(for: $0),
                    relativeScore: $0.relativeFaceDayScore,
                    confidence: $0.scanConfidence,
                    puffinessDelta: rel?.puffinessDelta,
                    underEyeFatigueDelta: rel?.underEyeFatigueDelta,
                    skinClarityDelta: rel?.skinClarityDelta,
                    stressLoadDelta: rel?.stressLoadDelta,
                    aiSummary: analysis.isValid ? analysis.summary : nil,
                    createdAt: formatter.string(from: $0.createdAt)
                )
            }
        }

        let history = BodyScanHistoryStore.shared.history.prefix(6)
        if !history.isEmpty {
            ctx.recentScans = history.map {
                CoachUserContext.ScanHistoryEntry(
                    postureScore: $0.postureScore,
                    createdAt: formatter.string(from: $0.createdAt),
                    aiEnhanced: $0.aiEnhanced
                )
            }
        }

        if let plan = WelcomePlanStore.shared.plan {
            let progress = ProcessPlanProgressStore.shared.snapshot
            ctx.planWeek = plan.calendar.currentWeekNumber()
            ctx.planProgressTasks = plan.progress.completedTaskIds.count
            let idx = plan.calendar.currentProgramDayIndex()
            ctx.planDayTitle = plan.calendar.day(globalIndex: idx)?.title
            ctx.planTotalDays = progress.totalProgramDays
            ctx.planElapsedDays = progress.elapsedProgramDays
            ctx.planValidatedDays = progress.validatedDays
            ctx.planRemainingDays = progress.remainingProgramDays
            ctx.planTrajectoryMode = progress.trajectoryMode?.label
            ctx.planActiveMilestone = progress.activeMilestoneLabel
        }

        let activityStatus = ProcessActivityStatusStore.shared.status(for: Date())
        ctx.activityStatus = activityStatus.title
        if activityStatus != .active {
            ctx.activityStatusGuidance = activityStatus.trainingGuidance
        }

        let trajectory = ProcessDebloatTrajectoryStore.shared
        let trajectorySnapshot = trajectory.snapshot
        let recent = trajectory.recentRecords(limit: 14)
        ctx.debloatTrajectory = .init(
            currentStreak: trajectorySnapshot.currentStreak,
            todayScore: trajectorySnapshot.todayCompositeScore,
            todayVerdict: trajectorySnapshot.todayVerdict?.rawValue,
            trend: trajectorySnapshot.trajectoryTrend.rawValue,
            velocityLabel: trajectorySnapshot.velocityLabel,
            recentDays: recent.map {
                .init(
                    dayKey: $0.dayKey,
                    score: $0.compositeScore,
                    verdict: $0.verdict.rawValue,
                    yesCount: $0.yesCount,
                    puffinessDelta: $0.puffinessDelta,
                    hasScan: $0.hasScan
                )
            }
        )

        return ctx
    }

    /// Contexte court pour le chat — évite les réponses encyclopédiques.
    static func compactPromptBlock(from context: CoachUserContext) -> String {
        var lines: [String] = []

        if let p = context.profile {
            let name = p.firstName ?? "Utilisateur"
            let goal = p.weightGoal ?? "—"
            let sports = p.sports.prefix(2).joined(separator: ", ")
            lines.append("• \(name), \(p.age.map { "\($0) ans" } ?? "âge —"), objectif \(goal)\(sports.isEmpty ? "" : ", \(sports)")")
        }

        if let h = context.health {
            var parts: [String] = []
            if let sleep = h.sleepHours, sleep > 0 {
                parts.append("sommeil \(String(format: "%.1f", sleep))h")
            }
            if let steps = h.steps { parts.append("\(steps) pas") }
            if let hrv = h.hrv, hrv > 0 {
                parts.append("HRV \(Int(hrv.rounded()))")
            }
            if !parts.isEmpty {
                lines.append("• " + parts.joined(separator: ", "))
            }
        }

        if let status = context.activityStatus, status != ProcessActivityStatus.active.title {
            let guidance = context.activityStatusGuidance ?? ""
            lines.append("• Statut du jour : \(status)\(guidance.isEmpty ? "" : " — \(guidance)")")
        }

        if let scan = context.lastBodyScan, let score = scan.postureScore {
            lines.append("• Dernier scan posture \(score)/100")
        }

        if let face = context.latestFaceScan {
            if let relativeScore = face.relativeScore {
                let puffinessDelta = face.puffinessDelta.map { signed($0) } ?? "n/a"
                let fatigueDelta = face.underEyeFatigueDelta.map { signed($0) } ?? "n/a"
                lines.append("• Visage relatif \(relativeScore)/100 : gonflement \(puffinessDelta), cernes \(fatigueDelta)")
            } else {
                lines.append("• Visage : gonflement \(face.puffiness ?? 0), cernes \(face.underEyeFatigue ?? 0)")
            }
        }

        if let progress = context.planTotalDays.map({ _ in ProcessPlanProgressStore.shared.snapshot }),
           progress.hasPlan,
           let mode = progress.trajectoryMode {
            lines.append("• Plan : \(mode.label), jalon actif \(progress.activeMilestoneLabel ?? "—")")
        }

        if let trajectory = context.debloatTrajectory {
            lines.append("• Trajectoire debloat : streak \(trajectory.currentStreak), aujourd'hui \(Int(trajectory.todayScore))/100 (\(trajectory.todayVerdict ?? "—")), tendance \(trajectory.velocityLabel)")
            if let last = trajectory.recentDays.first {
                lines.append("• Dernier bilan : \(last.dayKey) — \(last.verdict), \(last.yesCount)/3 leviers, score \(Int(last.score))")
            }
        }

        lines.append(CoachPlanContextBuilder.unifiedPromptSections(
            plan: WelcomePlanStore.shared.plan,
            memory: CoachMemoryStore.shared.memory,
            questionnaire: WelcomePlanStore.shared.questionnaire
        ))

        if lines.isEmpty {
            return AppCopy.tSync(
                "CONTEXTE : profil useprocess (données limitées).",
                en: "CONTEXT: useprocess profile (limited data)."
            )
        }

        return AppCopy.tSync(
            "CONTEXTE (résumé — ne pas tout reciter) :\n",
            en: "CONTEXT (summary — do not recite everything):\n"
        ) + lines.joined(separator: "\n")
    }

    static func promptBlock(from context: CoachUserContext) -> String {
        guard let data = try? JSONEncoder().encode(context),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return """
        CONTEXTE UTILISATEUR useprocess (JSON — données réelles de l'app, ne pas inventer) :
        ```json
        \(json)
        ```
        """
    }

    private static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}
