import Foundation

enum ProcessCrispConfiguration {
    static var websiteID: String? {
        if let env = ProcessInfo.processInfo.environment["CRISP_WEBSITE_ID"],
           isValidWebsiteID(env) {
            return env.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let bundled = bundledWebsiteID, isValidWebsiteID(bundled) {
            return bundled
        }
        for url in secretsPlistURLs() {
            if let value = readSecret(from: url), isValidWebsiteID(value) {
                return value
            }
        }
        return nil
    }

    static var isConfigured: Bool { websiteID != nil }

    private static var bundledWebsiteID: String? {
        guard let url = Bundle.main.url(forResource: "CrispWebsiteID", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let value = json["websiteID"] else {
            return nil
        }
        return value
    }

    private static func isValidWebsiteID(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        if value.hasPrefix("YOUR_") { return false }
        return value.count >= 8
    }

    private static func secretsPlistURLs() -> [URL] {
        var urls: [URL] = []
        if let u = Bundle.main.url(forResource: "CrispSecrets", withExtension: "plist") {
            urls.append(u)
        }
        if let u = Bundle.main.url(forResource: "CrispSecrets", withExtension: "plist", subdirectory: "Config") {
            urls.append(u)
        }
        urls.append(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("CrispSecrets.plist")
        )
        return urls
    }

    private static func readSecret(from url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
              let value = dict["CRISP_WEBSITE_ID"], !value.isEmpty else {
            return nil
        }
        return value
    }
}
