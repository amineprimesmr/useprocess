import Foundation

struct FaceScanAnalysisContent: Equatable {
    var summary: String
    var signals: [String]
    var evolution: String
    var tips: [String]

    static let empty = FaceScanAnalysisContent(summary: "", signals: [], evolution: "", tips: [])

    var isValid: Bool {
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum FaceScanAnalysisParser {

    static func sanitize(_ raw: String) -> String {
        raw
            .components(separatedBy: .newlines)
            .filter { line in
                let upper = line.trimmingCharacters(in: .whitespaces).uppercased()
                guard !upper.isEmpty else { return false }
                return !upper.hasPrefix("CONSEIL")
                    && !upper.hasPrefix("TIP:")
                    && !upper.hasPrefix("CONSEIL:")
            }
            .joined(separator: "\n")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ raw: String) -> FaceScanAnalysisContent {
        let cleaned = sanitize(raw)
        var summary = ""
        var signals: [String] = []
        var evolution = ""
        var tips: [String] = []

        for line in cleaned.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let value = labeledValue(in: trimmed, labels: ["RESUME", "RÉSUMÉ"]) {
                summary = value
            } else if let value = labeledValue(in: trimmed, labels: ["SIGNAUX"]) {
                signals = value
                    .components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } else if let value = labeledValue(in: trimmed, labels: ["EVOLUTION", "ÉVOLUTION"]) {
                evolution = value
            } else if let value = labeledValue(in: trimmed, labels: ["CONSEIL_1", "CONSEIL 1"]) {
                tips.append(value)
            } else if let value = labeledValue(in: trimmed, labels: ["CONSEIL_2", "CONSEIL 2"]) {
                tips.append(value)
            }
        }

        if summary.isEmpty {
            return fallback(from: cleaned)
        }

        return FaceScanAnalysisContent(
            summary: summary,
            signals: Array(signals.prefix(4)),
            evolution: evolution,
            tips: Array(tips.prefix(2))
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

    private static func fallback(from text: String) -> FaceScanAnalysisContent {
        let parts = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return FaceScanAnalysisContent(
            summary: parts.first.map { String($0.prefix(160)) } ?? text.prefix(160).description,
            signals: [],
            evolution: "",
            tips: []
        )
    }
}
