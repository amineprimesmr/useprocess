import Foundation

enum TransformationBundledVideo {
    static func url(for resourceName: String?) -> URL? {
        guard let resourceName, !resourceName.isEmpty else { return nil }
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") {
            return url
        }
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "mp4",
            subdirectory: "Resources/Onboarding"
        ) {
            return url
        }
        return nil
    }
}
