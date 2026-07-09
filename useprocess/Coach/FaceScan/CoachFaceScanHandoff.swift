import Foundation
import UIKit

/// Métadonnée embarquée dans le texte utilisateur pour afficher la vidéo du scan dans le chat.
enum CoachFaceScanMessageMarker {
    private static let prefix = "[[process_face_scan:"
    private static let suffix = "]]"

    static func embed(scanId: String, displayText: String) -> String {
        "\(prefix)\(scanId)\(suffix)\n\(displayText)"
    }

    static func scanId(from text: String) -> String? {
        guard let start = text.range(of: prefix) else { return nil }
        let after = text[start.upperBound...]
        guard let end = after.range(of: suffix) else { return nil }
        let id = String(after[..<end.lowerBound])
        return id.isEmpty ? nil : id
    }

    static func displayText(from text: String) -> String {
        guard let start = text.range(of: prefix) else { return text }
        guard let end = text.range(of: suffix, range: start.lowerBound..<text.endIndex) else { return text }
        let remainder = text[end.upperBound...]
        return remainder.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct FaceScanCoachHandoff: Equatable {
    let resultId: String
    let assistantMessage: CoachMessage
}

enum FaceScanCoachHandoffBuilder {
    static func previewImages(for result: FaceScanResult) -> [UIImage] {
        var images: [UIImage] = []
        if let filename = result.snapshotFilename,
           let image = FaceScanImageStore.load(filename: filename) {
            images.append(image)
        }
        return images
    }
}

@MainActor
enum FaceScanCoachHandoffCoordinator {
    static func deliver(result: FaceScanResult, insight: FaceScanAIInsight? = nil) {
        HapticManager.shared.impact(.light)

        let history = FaceScanEvolutionEngine.dailyHistory(from: FaceScanHistoryStore.shared.history)
        let resolvedInsight = insight ?? FaceScanAIInsightBuilder.insight(
            for: result,
            history: history,
            context: FaceScanInsightContext.fromTodayHealth()
        )

        let message = FaceScanCoachInsightService.immediateCoachMessage(
            for: result,
            insight: resolvedInsight
        )

        CoachPlanNavigationBridge.shared.openCoachAfterFaceScan(
            handoff: FaceScanCoachHandoff(resultId: result.id, assistantMessage: message)
        )

        Task {
            _ = await FaceScanCoachInsightService.ensureCoachMessage(
                for: result,
                insight: resolvedInsight,
                profile: UnifiedProfileService.shared.currentProfile
            )
        }
    }
}
