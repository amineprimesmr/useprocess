import Foundation

enum RevenueCatConfiguration {
    static var apiKey: String? {
        secret(for: "REVENUECAT_API_KEY")
    }

    static var isConfigured: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty && !key.hasPrefix("YOUR_") && !key.hasPrefix("appl_YOUR")
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
        let names = ["RevenueCatSecrets", "CoachSecrets"]
        let subdirs: [String?] = [nil, "Subscriptions", "Coach/Config", "Config"]

        for name in names {
            for sub in subdirs {
                if let sub, let u = Bundle.main.url(forResource: name, withExtension: "plist", subdirectory: sub) {
                    urls.append(u)
                } else if sub == nil, let u = Bundle.main.url(forResource: name, withExtension: "plist") {
                    urls.append(u)
                }
            }
        }

        urls.append(URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("RevenueCatSecrets.plist"))
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
