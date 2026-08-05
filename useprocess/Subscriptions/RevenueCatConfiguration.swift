import Foundation
import os.log

enum RevenueCatConfiguration {
    /// Clé publique iOS RevenueCat (projet Process).
    /// Safe to ship in the client — ce n’est PAS une secret key (`sk_`).
    /// Remplir avec la clé `appl_…` depuis RevenueCat → API keys, puis re-archiver.
    static let bundledIOSPublicAPIKey = "appl_vDFQcBzxZNabxkSAwSqFNYHptbw"

    private static let log = Logger(subsystem: "com.useprocess", category: "RevenueCat")

    static var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"],
           isValidPublicKey(env) {
            return env
        }

        for url in secretsPlistURLs() {
            if let value = readSecret(key: "REVENUECAT_API_KEY", from: url),
               isValidPublicKey(value) {
                return value
            }
        }

        if isValidPublicKey(bundledIOSPublicAPIKey) {
            return bundledIOSPublicAPIKey
        }

        return nil
    }

    static var isConfigured: Bool {
        apiKey != nil
    }

    /// Appelé au boot — log clair si la prod part sans RevenueCat.
    static func logConfigurationStatus() {
        if isConfigured {
            log.info("RevenueCat configuré (clé publique iOS présente).")
            return
        }

        #if DEBUG
        log.error("RevenueCat NON configuré — achats en StoreKit local uniquement (invisibles dans le dashboard prod).")
        #else
        log.error("RevenueCat NON configuré en Release — les achats App Store ne seront PAS trackés. Renseigne bundledIOSPublicAPIKey.")
        assertionFailure("RevenueCat API key missing in Release build")
        #endif
    }

    private static func isValidPublicKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.hasPrefix("appl_") else { return false }
        guard !trimmed.hasPrefix("appl_YOUR") else { return false }
        guard trimmed.count > 10 else { return false }
        return true
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
              let value = dict[key], !value.isEmpty else {
            return nil
        }
        return value
    }
}
