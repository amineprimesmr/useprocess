import Foundation

/// @deprecated Utiliser `ClaudeConfiguration` — conservé pour compatibilité Body Scan.
enum BodyScanConfiguration {
    static var anthropicAPIKey: String? { ClaudeConfiguration.anthropicAPIKey }
    static var openAIAPIKey: String? { ClaudeConfiguration.openAIAPIKey }
    static var aiAnalysisEnabled: Bool { ClaudeConfiguration.aiAnalysisEnabled }
    static var claudeEnabled: Bool { ClaudeConfiguration.claudeEnabled }
}
