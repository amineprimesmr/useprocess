import Foundation

/// Filtre les FOLLOW_UP générés par le modèle : seuls les messages utilisateur→coach sont affichés.
enum CoachFollowUpSanitizer {

    static func sanitized(_ followUps: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for raw in followUps {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard isUserToCoachMessage(trimmed) else { continue }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }

        return Array(result.prefix(2))
    }

    /// Vrai si la phrase ressemble à un message que l'utilisateur envoie au coach.
    static func isUserToCoachMessage(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")

        guard !normalized.isEmpty else { return false }

        if isCoachAskingUser(normalized) { return false }

        let userLedPrefixes = [
            "je ", "j'", "j’", "propose", "ajoute", "enregistre", "valide", "modifie",
            "change", "autre ", "comment ", "pourquoi ", "quelle ", "quel ", "quoi ",
            "aide", "aide-moi", "montre", "donne", "prépare", "adapter", "adapte"
        ]
        if userLedPrefixes.contains(where: { normalized.hasPrefix($0) }) { return true }

        // Impératif coach → utilisateur
        let coachImperatives = ["prends ", "mange ", "fais ", "va ", "n'oublie", "essaie ", "privilégie "]
        if coachImperatives.contains(where: { normalized.hasPrefix($0) }) { return false }

        return true
    }

    private static func isCoachAskingUser(_ normalized: String) -> Bool {
        let coachPatterns = [
            "t'as ", "t'es ", "tu as ", "tu es ", "tu fais ", "tu peux ", "tu veux ",
            "tu manges ", "tu prends ", "as-tu ", "as tu ", "est-ce que tu ", "est-ce qu'tu ",
            "vas-tu ", "vas tu ", "tu comptes ", "t'as fait", "t'as mangé", "t'as pris"
        ]
        if coachPatterns.contains(where: { normalized.hasPrefix($0) }) { return true }

        if normalized.hasSuffix("?") {
            if normalized.hasPrefix("t'") || normalized.hasPrefix("tu ") { return true }
            if normalized.contains("t'as ") || normalized.contains(" tu ") { return true }
        }

        return false
    }
}
