import Foundation

enum BodyScanConfiguration {

    static var anthropicAPIKey: String? {
        secret(for: "ANTHROPIC_API_KEY")
    }

    static var openAIAPIKey: String? {
        secret(for: "OPENAI_API_KEY")
    }

    static var aiAnalysisEnabled: Bool {
        anthropicAPIKey != nil || openAIAPIKey != nil
    }

    static var claudeEnabled: Bool {
        anthropicAPIKey != nil
    }

    private static func secret(for key: String) -> String? {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
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

        let subdirs = [nil, "BodyScan/Config", "Config"]
        for sub in subdirs {
            if let sub {
                if let u = Bundle.main.url(forResource: "BodyScanSecrets", withExtension: "plist", subdirectory: sub) {
                    urls.append(u)
                }
            } else if let u = Bundle.main.url(forResource: "BodyScanSecrets", withExtension: "plist") {
                urls.append(u)
            }
        }

        // Plist à côté de ce fichier source (build Xcode / simulateur)
        let sibling = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("BodyScanSecrets.plist")
        urls.append(sibling)

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
