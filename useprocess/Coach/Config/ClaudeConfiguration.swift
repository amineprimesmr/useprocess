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

        for url in secretsPlistURLs() {
            if let value = readSecret(key: key, from: url) {
                return value
            }
        }
        return nil
    }

    private static func secretsPlistURLs() -> [URL] {
        var urls: [URL] = []
        let resourceNames = ["CoachSecrets", "BodyScanSecrets"]
        let subdirs: [String?] = [nil, "Coach/Config", "BodyScan/Config", "Config"]

        for name in resourceNames {
            for sub in subdirs {
                if let sub {
                    if let u = Bundle.main.url(forResource: name, withExtension: "plist", subdirectory: sub) {
                        urls.append(u)
                    }
                } else if let u = Bundle.main.url(forResource: name, withExtension: "plist") {
                    urls.append(u)
                }
            }
        }

        urls.append(URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("CoachSecrets.plist"))
        urls.append(URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("BodyScan/Config/BodyScanSecrets.plist"))

        return urls
    }

    private static func readSecret(key: String, from url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
              let value = dict[key], !value.isEmpty,
              !value.hasPrefix("YOUR_") else {
            return nil
        }
        return value
    }
}
