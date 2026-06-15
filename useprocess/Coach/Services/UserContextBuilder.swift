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
        var readinessScore: Int?
        var readinessLabel: String?
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
    }

    struct FaceScanHistoryEntry: Codable, Sendable {
        var puffiness: Int
        var underEyeFatigue: Int
        var jawTension: Int
        var createdAt: String
    }

    struct ScanHistoryEntry: Codable, Sendable {
        var postureScore: Int
        var createdAt: String
        var aiEnhanced: Bool
    }

    var generatedAt: String
    var profile: ProfileBlock?
    var health: HealthBlock?
    var lastBodyScan: BodyScanBlock?
    var onboardingFace: OnboardingFaceBlock?
    var latestFaceScan: OnboardingFaceBlock?
    var recentFaceScans: [FaceScanHistoryEntry]?
    var recentScans: [ScanHistoryEntry]?
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
            readinessScore: healthManager.readinessScore > 0 ? healthManager.readinessScore : nil,
            readinessLabel: healthManager.readinessLabel != "—" ? healthManager.readinessLabel : nil,
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
            ctx.latestFaceScan = .init(
                skinClarity: m.skinClarityScore,
                underEyeFatigue: m.underEyeFatigueScore,
                puffiness: m.puffinessScore,
                jawTension: m.jawTensionScore
            )
        }

        let faceHistory = FaceScanHistoryStore.shared.recentResults(limit: 7)
        if !faceHistory.isEmpty {
            ctx.recentFaceScans = faceHistory.map {
                CoachUserContext.FaceScanHistoryEntry(
                    puffiness: $0.markers.puffinessScore,
                    underEyeFatigue: $0.markers.underEyeFatigueScore,
                    jawTension: $0.markers.jawTensionScore,
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
            var health = "• Readiness \(h.readinessScore.map(String.init) ?? "—")"
            if let steps = h.steps { health += ", \(steps) pas" }
            if let sleep = h.sleepHours, sleep > 0 {
                health += ", sommeil \(String(format: "%.1f", sleep))h"
            }
            lines.append(health)
        }

        if let scan = context.lastBodyScan, let score = scan.postureScore {
            lines.append("• Dernier scan posture \(score)/100")
        }

        if let face = context.latestFaceScan {
            lines.append("• Visage : gonflement \(face.puffiness ?? 0), cernes \(face.underEyeFatigue ?? 0)")
        }

        if lines.isEmpty {
            return "CONTEXTE : profil useprocess (données limitées)."
        }

        return "CONTEXTE (résumé — ne pas tout reciter) :\n" + lines.joined(separator: "\n")
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
}
