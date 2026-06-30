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
    let userMessageText: String
    let analysisPrompt: String
}

enum FaceScanCoachHandoffBuilder {
    static func make(from result: FaceScanResult) -> FaceScanCoachHandoff {
        let score = result.displayWellnessScore
        let display = CoachFaceScanMessageMarker.embed(
            scanId: result.id,
            displayText: "Scan visage du jour · \(score)%"
        )

        let markers = result.markers
        let prompt = """
        Analyse mon scan visage quotidien (vidéo / capture jointe).

        Score wellness du jour : \(score)% (moyenne des 5 indicateurs).
        Score relatif vs baseline : \(result.resolvedFaceDayScore)/100.
        Signaux locaux : rétention \(markers.puffinessScore), récupération \(markers.underEyeFatigueScore), peau \(markers.skinClarityScore), définition \(FaceScanIndicators.definitionScore(from: markers)), charge stress \(FaceScanIndicators.stressLoad(for: result)).

        Compare avec mes scans précédents si tu les as dans le contexte.
        Donne une lecture debloat / visage claire, puis 3 actions concrètes pour aujourd'hui dans mon protocole Origine.
        Réponds en français, coach Process, pas de jargon médical.
        """

        return FaceScanCoachHandoff(
            resultId: result.id,
            userMessageText: display,
            analysisPrompt: prompt
        )
    }

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
    static func deliver(result: FaceScanResult) {
        HapticManager.shared.notification(.success)
        CoachPlanNavigationBridge.shared.openCoachAfterFaceScan(result: result)
    }
}
