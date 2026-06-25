import Foundation

extension CoachMessage {

    var enrichment: CoachMessageEnrichment? {
        var link: CoachDeepLink?
        if let actionRaw = deepLinkAction,
           let action = CoachDeepLinkAction(rawValue: actionRaw) {
            let label = deepLinkLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
            link = CoachDeepLink(
                action: action,
                label: (label?.isEmpty == false ? label! : action.defaultLabel)
            )
        }

        let hasReasoning = !(reasoning?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let resolvedFollowUps = followUps ?? []
        guard hasReasoning || !resolvedFollowUps.isEmpty || link != nil else { return nil }

        return CoachMessageEnrichment(
            displayText: text,
            reasoning: hasReasoning ? reasoning : nil,
            followUps: resolvedFollowUps,
            deepLink: link
        )
    }

    static func assistant(from parsed: CoachMessageEnrichment, modelUsed: String?) -> CoachMessage {
        CoachMessage(
            role: .assistant,
            text: parsed.displayText,
            modelUsed: modelUsed,
            reasoning: parsed.reasoning,
            followUps: parsed.followUps.isEmpty ? nil : parsed.followUps,
            deepLinkAction: parsed.deepLink?.action.rawValue,
            deepLinkLabel: parsed.deepLink?.label
        )
    }
}
