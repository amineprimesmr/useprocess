import Foundation

@MainActor
enum CoachPostReplyService {

    static func applySideEffects(parsed: CoachParsedReply, userText: String, rawAssistantText _: String) {
        for update in parsed.memoryUpdates {
            CoachMyMemoryStore.shared.add(category: update.category, text: update.text)
        }

        if parsed.memoryUpdates.isEmpty {
            CoachMyMemoryExtractor.heuristicExtract(userText: userText)
        }

        CoachProcessFilesStore.shared.syncFromExchange(
            userText: userText,
            assistantText: parsed.enrichment.displayText,
            plan: WelcomePlanStore.shared.plan
        )

        if let title = parsed.artifactTitle,
           let body = parsed.artifactBody,
           !body.isEmpty {
            CoachProcessFilesStore.shared.upsert(
                title: AppCopy.t("Graphique · \(title)", en: "Chart · \(title)"),
                content: body
            )
        }

    }
}

@MainActor
enum CoachTrainingTemplateStore {

    static func promptBlock(plan: FaceOriginPlan?) -> String {
        guard plan != nil else { return "" }
        let cardio = DebloatCardioDayCatalog.session()
        let lines: [String] = [
            AppCopy.tSync(
                "CARDIO OBLIGATOIRE : \(cardio.title) — \(cardio.prescriptionLine)",
                en: "REQUIRED CARDIO: \(cardio.title) — \(cardio.prescriptionLine)"
            ),
            cardio.detail,
            DebloatCardioDayCatalog.frequencyCaption,
            AppCopy.tSync(
                "Aucun autre cardio (pas de vélo, HIIT, course, rameur, randonnée). Uniquement marche inclinée + circuit posture.",
                en: "No other cardio (no bike, HIIT, running, rower, hiking). Incline walk + posture circuit only."
            )
        ]
        return AppCopy.tSync(
            "\nTEMPLATE CARDIO & CIRCUIT :\n",
            en: "\nCARDIO & CIRCUIT TEMPLATE:\n"
        ) + lines.joined(separator: "\n")
    }
}

@MainActor
enum CoachMyMemoryExtractor {

    static func heuristicExtract(userText: String) {
        let lower = userText.lowercased()
        if lower.contains("objectif") || lower.contains("but ") || lower.contains("goal") {
            CoachMyMemoryStore.shared.add(category: .goals, text: String(userText.prefix(220)))
        }
        if lower.contains("bless") || lower.contains("douleur") || lower.contains("genou")
            || lower.contains("injur") || lower.contains("pain") || lower.contains("knee") {
            CoachMyMemoryStore.shared.add(category: .healthHistory, text: String(userText.prefix(220)))
        }
        if lower.contains("voyage") || lower.contains("week-end") || lower.contains("weekend")
            || lower.contains("travel") || lower.contains("trip") {
            CoachMyMemoryStore.shared.add(category: .events, text: String(userText.prefix(220)))
        }
        if lower.contains("stress") || lower.contains("fatigu") || lower.contains("motiv")
            || lower.contains("tired") || lower.contains("exhaust") {
            CoachMyMemoryStore.shared.add(category: .mood, text: String(userText.prefix(220)))
        }
    }
}
