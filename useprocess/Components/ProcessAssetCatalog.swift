import UIKit

@MainActor
enum ProcessAssetCatalog {
    private static var availabilityCache: [String: Bool] = [:]

    static func contains(_ name: String) -> Bool {
        if let cached = availabilityCache[name] { return cached }
        let exists = UIImage(named: name) != nil
        availabilityCache[name] = exists
        return exists
    }
}
