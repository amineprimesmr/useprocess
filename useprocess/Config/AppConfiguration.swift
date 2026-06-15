import Foundation

enum AppConfiguration {
    static var appDisplayName: String {
        infoString(for: "CFBundleDisplayName") ?? "Process AI"
    }

    static let supportEmail = "hello@useprocess.app"

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
