import Foundation

enum PostHogConfiguration {
    static var projectToken: String? {
        secret(for: "POSTHOG_PROJECT_TOKEN")
    }

    /// EU by default (GDPR-friendly). Override via `POSTHOG_HOST` in the secrets plist.
    static var host: String {
        secret(for: "POSTHOG_HOST") ?? "https://eu.i.posthog.com"
    }

    static var isConfigured: Bool {
        guard let token = projectToken else { return false }
        return !token.isEmpty
            && !token.hasPrefix("YOUR_")
            && !token.hasPrefix("phc_YOUR")
    }

    private static func secret(for key: String) -> String? {
        if let env = ProcessInfo.processInfo.environment[key],
           !env.isEmpty,
           !env.hasPrefix("YOUR_"),
           !env.hasPrefix("phc_YOUR") {
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
        let names = ["PostHogSecrets", "CoachSecrets", "RevenueCatSecrets"]
        let subdirs: [String?] = [nil, "Analytics", "Config", "Subscriptions", "Coach/Config"]

        for name in names {
            for sub in subdirs {
                if let sub,
                   let u = Bundle.main.url(forResource: name, withExtension: "plist", subdirectory: sub) {
                    urls.append(u)
                } else if sub == nil, let u = Bundle.main.url(forResource: name, withExtension: "plist") {
                    urls.append(u)
                }
            }
        }

        urls.append(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("PostHogSecrets.plist")
        )
        return urls
    }

    private static func readSecret(key: String, from url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
              let value = dict[key], !value.isEmpty,
              !value.hasPrefix("YOUR_"),
              !value.hasPrefix("phc_YOUR") else {
            return nil
        }
        return value
    }
}
