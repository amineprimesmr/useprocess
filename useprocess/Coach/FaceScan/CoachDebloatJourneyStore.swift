import Foundation

/// Conversation coach unique — fil chronologique scan + bilans debloat.
@MainActor
enum CoachDebloatJourneyStore {
    private static var title: String {
        AppCopy.tSync("Trajectoire debloat", en: "Debloat trajectory")
    }
    private static var subject: String { title }

    private static func matchesJourney(_ conversation: CoachConversation) -> Bool {
        let candidates: Set<String> = [
            "Trajectoire debloat",
            "Debloat trajectory",
            title,
            subject,
        ]
        return candidates.contains(conversation.title) || candidates.contains(conversation.subjectLabel ?? "")
    }

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

        if let existing = store.library.conversations.first(where: matchesJourney) {
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
        let water = answers[EveningCheckInQuestionID.water] == "yes"
            ? AppCopy.tSync("oui", en: "yes")
            : AppCopy.tSync("non", en: "no")
        let meal = answers[EveningCheckInQuestionID.debloatMeal] == "yes"
            ? AppCopy.tSync("oui", en: "yes")
            : AppCopy.tSync("non", en: "no")
        let routine = answers[EveningCheckInQuestionID.morningRoutine] == "yes"
            ? AppCopy.tSync("oui", en: "yes")
            : AppCopy.tSync("non", en: "no")
        let streak = ProcessStreakStore.shared.displayStreak
        let text = AppCopy.tSync(
            """
            [Check du jour — \(record.dayKey)]
            Eau: \(water) · Repas debloat: \(meal) · Routine: \(routine)
            Score trajectoire: \(Int(record.compositeScore))/100 · Verdict: \(record.verdict.shortLabel) · Série: \(streak)
            \(summary)
            """,
            en: """
            [Daily check — \(record.dayKey)]
            Water: \(water) · Debloat meal: \(meal) · Routine: \(routine)
            Trajectory score: \(Int(record.compositeScore))/100 · Verdict: \(record.verdict.shortLabel) · Streak: \(streak)
            \(summary)
            """
        )

        let message = CoachMessage(role: .user, text: text)
        store.appendToActive(message)
    }

    static func faceScanUserMessage(scanId: String, scanNumber: Int) -> CoachMessage {
        let display = AppCopy.tSync(
            "Scan visage #\(scanNumber) — analyse ma progression debloat vs mes scans précédents.",
            en: "Face scan #\(scanNumber) — analyze my debloat progress vs my previous scans."
        )
        let text = CoachFaceScanMessageMarker.embed(scanId: scanId, displayText: display)
        return CoachMessage(role: .user, text: text)
    }

    private static func persistedConversationId() -> UUID? {
        ProcessDebloatTrajectoryStore.shared.debloatJourneyConversationId
    }
}
