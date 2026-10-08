import Foundation

nonisolated enum AppConfiguration {
    static var appDisplayName: String {
        infoString(for: "CFBundleDisplayName") ?? "Process"
    }

    /// Bascule configurée seulement après validation DNS, site, emails et liens.
    /// La valeur de migration prévue est https://processdebloat.com.
    static var websiteOrigin: String {
        let candidate = infoString(for: "ProcessWebsiteOrigin") ?? "https://processdebloat.com"
        guard let url = URL(string: candidate), url.scheme == "https",
              let host = url.host,
              ["useprocess.xyz", "processdebloat.com"].contains(host) else {
            return "https://processdebloat.com"
        }
        return "https://\(host)"
    }

    static var supportEmail: String {
        infoString(for: "ProcessSupportEmail") ?? "contact@processdebloat.com"
    }

    static var firebaseConfigured: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.useprocess"
    }

    private static func infoString(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
