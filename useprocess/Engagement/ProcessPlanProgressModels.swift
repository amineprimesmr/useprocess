import Foundation

// MARK: - Évolution durée

enum PlanDurationEvolutionReason: String, Codable, Equatable {
    case earlyScanCompletion
    case streakMilestone
    case consecutiveMisses
    case cardioConsecutiveMisses
    case cardioWeeklyDeficit
    case regressionPattern

    var systemImage: String {
        switch self {
        case .earlyScanCompletion: return "checkmark.seal.fill"
        case .streakMilestone: return "flame.fill"
        case .consecutiveMisses: return "calendar.badge.plus"
        case .cardioConsecutiveMisses: return "figure.run"
        case .cardioWeeklyDeficit: return "figure.run.circle"
        case .regressionPattern: return "arrow.uturn.backward.circle.fill"
        }
    }
}

struct PlanDurationEvolutionEvent: Codable, Equatable, Identifiable {
    let id: String
    let createdAt: Date
    let deltaDays: Int
    let reason: PlanDurationEvolutionReason
    let message: String

    var signedLabel: String {
        let days = abs(deltaDays)
        if deltaDays > 0 { return "+\(days) j" }
        if deltaDays < 0 { return "-\(days) j" }
        return "0 j"
    }
}

struct ProcessPlanProgressState: Codable, Equatable {
    var adjustmentDays: Int = 0
    var events: [PlanDurationEvolutionEvent] = []
    var appliedTokens: Set<String> = []
    var schemaVersion: Int = 1
}

// MARK: - Jalons trajectoire

struct PlanMilestoneProgress: Equatable {
    let id: String
    let label: String
    let targetDays: Int
    let elapsedDays: Int
    let remainingDays: Int
    let estimatedDate: Date?
    let progress: Double
    let isComplete: Bool
    let isActive: Bool
}

// MARK: - Snapshot UI

struct PlanProgressSnapshot: Equatable {
    let hasPlan: Bool
    let totalProgramDays: Int
    let baseProgramDays: Int
    let durationAdjustmentDays: Int
    let elapsedProgramDays: Int
    let remainingProgramDays: Int
    let currentWeek: Int
    let totalWeeks: Int
    let validatedDays: Int
    let currentStreak: Int
    let estimatedEndDate: Date?
    let timeProgress: Double
    let validationProgress: Double
    let headline: String
    let subtitle: String
    let weeksLabel: String
    let latestEvolutionNote: String?
    let trajectoryMode: TrajectoryMode?
    let milestones: [PlanMilestoneProgress]
    let activeMilestoneLabel: String?
    /// Jalon debloat promis à l'onboarding (`assessmentSnapshot.debloatTargetDays`).
    let debloatTargetDays: Int?
    let debloatEstimatedDate: Date?
    let debloatRemainingDays: Int?

    static let empty = PlanProgressSnapshot(
        hasPlan: false,
        totalProgramDays: 0,
        baseProgramDays: 0,
        durationAdjustmentDays: 0,
        elapsedProgramDays: 0,
        remainingProgramDays: 0,
        currentWeek: 0,
        totalWeeks: 0,
        validatedDays: 0,
        currentStreak: 0,
        estimatedEndDate: nil,
        timeProgress: 0,
        validationProgress: 0,
        headline: "Aucun plan actif",
        subtitle: "Complète la configuration pour obtenir ton calendrier personnalisé.",
        weeksLabel: "",
        latestEvolutionNote: nil,
        trajectoryMode: nil,
        milestones: [],
        activeMilestoneLabel: nil,
        debloatTargetDays: nil,
        debloatEstimatedDate: nil,
        debloatRemainingDays: nil
    )
}
