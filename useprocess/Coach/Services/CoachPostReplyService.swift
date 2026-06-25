import Foundation

@MainActor
enum CoachPostReplyService {

    static func applySideEffects(parsed: CoachParsedReply, userText: String, rawAssistantText: String) {
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
                title: "Graphique · \(title)",
                content: body
            )
        }

        if parsed.foodLogged {
            _ = CoachFoodLogService.tryLogMeal(from: rawAssistantText, userText: userText)
        }
    }
}

@MainActor
enum CoachFoodLogService {

    @discardableResult
    static func tryLogMeal(from assistantText: String, userText: String) -> Bool {
        guard var plan = WelcomePlanStore.shared.plan,
              let day = OriginPlanPresenter.todayDay(in: plan) else { return false }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: day.id, in: plan) else { return false }

        if let meal = CoachMealMessageDetector.mealContent(from: assistantText), meal.isValid {
            WelcomePlanStore.shared.saveDraftMeal(dayId: day.id, meal: meal, slot: meal.timeSlot)
            CoachProcessFilesStore.shared.upsert(
                title: "Repas brouillon · \(meal.timeSlot.rawValue)",
                content: meal.compactSummary
            )
            return true
        }

        let combined = "\(userText)\n\(assistantText)"
        let lower = combined.lowercased()
        guard lower.contains("repas") || lower.contains("mang") || lower.contains("déjeuner")
            || lower.contains("dejeuner") || lower.contains("dîner") || lower.contains("diner") else {
            return false
        }

        let fallback = MealSuggestionContent.asProcessDefault(
            name: "Repas noté par le coach",
            mealType: inferredMealType(from: combined),
            items: [MealSuggestionItem(name: "Repas", quantity: "1 portion", role: "Autre")],
            prepMinutes: 10,
            prepSummary: String(combined.prefix(180)),
            coachTip: "Validé depuis le coach.",
            tags: ["Coach"],
            imageAssetName: nil
        )
        WelcomePlanStore.shared.saveDraftMeal(dayId: day.id, meal: fallback, slot: fallback.timeSlot)
        return true
    }

    private static func inferredMealType(from text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("petit") { return "Petit-déjeuner" }
        if lower.contains("dîner") || lower.contains("diner") || lower.contains("soir") { return "Dîner" }
        if lower.contains("collation") { return "Collation" }
        return "Déjeuner"
    }
}

@MainActor
enum CoachTrainingTemplateStore {

    static func promptBlock(plan: FaceOriginPlan?) -> String {
        guard let plan,
              let day = OriginPlanPresenter.todayDay(in: plan),
              let training = day.training else { return "" }

        var lines: [String] = [
            "SÉANCE DU JOUR : \(training.sessionName) (\(training.durationMinutes) min)"
        ]
        if !training.warmup.isEmpty {
            lines.append("Échauffement : \(training.warmup.prefix(3).joined(separator: ", "))")
        }
        for exercise in training.exercises.prefix(4) {
            lines.append("• \(exercise.name) — \(exercise.sets)×\(exercise.reps)")
        }
        if let notes = training.notes, !notes.isEmpty {
            lines.append("Note : \(notes)")
        }
        return "\nTEMPLATE ENTRAÎNEMENT :\n" + lines.joined(separator: "\n")
    }
}

@MainActor
enum CoachMyMemoryExtractor {

    static func heuristicExtract(userText: String) {
        let lower = userText.lowercased()
        if lower.contains("objectif") || lower.contains("but ") {
            CoachMyMemoryStore.shared.add(category: .goals, text: String(userText.prefix(220)))
        }
        if lower.contains("bless") || lower.contains("douleur") || lower.contains("genou") {
            CoachMyMemoryStore.shared.add(category: .healthHistory, text: String(userText.prefix(220)))
        }
        if lower.contains("voyage") || lower.contains("week-end") || lower.contains("weekend") {
            CoachMyMemoryStore.shared.add(category: .events, text: String(userText.prefix(220)))
        }
        if lower.contains("stress") || lower.contains("fatigu") || lower.contains("motiv") {
            CoachMyMemoryStore.shared.add(category: .mood, text: String(userText.prefix(220)))
        }
    }
}
