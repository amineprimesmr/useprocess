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

