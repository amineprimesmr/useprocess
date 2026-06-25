import Foundation

enum CoachDeepLinkAction: String, Codable, Equatable {
    case plan
    case journal
    case scan
    case streak
    case integration

    var defaultLabel: String {
        switch self {
        case .plan: return "Voir mon plan"
        case .journal: return "Ouvrir le journal"
        case .scan: return "Faire mon scan"
        case .streak: return "Voir ma streak"
        case .integration: return "Continuer l'intégration"
        }
    }
}

struct CoachDeepLink: Equatable {
    let action: CoachDeepLinkAction
    let label: String
}

struct CoachMessageEnrichment: Equatable {
    var displayText: String
    var reasoning: String?
    var followUps: [String]
    var deepLink: CoachDeepLink?
}

struct CoachMemoryUpdate: Equatable {
    let category: CoachMyMemoryCategory
    let text: String
}

struct CoachParsedReply: Equatable {
    var enrichment: CoachMessageEnrichment
    var memoryUpdates: [CoachMemoryUpdate]
    var foodLogged: Bool
    var artifactTitle: String?
    var artifactBody: String?
}

enum CoachResponseParser {

    static func parse(_ raw: String) -> CoachMessageEnrichment {
        parseFull(raw).enrichment
    }

    static func parseFull(_ raw: String) -> CoachParsedReply {
        var text = raw
        var reasoning: String?
        var followUps: [String] = []
        var deepLink: CoachDeepLink?
        var memoryUpdates: [CoachMemoryUpdate] = []
        var foodLogged = false
        var artifactTitle: String?
        var artifactBody: String?

        if let match = extract(label: "REASONING:", from: &text) {
            reasoning = match.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for index in 1...3 {
            if let match = extract(label: "FOLLOW_UP_\(index):", from: &text) {
                let q = match.trimmingCharacters(in: .whitespacesAndNewlines)
                if !q.isEmpty { followUps.append(q) }
            }
        }

        if let match = extract(label: "DEEP_LINK:", from: &text) {
            let parts = match.split(separator: "|", maxSplits: 1).map(String.init)
            if let actionRaw = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
               let action = CoachDeepLinkAction(rawValue: actionRaw) {
                let label = parts.count > 1
                    ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    : action.defaultLabel
                deepLink = CoachDeepLink(action: action, label: label.isEmpty ? action.defaultLabel : label)
            }
        }

        for index in 1...2 {
            if let match = extract(label: "MEMORY_UPDATE_\(index):", from: &text) {
                applyMemoryLine(match, into: &memoryUpdates)
            }
        }
        if let match = extract(label: "MEMORY_UPDATE:", from: &text) {
            applyMemoryLine(match, into: &memoryUpdates)
        }

        if extract(label: "FOOD_LOG:", from: &text) != nil {
            foodLogged = true
        }

        if let match = extract(label: "ARTIFACT:", from: &text) {
            let parts = match.split(separator: "|", maxSplits: 1).map(String.init)
            artifactTitle = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
            if parts.count > 1 {
                artifactBody = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let display = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")

        let enrichment = CoachMessageEnrichment(
            displayText: display.isEmpty ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : display,
            reasoning: reasoning?.isEmpty == true ? nil : reasoning,
            followUps: followUps,
            deepLink: deepLink
        )

        return CoachParsedReply(
            enrichment: enrichment,
            memoryUpdates: memoryUpdates,
            foodLogged: foodLogged,
            artifactTitle: artifactTitle,
            artifactBody: artifactBody
        )
    }

    private static func applyMemoryLine(_ line: String, into updates: inout [CoachMemoryUpdate]) {
        let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let categoryRaw = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let text = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let category: CoachMyMemoryCategory = {
            if let match = CoachMyMemoryCategory.allCases.first(where: { $0.rawValue == categoryRaw }) {
                return match
            }
            if let match = CoachMyMemoryCategory.allCases.first(where: { $0.label.caseInsensitiveCompare(categoryRaw) == .orderedSame }) {
                return match
            }
            return .goals
        }()
        updates.append(CoachMemoryUpdate(category: category, text: text))
    }

    private static func extract(label: String, from text: inout String) -> String? {
        guard let range = text.range(of: label, options: .caseInsensitive) else { return nil }
        let after = text[range.upperBound...]
        let lineEnd = after.firstIndex(of: "\n") ?? after.endIndex
        let value = String(after[..<lineEnd])
        text.removeSubrange(range.lowerBound..<lineEnd)
        if lineEnd < after.endIndex, after[lineEnd] == "\n" {
            text.remove(at: lineEnd)
        }
        return value
    }
}
