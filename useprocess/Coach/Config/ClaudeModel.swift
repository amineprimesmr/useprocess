import Foundation

/// Modèles Anthropic supportés par useprocess.
enum ClaudeModel: String, CaseIterable, Identifiable, Sendable {
    case sonnet4 = "claude-sonnet-4-20250514"
    case opus4 = "claude-opus-4-20250514"
    case haiku45 = "claude-haiku-4-5-20251001"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sonnet4: return "Claude Sonnet 4"
        case .opus4: return "Claude Opus 4"
        case .haiku45: return "Claude Haiku 4.5"
        }
    }

    var supportsVision: Bool {
        switch self {
        case .sonnet4, .opus4: return true
        case .haiku45: return true
        }
    }

    /// Usage recommandé par type de tâche.
    static func preferred(for task: CoachTaskKind) -> ClaudeModel {
        switch task {
        case .chat, .dailyBrief:
            return .sonnet4
        case .bodyScanVision:
            return .sonnet4
        case .bodyScanReport, .programSummary, .readinessAnalysis:
            return .opus4
        case .quickHint:
            return .haiku45
        }
    }
}

enum CoachTaskKind: Sendable {
    case chat
    case dailyBrief
    case bodyScanVision
    case bodyScanReport
    case programSummary
    case readinessAnalysis
    case quickHint
}
