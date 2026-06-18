import Foundation

enum CoachConversationSubjectService {

    /// Mots-clés courts (heuristique locale, immédiat).
    static func keywords(from text: String) -> String {
        let cleaned = normalize(text)
        guard !cleaned.isEmpty else { return "Conversation" }

        if let topic = extractTopicAfterPossessive(cleaned) {
            return formatKeywords([topic])
        }

        var working = stripLeadingPhrases(cleaned)
        working = working.trimmingCharacters(in: CharacterSet(charactersIn: "?!.,;:"))

        let tokens = tokenize(working)
        let meaningful = tokens.filter { !stopwords.contains($0) && ($0.count >= 3 || allowedShort.contains($0)) }

        if meaningful.isEmpty {
            let fallback = tokens.filter { $0.count >= 3 }
            return formatKeywords(Array(fallback.prefix(3)))
        }

        return formatKeywords(Array(meaningful.prefix(4)))
    }

    /// Affinage IA (2–4 mots-clés) — optionnel, après le 1er message.
    static func refineWithAI(from text: String) async -> String? {
        guard ClaudeConfiguration.isConfigured else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return nil }

        let prompt = """
        Extrais 2 à 4 mots-clés (substantifs) qui résument le SUJET principal de ce message utilisateur.
        Pas une question. Pas une phrase complète. Français. Sépare par « · ».
        Exemples:
        - « Comment améliorer mon sommeil ? » → Sommeil · Récupération
        - « J'ai mal au genou » → Genou · Douleur
        - « Change mon plan muscu mardi » → Plan · Musculation

        Message:
        \(trimmed)
        """

        do {
            let raw = try await CoachAPITransport.complete(
                task: .programSummary,
                system: "Tu réponds uniquement par des mots-clés séparés par ·, sans ponctuation finale.",
                userText: prompt,
                model: ClaudeModel.preferred(for: .programSummary),
                maxTokens: 32
            )
            let subject = sanitizeAIOutput(raw)
            return subject.isEmpty ? nil : subject
        } catch {
            return nil
        }
    }

    // MARK: - Heuristiques

    private static let stopwords: Set<String> = [
        "je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles",
        "me", "te", "se", "moi", "toi", "lui", "eux", "y", "en", "ne", "pas", "plus", "très", "tres", "bien",
        "le", "la", "les", "un", "une", "des", "du", "de", "d", "l", "au", "aux", "à", "a", "dans", "sur", "sous",
        "pour", "par", "avec", "sans", "chez", "entre", "vers", "comme",
        "mon", "ma", "mes", "ton", "ta", "tes", "son", "sa", "ses", "notre", "votre", "leur", "leurs",
        "ce", "cet", "cette", "ces", "ça", "ca", "cela",
        "est", "suis", "es", "sommes", "êtes", "etes", "sont", "ai", "as", "avons", "avez", "ont", "être", "etre", "avoir",
        "fais", "faire", "fait", "peux", "peut", "pouvez", "pourrais", "pourrait", "veux", "veut", "voudrais",
        "que", "qui", "quoi", "dont", "où", "ou", "quand", "comment", "pourquoi", "combien",
        "dis", "dit", "dire", "explique", "expliquer", "donne", "donner", "aide", "aider", "aidez",
        "salut", "bonjour", "coucou", "hey", "merci", "svp", "stp", "please",
        "suis", "été", "ete", "être", "etre", "vais", "aller", "allons",
        "quel", "quelle", "quels", "quelles", "estce", "ceque", "quest"
    ]

    private static let allowedShort: Set<String> = ["hrv", "omd", "hr", "fc", "spa", "run"]

    private static func normalize(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("🔹") {
            s = String(s.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }

    private static func stripLeadingPhrases(_ text: String) -> String {
        var s = text.lowercased()
        let prefixes = [
            "est-ce que ", "est ce que ", "est-ce qu'", "est ce qu'",
            "qu'est-ce que ", "qu est ce que ", "qu'est-ce qu'", "qu est ce qu'",
            "peux-tu ", "peux tu ", "pourrais-tu ", "pourrais tu ",
            "dis-moi ", "dis moi ", "explique-moi ", "explique moi ",
            "aide-moi ", "aide moi ", "aide-moi à ", "aide moi a ",
            "j'aimerais ", "j aimerais ", "je voudrais ", "je veux ", "je peux ",
            "j'ai besoin ", "j ai besoin ", "c'est quoi ", "c est quoi ",
            "comment ", "pourquoi ", "combien ", "quand ", "où ", "ou "
        ]
        var changed = true
        while changed {
            changed = false
            for prefix in prefixes {
                if s.hasPrefix(prefix) {
                    s = String(s.dropFirst(prefix.count))
                    changed = true
                    break
                }
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractTopicAfterPossessive(_ text: String) -> String? {
        let lower = text.lowercased()
        let markers = ["mon ", "ma ", "mes ", "ton ", "ta ", "tes "]
        for marker in markers {
            guard let range = lower.range(of: marker) else { continue }
            let after = String(text[range.upperBound...])
            let token = tokenize(after).first(where: { !stopwords.contains($0) && $0.count >= 3 })
            if let token { return token }
        }
        return nil
    }

    private static func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func formatKeywords(_ words: [String]) -> String {
        let formatted = words
            .prefix(4)
            .map { word -> String in
                let w = word.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !w.isEmpty else { return "" }
                return w.prefix(1).uppercased() + w.dropFirst()
            }
            .filter { !$0.isEmpty }

        if formatted.isEmpty { return "Conversation" }
        return formatted.joined(separator: " · ")
    }

    private static func sanitizeAIOutput(_ raw: String) -> String {
        var s = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if s.hasPrefix("\"") { s.removeFirst() }
        if s.hasSuffix("\"") { s.removeLast() }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "?!.,;:"))
        if s.count > 48 {
            s = String(s.prefix(48)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return s
    }
}
