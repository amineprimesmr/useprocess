import Foundation

/// Conversation coach unique — fil chronologique scan + bilans debloat.
@MainActor
enum CoachDebloatJourneyStore {
    private static let title = "Trajectoire debloat"
    private static let subject = "Trajectoire debloat"

    static func ensureConversation(in store: CoachConversationLibraryStore) -> UUID {
        if let existing = ProcessDebloatTrajectoryStore.shared.debloatJourneyConversationId,
           store.conversation(for: existing) != nil {
            return existing
        }

        if let persisted = persistedConversationId(),
           store.conversation(for: persisted) != nil {
            ProcessDebloatTrajectoryStore.shared.setDebloatJourneyConversationId(persisted)
            return persisted
        }

        if let existing = store.library.conversations.first(where: { conversation in
            conversation.title == title || conversation.subjectLabel == subject
        }) {
            ProcessDebloatTrajectoryStore.shared.setDebloatJourneyConversationId(existing.id)
            return existing.id
        }

        let id = store.createConversation()
        store.updateConversation(id) { conversation in
            conversation.title = title
            conversation.subjectLabel = subject
        }
        ProcessDebloatTrajectoryStore.shared.setDebloatJourneyConversationId(id)
        return id
    }

    static func chatHistory(for conversationId: UUID, in store: CoachConversationLibraryStore) -> [CoachMessage] {
        store.conversation(for: conversationId)?.messages ?? []
    }

    static func appendCheckInEvent(
        answers: [String: String],
        record: DebloatDayRecord,
        in store: CoachConversationLibraryStore
    ) {
        let conversationId = ensureConversation(in: store)
        store.selectConversation(conversationId)

        let summary = record.aiSummary ?? record.verdict.shortLabel
        let text = """
        [Check du jour — \(record.dayKey)]
        Eau: \(answers[EveningCheckInQuestionID.water] == "yes" ? "oui" : "non") · Repas debloat: \(answers[EveningCheckInQuestionID.debloatMeal] == "yes" ? "oui" : "non") · Cardio: \(answers[EveningCheckInQuestionID.cardio] == "yes" ? "oui" : "non") · Routine: \(answers[EveningCheckInQuestionID.morningRoutine] == "yes" ? "oui" : "non")
        Score trajectoire: \(Int(record.compositeScore))/100 · Verdict: \(record.verdict.shortLabel) · Streak: \(record.streakAfterDay)
        \(summary)
        """

        let message = CoachMessage(role: .user, text: text)
        store.appendToActive(message)
    }

    static func faceScanUserMessage(scanId: String, scanNumber: Int) -> CoachMessage {
        let display = "Scan visage #\(scanNumber) — analyse ma progression debloat vs mes scans précédents."
        let text = CoachFaceScanMessageMarker.embed(scanId: scanId, displayText: display)
        return CoachMessage(role: .user, text: text)
    }

    private static func persistedConversationId() -> UUID? {
        ProcessDebloatTrajectoryStore.shared.debloatJourneyConversationId
    }
}
