import Foundation

enum CoachDeepLinkAction: String, Codable, Equatable {
    case plan
    case journal
    case scan
    case streak
    case integration

    var defaultLabel: String {
        switch self {
        case .plan: return AppCopy.t("Ouvrir l'accueil", en: "Open Home")
        case .journal: return AppCopy.t("Ouvrir le journal", en: "Open journal")
        case .scan: return AppCopy.t("Faire mon scan", en: "Take my scan")
        case .streak: return AppCopy.t("Voir ma streak", en: "View my streak")
        case .integration: return AppCopy.t("Continuer la configuration", en: "Continue setup")
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
    var contextualActions: [CoachContextualAction]
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

    private static let metadataLabels = [
        "INTRO:",
        "REASONING:",
        "FOLLOW_UP_1:",
        "FOLLOW_UP_2:",
        "FOLLOW_UP_3:",
        "DEEP_LINK:",
        "MEMORY_UPDATE:",
        "MEMORY_UPDATE_1:",
        "MEMORY_UPDATE_2:",
        "FOOD_LOG:",
        "ARTIFACT:",
        "ACTION_1:",
        "ACTION_2:",
        "ACTION_3:",
        "ACTION_4:"
    ]

    static func parse(_ raw: String) -> CoachMessageEnrichment {
        parseFull(raw).enrichment
    }

    static func parseFull(_ raw: String) -> CoachParsedReply {
        var working = raw
        var followUps: [String] = []
        var deepLink: CoachDeepLink?
        var memoryUpdates: [CoachMemoryUpdate] = []
        var foodLogged = false
        var artifactTitle: String?
        var artifactBody: String?
        var contextualActions: [CoachContextualAction] = []

        // Strip legacy REASONING blocks without surfacing them in the UI.
        _ = extract(label: "REASONING:", from: &working)

        for index in 1...3 {
            if let match = extract(label: "FOLLOW_UP_\(index):", from: &working) {
                if !match.isEmpty { followUps.append(match) }
            }
        }
        followUps = CoachFollowUpSanitizer.sanitized(followUps)

        if let match = extract(label: "DEEP_LINK:", from: &working) {
            let parts = match.split(separator: "|", maxSplits: 1).map(String.init)
            if let actionRaw = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
               let action = CoachDeepLinkAction(rawValue: actionRaw),
               action != .plan {
                let label = parts.count > 1
                    ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    : action.defaultLabel
                deepLink = CoachDeepLink(action: action, label: label.isEmpty ? action.defaultLabel : label)
            }
        }

        for index in 1...2 {
            if let match = extract(label: "MEMORY_UPDATE_\(index):", from: &working) {
                applyMemoryLine(match, into: &memoryUpdates)
            }
        }
        if let match = extract(label: "MEMORY_UPDATE:", from: &working) {
            applyMemoryLine(match, into: &memoryUpdates)
        }

        if extract(label: "FOOD_LOG:", from: &working) != nil {
            foodLogged = true
        }

        if let match = extract(label: "ARTIFACT:", from: &working) {
            let parts = match.split(separator: "|", maxSplits: 1).map(String.init)
            artifactTitle = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
            if parts.count > 1 {
                artifactBody = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        for index in 1...4 {
            if let match = extract(label: "ACTION_\(index):", from: &working),
               let action = CoachContextualAction.parse(line: match),
               action.kind == .applyPlanChanges {
                contextualActions.append(action)
            }
        }

        working = MealSuggestionParser.stripStructuredMealBlock(from: working)

        var display = stripRemainingMetadata(from: working)
        if display.isEmpty {
            display = stripRemainingMetadata(from: raw)
        }

        let enrichment = CoachMessageEnrichment(
            displayText: display,
            reasoning: nil,
            followUps: followUps,
            deepLink: deepLink,
            contextualActions: contextualActions
        )

        return CoachParsedReply(
            enrichment: enrichment,
            memoryUpdates: memoryUpdates,
            foodLogged: foodLogged,
            artifactTitle: artifactTitle,
            artifactBody: artifactBody
        )
    }

    /// Re-parse un message assistant déjà stocké avec métadonnées visibles.
    static func reparsedMessageIfNeeded(_ message: CoachMessage) -> CoachMessage {
        guard message.role == .assistant else { return message }
        if message.reasoning != nil || message.followUps != nil || message.deepLinkAction != nil
            || message.contextualActions != nil {
            return message
        }

        let raw = message.text
        let hasMetadata = metadataLabels.contains {
            raw.range(of: $0, options: .caseInsensitive) != nil
        }
        guard hasMetadata else { return message }

        let parsed = parseFull(raw)
        let rebuilt = CoachMessage.assistant(from: parsed.enrichment, modelUsed: message.modelUsed)
        let text: String = {
            if let intro = MealSuggestionParser.coachIntro(from: raw),
               MealSuggestionParser.parse(raw)?.isValid == true {
                return intro
            }
            let display = rebuilt.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return display.isEmpty ? message.text : display
        }()
        return CoachMessage(
            id: message.id,
            role: .assistant,
            text: text,
            createdAt: message.createdAt,
            modelUsed: message.modelUsed,
            reasoning: nil,
            followUps: rebuilt.followUps,
            deepLinkAction: nil,
            deepLinkLabel: nil,
            contextualActions: rebuilt.contextualActions
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
        guard let labelRange = text.range(of: label, options: .caseInsensitive) else { return nil }

        var removeStart = labelRange.lowerBound
        if removeStart > text.startIndex {
            let before = text.index(before: removeStart)
            if text[before] == " " {
                removeStart = before
            }
        }

        let valueStart = labelRange.upperBound
        guard valueStart <= text.endIndex else { return nil }

        let lineEnd = text[valueStart...].firstIndex(of: "\n") ?? text.endIndex
        let value = String(text[valueStart..<lineEnd]).trimmingCharacters(in: .whitespacesAndNewlines)

        var removeEnd = lineEnd
        if removeEnd < text.endIndex, text[removeEnd] == "\n" {
            removeEnd = text.index(after: removeEnd)
        }

        text.removeSubrange(removeStart..<removeEnd)
        return value.isEmpty ? nil : value
    }

    private static func stripRemainingMetadata(from text: String) -> String {
        var result = text

        for label in metadataLabels {
            while let range = result.range(of: label, options: .caseInsensitive) {
                var removeStart = range.lowerBound
                if removeStart > result.startIndex {
                    let before = result.index(before: removeStart)
                    if result[before] == " " {
                        removeStart = before
                    }
                }

                let tailStart = range.upperBound
                var removeEnd = result.endIndex
                let tail = result[tailStart...]
                for other in metadataLabels where other.caseInsensitiveCompare(label) != .orderedSame {
                    if let next = tail.range(of: other, options: .caseInsensitive) {
                        let absolute = next.lowerBound
                        if absolute < removeEnd {
                            removeEnd = absolute
                        }
                    }
                }

                result.removeSubrange(removeStart..<removeEnd)
            }
        }

        return result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
}

extension CoachMessage {

    var enrichment: CoachMessageEnrichment? {
        let resolvedFollowUps = CoachFollowUpSanitizer.sanitized(followUps ?? [])
        let resolvedActions = resolvedContextualActions.filter { $0.kind == .applyPlanChanges }
        guard !resolvedFollowUps.isEmpty || !resolvedActions.isEmpty else { return nil }

        return CoachMessageEnrichment(
            displayText: text,
            reasoning: nil,
            followUps: resolvedFollowUps,
            deepLink: nil,
            contextualActions: resolvedActions
        )
    }

    static func assistant(from parsed: CoachMessageEnrichment, modelUsed: String?) -> CoachMessage {
        let applyActions = parsed.contextualActions.filter { $0.kind == .applyPlanChanges }
        return CoachMessage(
            role: .assistant,
            text: parsed.displayText,
            modelUsed: modelUsed,
            reasoning: nil,
            followUps: parsed.followUps.isEmpty ? nil : parsed.followUps,
            deepLinkAction: nil,
            deepLinkLabel: nil,
            contextualActions: applyActions.isEmpty
                ? nil
                : CoachContextualAction.encodeList(applyActions)
        )
    }
}
