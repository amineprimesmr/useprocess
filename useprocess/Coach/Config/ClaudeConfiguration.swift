import Foundation

/// Configuration centralisée Anthropic — local (dev) ou proxy Firebase (prod).
enum ClaudeConfiguration {

    static let apiVersion = "2023-06-01"
    static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!

    static var anthropicAPIKey: String? {
        secret(for: "ANTHROPIC_API_KEY")
    }

    static var openAIAPIKey: String? {
        secret(for: "OPENAI_API_KEY")
    }

    /// URL de base Cloud Functions — override via CoachSecrets `COACH_FUNCTIONS_BASE_URL`.
    static var functionsBaseURL: URL? {
        if let raw = secret(for: "COACH_FUNCTIONS_BASE_URL"),
           let url = URL(string: raw), !raw.hasPrefix("YOUR_") {
            return url
        }
        return FirebaseProjectConfiguration.defaultFunctionsBaseURL
    }

    /// `true` = proxy Firebase (clé serveur). `false` = appels directs (dev).
    static var useRemoteCoach: Bool {
        let flag = secret(for: "USE_REMOTE_COACH")?.lowercased()
        if flag == "false" || flag == "0" { return false }
        if flag == "true" || flag == "1" { return true }
        return AppConfiguration.firebaseConfigured
    }

    static var prefersRemoteCoach: Bool {
        useRemoteCoach && AppConfiguration.firebaseConfigured && functionsBaseURL != nil
    }

    static var isConfigured: Bool {
        prefersRemoteCoach || anthropicAPIKey != nil
    }

    static var claudeEnabled: Bool { isConfigured }

    static var aiAnalysisEnabled: Bool { isConfigured }

    static var transportLabel: String {
        switch CoachAPITransport.activeMode {
        case .remote: return "Proxy Firebase"
        case .local: return "Direct (dev)"
        case .unavailable: return "Non configuré"
        }
    }

    private static func secret(for key: String) -> String? {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty, !env.hasPrefix("YOUR_") {
            return env
        }
        return nil
    }
}
