import Foundation

enum FirebaseProjectConfiguration {
    static var projectId: String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let id = dict["PROJECT_ID"] as? String, !id.isEmpty else {
            return nil
        }
        return id
    }

    static var defaultFunctionsRegion: String { "us-central1" }

    static var defaultFunctionsBaseURL: URL? {
        guard let projectId else { return nil }
        return URL(string: "https://\(defaultFunctionsRegion)-\(projectId).cloudfunctions.net")
    }
}
