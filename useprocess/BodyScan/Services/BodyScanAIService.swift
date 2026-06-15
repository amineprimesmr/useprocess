import Foundation
import UIKit

/// @deprecated Utiliser `CoachEngine.enhanceBodyScanReport` — wrapper de compatibilité.
enum BodyScanAIService {
    static func enhanceReport(_ result: BodyScanResult) async -> BodyScanResult {
        await CoachEngine.enhanceBodyScanReport(result)
    }
}
