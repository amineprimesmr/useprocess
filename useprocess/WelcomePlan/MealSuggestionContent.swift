import Foundation

// MARK: - Modèle

struct MealSuggestionItem: Codable, Equatable, Identifiable, Hashable {
    var name: String
    var quantity: String
    var role: String

    var id: String { "\(name)|\(quantity)|\(role)" }

    var roleIcon: String {
        switch role.lowercased() {
        case let r where r.contains("prot"): return "bolt.fill"
        case let r where r.contains("lég") || r.contains("leg"): return "leaf.fill"
        case let r where r.contains("gluc"): return "flame.fill"
        case let r where r.contains("gras"): return "drop.fill"
        default: return "circle.fill"
        }
    }
}

struct MealSuggestionContent: Codable, Equatable {
    var name: String
    var mealType: String
    var protocolScore: Int
    var scoreSummary: String
    var items: [MealSuggestionItem]
    var prepMinutes: Int
    var prepSummary: String
    var coachTip: String
    var tags: [String]
    var subScores: MealSubScores?
    var imageAssetName: String? = nil
    /// Afficher le score uniquement après personnalisation IA (repas par défaut = 100/100 masqué).
    var showsScore: Bool = false

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !items.isEmpty
    }

    var timeSlot: MealTimeSlot { MealTimeSlot.from(mealType: mealType) }

    var resolvedSubScores: MealSubScores {
        if let subScores { return subScores }
        let base = protocolScore
        return MealSubScores(
            protocolFit: base,
            satiety: min(100, base + 4),
            antiBloat: max(40, base - 6)
        )
    }

    var compactSummary: String {
        let ingredients = items.map { "\($0.name) (\($0.quantity))" }.joined(separator: ", ")
        return "\(name) — \(ingredients). \(prepSummary)"
    }

    // MARK: - Persistance (validatedMeals reste [String: String])

    func encodedForStorage() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return compactSummary
        }
        return json
    }

    static func fromStored(_ raw: String) -> MealSuggestionContent? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           var decoded = try? JSONDecoder().decode(MealSuggestionContent.self, from: data) {
            if !trimmed.contains("\"showsScore\"") {
                decoded.showsScore = Self.inferShowsScore(
                    protocolScore: decoded.protocolScore,
                    scoreSummary: decoded.scoreSummary
                )
            }
            return decoded.isValid ? decoded : nil
        }

        return MealSuggestionParser.parse(trimmed)
    }

    static func inferShowsScore(protocolScore: Int, scoreSummary: String) -> Bool {
        let summary = scoreSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return protocolScore < 100 || !summary.isEmpty
    }

    /// Repas catalogue Process — score parfait implicite, sans affichage UI.
    static func asProcessDefault(
        name: String,
        mealType: String,
        items: [MealSuggestionItem],
        prepMinutes: Int,
        prepSummary: String,
        coachTip: String,
        tags: [String],
        imageAssetName: String?
    ) -> MealSuggestionContent {
        MealSuggestionContent(
            name: name,
            mealType: mealType,
            protocolScore: 100,
            scoreSummary: "",
            items: items,
            prepMinutes: prepMinutes,
            prepSummary: prepSummary,
            coachTip: coachTip,
            tags: tags,
            subScores: MealSubScores(protocolFit: 100, satiety: 100, antiBloat: 100),
            imageAssetName: imageAssetName,
            showsScore: false
        )
    }
}

// MARK: - Parser

enum MealSuggestionParser {

    static func parse(_ raw: String) -> MealSuggestionContent? {
        let cleaned = sanitize(raw)
        if let json = parseJSON(cleaned) { return json }
        let labeled = parseLabeled(cleaned)
        return labeled?.isValid == true ? labeled : nil
    }

    static func parseOrFallback(_ raw: String) -> MealSuggestionContent {
        parse(raw) ?? fallback(from: raw)
    }

