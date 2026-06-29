import UIKit

@MainActor
enum ProcessAssetCatalog {
    static func contains(_ name: String) -> Bool {
        UIImage(named: name, in: .main, compatibleWith: nil) != nil
    }
}
