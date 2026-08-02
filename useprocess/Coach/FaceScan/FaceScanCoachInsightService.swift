import Foundation

/// Génère et met en cache le message coach scan visage (Process Intelligence).
/// Le chat affiche le message en entier — sans streaming ni animation « réflexion ».
@MainActor
enum FaceScanCoachInsightService {
    static let messageMarker = "process.face_scan_insight"

    private static var inflightTasks: [String: Task<CoachMessage?, Never>] = [:]

    static func isCoachInsightMessage(_ message: CoachMessage) -> Bool {
        message.modelUsed == messageMarker
    }

    /// Message prêt à afficher sans attendre l'API (cache ou fallback local).
    static func immediateCoachMessage(
        for result: FaceScanResult,
        insight: FaceScanAIInsight
    ) -> CoachMessage {
        if let cached = cachedCoachMessage(for: result) {
            return cached
        }
        return fallbackCoachMessage(for: result, insight: insight)
    }

    /// Lance la génération en arrière-plan juste après le scan.
    static func pregenerate(for result: FaceScanResult, profile: UnifiedUserProfile?) {
        guard cachedRawMessage(for: result) == nil else { return }
        let history = FaceScanEvolutionEngine.dailyHistory(from: FaceScanHistoryStore.shared.history)
        let insight = FaceScanAIInsightBuilder.insight(
            for: result,
            history: history,
            context: FaceScanInsightContext.fromTodayHealth()
        )
        Task {
            _ = await ensureCoachMessage(for: result, insight: insight, profile: profile)
        }
    }

    /// Retourne le message coach (cache local ou appel IA).
    static func ensureCoachMessage(
        for result: FaceScanResult,
        insight: FaceScanAIInsight,
        profile: UnifiedUserProfile?
    ) async -> CoachMessage? {
        if let cached = cachedCoachMessage(for: result) {
            return cached
        }

        if let existing = inflightTasks[result.id] {
            return await existing.value
        }

        let task = Task<CoachMessage?, Never> {
            await generateCoachMessage(for: result, insight: insight, profile: profile)
        }
        inflightTasks[result.id] = task
        defer { inflightTasks[result.id] = nil }
        return await task.value
    }

    /// Extrait un résumé court pour la carte Plan (2 phrases max).
    static func cardPreview(from coachText: String, maxLength: Int = 260) -> String {
        let display = CoachResponseParser.parseFull(coachText).enrichment.displayText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !display.isEmpty else { return "" }

        var sentences: [String] = []
        var buffer = ""
        for character in display {
            buffer.append(character)
            if ".!?".contains(character) {
                let sentence = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
                buffer = ""
                if sentences.count >= 2 { break }
            }
        }

        let preview: String
        if sentences.count >= 2 {
            preview = sentences.prefix(2).joined(separator: " ")
        } else if !sentences.isEmpty {
            preview = sentences[0]
        } else {
            preview = display
        }

        return truncated(preview, max: maxLength)
    }

    // MARK: - Private

    private static func cachedRawMessage(for result: FaceScanResult) -> String? {
        let trimmed = result.coachInsightMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        if shouldRegenerateCachedMessage(trimmed, for: result) { return nil }
        return trimmed
    }

    /// Ignore les messages IA obsolètes qui minimisent un signal marqué (ex. « légèrement gonflé » à 70 % rétention).
    private static func shouldRegenerateCachedMessage(_ raw: String, for result: FaceScanResult) -> Bool {
        let lower = raw.lowercased()
        let minimizing = [
            "légèrement gonfl", "legerement gonfl", "un peu gonfl",
            "léger gonflement", "legere retention", "légère rétention"
        ]
        guard minimizing.contains(where: { lower.contains($0) }) else { return false }

        let retention = FaceScanIndicators.displayPercent(for: .retention, result: result)
        let recovery = FaceScanIndicators.displayPercent(for: .recovery, result: result)
        let cortisol = FaceScanIndicators.displayPercent(for: .stressLoad, result: result)
        return retention >= 62 || recovery >= 62 || cortisol >= 62
    }

    private static func cachedCoachMessage(for result: FaceScanResult) -> CoachMessage? {
        guard let raw = cachedRawMessage(for: result) else { return nil }
        return coachMessage(from: raw)
    }

    private static func generateCoachMessage(
        for result: FaceScanResult,
        insight: FaceScanAIInsight,
        profile: UnifiedUserProfile?
    ) async -> CoachMessage? {
        if let cached = cachedCoachMessage(for: result) {
            return cached
        }

        guard ProcessPrivacyConsentStore.shared.canUseThirdPartyAI else {
            return persistFallback(for: result, insight: insight)
        }

        if CoachIntelligenceSettingsStore.shared.isEnabled,
           !CoachIntelligenceSettingsStore.shared.canSendCoachMessage {
            return persistFallback(for: result, insight: insight)
        }

        let prompt = insight.coachPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return persistFallback(for: result, insight: insight) }

        do {
            let journeyId = CoachDebloatJourneyStore.ensureConversation(in: CoachConversationLibraryStore.shared)
            let history = CoachDebloatJourneyStore.chatHistory(
                for: journeyId,
                in: CoachConversationLibraryStore.shared
            )
            let reply = try await CoachEngine.sendChatMessage(
                prompt,
                profile: profile,
                history: history
            )
            CoachIntelligenceSettingsStore.shared.recordCoachMessageSent()

            let parsed = CoachResponseParser.parseFull(reply.text)
            var enrichment = parsed.enrichment
            enrichment.contextualActions = []
            enrichment.deepLink = nil
            enrichment.followUps = []
            let message = CoachMessage.assistant(
                from: enrichment,
                modelUsed: messageMarker
            )

            persist(message: message, for: result, aiModel: reply.modelUsed)
            return message
        } catch {
            return persistFallback(for: result, insight: insight)
        }
    }

    private static func persistFallback(for result: FaceScanResult, insight: FaceScanAIInsight) -> CoachMessage {
        let message = fallbackCoachMessage(for: result, insight: insight)
        persist(message: message, for: result, aiModel: nil)
        return message
    }

    private static func fallbackCoachMessage(
        for result: FaceScanResult,
        insight: FaceScanAIInsight
    ) -> CoachMessage {
        let fallbackText = """
        \(insight.title)

        \(insight.body)
        """
        let parsed = CoachResponseParser.parseFull(fallbackText)
        return CoachMessage.assistant(from: parsed.enrichment, modelUsed: messageMarker)
    }

    private static func coachMessage(from raw: String) -> CoachMessage {
        var parsed = CoachResponseParser.parseFull(raw)
        parsed.enrichment.contextualActions = []
        parsed.enrichment.deepLink = nil
        parsed.enrichment.followUps = []
        return CoachMessage.assistant(from: parsed.enrichment, modelUsed: messageMarker)
    }

    private static func persist(message: CoachMessage, for result: FaceScanResult, aiModel: String?) {
        var updated = result
        updated.coachInsightMessage = message.text
        updated.coachInsightModel = aiModel ?? messageMarker
        FaceScanHistoryStore.shared.update(updated)
    }

    private static func truncated(_ text: String, max: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > max else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: max)
        return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