    static func sanitize(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            let jsonSlice = text[start...end]
            if String(jsonSlice).contains("\"name\"") {
                text = String(jsonSlice)
            }
        }
        return text
    }

    private static func parseJSON(_ raw: String) -> MealSuggestionContent? {
        guard raw.hasPrefix("{"), let data = raw.data(using: .utf8) else { return nil }
        guard var decoded = try? JSONDecoder().decode(MealSuggestionContent.self, from: data) else { return nil }
        decoded.protocolScore = min(100, max(0, decoded.protocolScore))
        decoded.showsScore = true
        if decoded.subScores == nil {
            decoded.subScores = MealSubScores(
                protocolFit: decoded.protocolScore,
                satiety: min(100, decoded.protocolScore + 3),
                antiBloat: max(45, decoded.protocolScore - 5)
            )
        }
        return decoded.isValid ? decoded : nil
    }

    private static func parseSubScores(from raw: String, fallbackScore: Int) -> MealSubScores {
        var protocolFit = fallbackScore
        var satiety = min(100, fallbackScore + 3)
        var antiBloat = max(45, fallbackScore - 5)

        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let value = labeledValue(in: trimmed, labels: ["SCORE_PROTOCOL", "PROTOCOL"]) {
                protocolFit = Int(value.filter(\.isNumber)) ?? protocolFit
            } else if let value = labeledValue(in: trimmed, labels: ["SCORE_SATIETY", "SATIETY", "SATIÉTÉ"]) {
                satiety = Int(value.filter(\.isNumber)) ?? satiety
            } else if let value = labeledValue(in: trimmed, labels: ["SCORE_BLOAT", "ANTI_BLOAT", "ANTIGONFLEMENT"]) {
                antiBloat = Int(value.filter(\.isNumber)) ?? antiBloat
            }
        }

        return MealSubScores(protocolFit: protocolFit, satiety: satiety, antiBloat: antiBloat)
    }

    private static func parseLabeled(_ raw: String) -> MealSuggestionContent? {
        var name = ""
        var mealType = "Repas"
        var score = 75
        var scoreSummary = ""
        var items: [MealSuggestionItem] = []
        var prepMinutes = 15
        var prepSummary = ""
        var coachTip = ""
        var tags: [String] = []

        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let value = labeledValue(in: trimmed, labels: ["MEAL_NAME", "NOM"]) {
                name = value
            } else if let value = labeledValue(in: trimmed, labels: ["MEAL_TYPE", "TYPE"]) {
                mealType = value
            } else if let value = labeledValue(in: trimmed, labels: ["SCORE"]) {
                score = Int(value.filter(\.isNumber)) ?? score
            } else if let value = labeledValue(in: trimmed, labels: ["SCORE_WHY", "SCORE WHY"]) {
                scoreSummary = value
            } else if let value = labeledValue(in: trimmed, labels: ["PREP_MIN", "PREP MIN"]) {
                prepMinutes = Int(value.filter(\.isNumber)) ?? prepMinutes
            } else if let value = labeledValue(in: trimmed, labels: ["PREP", "PRÉPARATION"]) {
                prepSummary = value
            } else if let value = labeledValue(in: trimmed, labels: ["TIP", "CONSEIL"]) {
                coachTip = value
            } else if trimmed.uppercased().hasPrefix("ITEM_") || trimmed.uppercased().hasPrefix("INGREDIENT_") {
                if let item = parseItemLine(trimmed) {
                    items.append(item)
                }
            } else if trimmed.uppercased().hasPrefix("TAG_") {
                if let value = labeledValue(in: trimmed, labels: ["TAG_1", "TAG_2", "TAG_3", "TAG"]) {
                    tags.append(value)
                }
            }
        }

        guard !name.isEmpty else { return nil }

        return MealSuggestionContent(
            name: name,
            mealType: mealType,
            protocolScore: min(100, max(0, score)),
            scoreSummary: scoreSummary,
            items: items,
            prepMinutes: prepMinutes,
            prepSummary: prepSummary,
            coachTip: coachTip,
            tags: tags,
            subScores: parseSubScores(from: raw, fallbackScore: score),
            showsScore: true
        )
    }

    private static func parseItemLine(_ line: String) -> MealSuggestionItem? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        let parts = value.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let name = parts.first, !name.isEmpty else { return nil }
        return MealSuggestionItem(
            name: name,
            quantity: parts.count > 1 ? parts[1] : "—",
            role: parts.count > 2 ? parts[2] : "Autre"
        )
    }

    private static func labeledValue(in line: String, labels: [String]) -> String? {
        let upper = line.uppercased()
        for label in labels {
            let normalized = label.hasSuffix(":") ? label : label + ":"
            if upper.hasPrefix(normalized) {
                let start = line.index(line.startIndex, offsetBy: normalized.count)
                return String(line[start...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func fallback(from text: String) -> MealSuggestionContent {
        let cleaned = CoachFormattedText.plainText(from: text)
        return MealSuggestionContent(
            name: String(cleaned.prefix(48)),
            mealType: "Repas",
            protocolScore: 70,
            scoreSummary: "Aligné avec ton protocole Origine.",
            items: [MealSuggestionItem(name: "Voir détail", quantity: "—", role: "Autre")],
            prepMinutes: 15,
            prepSummary: cleaned,
            coachTip: "",
            tags: [],
            subScores: .balanced,
            showsScore: true
        )
    }
}
