import Foundation

/// Modèles Anthropic — alignés sur le statut juin 2026 (doc deprecations Anthropic).
/// Actifs : Sonnet 4.6, Opus 4.8, Haiku 4.5.
/// Retirés le 15/06/2026 : claude-sonnet-4-20250514, claude-opus-4-20250514.
enum ClaudeModel: String, CaseIterable, Identifiable, Sendable {
    case sonnet46 = "claude-sonnet-4-6"
    case opus48 = "claude-opus-4-8"
    case haiku45 = "claude-haiku-4-5-20251001"

    var id: String { rawValue }

    /// Identifiant API — remappe les anciens modèles retirés.
    var apiModelId: String {
        Self.resolving(rawValue).rawValue
    }

    var displayName: String {
        switch self {
        case .sonnet46: return "Claude Sonnet 4.6"
        case .opus48: return "Claude Opus 4.8"
        case .haiku45: return "Claude Haiku 4.5"
        }
    }

    var supportsVision: Bool {
        switch self {
        case .sonnet46, .opus48, .haiku45: return true
        }
    }

    /// Usage recommandé par type de tâche (juin 2026).
    static func preferred(for task: CoachTaskKind) -> ClaudeModel {
        switch task {
        case .chat, .dailyBrief, .bodyScanVision, .faceScanVision:
            return .sonnet46
        case .bodyScanReport, .programSummary, .readinessAnalysis:
            return .opus48
        case .quickHint:
            return .haiku45
        }
    }

    /// Remplace automatiquement les modèles retirés ou dépréciés.
    static func resolving(_ raw: String?) -> ClaudeModel {
        guard let raw, !raw.isEmpty else { return .sonnet46 }
        if let exact = ClaudeModel(rawValue: raw) { return exact }

        switch raw {
        // Retirés 15/06/2026
        case "claude-sonnet-4-20250514":
            return .sonnet46
        case "claude-opus-4-20250514":
            return .opus48

        // Autres Sonnet retirés → 4.6
        case "claude-3-7-sonnet-20250219",
             "claude-3-5-sonnet-20240620",
             "claude-3-5-sonnet-20241022",
             "claude-3-sonnet-20240229":
            return .sonnet46

        // Sonnet 4.5 encore actif mais on standardise sur 4.6
        case "claude-sonnet-4-5-20250929":
            return .sonnet46

        // Opus dépréciés / intermédiaires → 4.8 (flagship juin 2026)
        case "claude-opus-4-1-20250805",
             "claude-opus-4-6",
             "claude-opus-4-7",
             "claude-opus-4-5-20251101",
             "claude-3-opus-20240229",
             "claude-2.0", "claude-2.1":
            return .opus48

        // Haiku retirés → 4.5
        case "claude-3-5-haiku-20241022",
             "claude-3-haiku-20240307",
             "claude-1.0", "claude-1.1", "claude-1.2", "claude-1.3",
             "claude-instant-1.0", "claude-instant-1.1", "claude-instant-1.2":
            return .haiku45

        default:
            return .sonnet46
        }
    }
}

enum CoachTaskKind: Sendable {
    case chat
    case dailyBrief
    case bodyScanVision
    case faceScanVision
    case bodyScanReport
    case programSummary
    case readinessAnalysis
    case quickHint
}
