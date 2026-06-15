import Foundation

struct CoachDailyBriefContent: Equatable {
    var verdict: String
    var why: String
    var actions: [String]

    static let empty = CoachDailyBriefContent(verdict: "", why: "", actions: [])

    var isValid: Bool {
        !verdict.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum CoachDailyBriefParser {

    static func sanitize(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")

        let bannedOpenings = [
            "Les gars,",
            "Les gars ",
            "Salut les gars",
            "Hey les gars"
        ]
        for phrase in bannedOpenings {
            text = text.replacingOccurrences(of: phrase, with: "", options: .caseInsensitive)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ raw: String) -> CoachDailyBriefContent {
        let cleaned = sanitize(raw)
        var verdict = ""
        var why = ""
        var actions: [String] = []

        for line in cleaned.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let value = labeledValue(in: trimmed, labels: ["VERDICT", "VERDICT:"]) {
                verdict = value
            } else if let value = labeledValue(in: trimmed, labels: ["POURQUOI", "POURQUOI:"]) {
                why = value
            } else if let value = labeledValue(in: trimmed, labels: ["ACTION_1", "ACTION 1", "ACTION1"]) {
                actions.append(value)
            } else if let value = labeledValue(in: trimmed, labels: ["ACTION_2", "ACTION 2", "ACTION2"]) {
                actions.append(value)
            }
        }

        if verdict.isEmpty {
            return fallback(from: cleaned)
        }

        return CoachDailyBriefContent(
            verdict: verdict,
            why: why,
            actions: Array(actions.prefix(2))
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

    private static func fallback(from text: String) -> CoachDailyBriefContent {
        let sentences = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = sentences.first else {
            return .empty
        }

        let verdict = String(first.prefix(120))
        let why = sentences.dropFirst().first.map { String($0.prefix(140)) } ?? ""
        return CoachDailyBriefContent(verdict: verdict, why: why, actions: [])
    }
}
