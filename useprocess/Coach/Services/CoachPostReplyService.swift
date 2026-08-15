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
enum CoachFoodLogService {

    @discardableResult
    static func tryLogMeal(from assistantText: String, userText: String) -> Bool {
        guard let plan = WelcomePlanStore.shared.plan,
              let day = OriginPlanPresenter.todayDay(in: plan) else { return false }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: day.id, in: plan) else { return false }

        if let meal = CoachMealMessageDetector.mealContent(from: assistantText), meal.isValid {
            WelcomePlanStore.shared.saveDraftMeal(dayId: day.id, meal: meal, slot: meal.timeSlot)
            CoachProcessFilesStore.shared.upsert(
                title: AppCopy.t("Repas brouillon · \(meal.timeSlot.displayTitle)", en: "Draft meal · \(meal.timeSlot.displayTitle)"),
                content: meal.compactSummary
            )
            return true
        }

        let combined = "\(userText)\n\(assistantText)"
        let lower = combined.lowercased()
        guard lower.contains("repas") || lower.contains("mang") || lower.contains("déjeuner")
            || lower.contains("dejeuner") || lower.contains("dîner") || lower.contains("diner")
            || lower.contains("meal") || lower.contains("lunch") || lower.contains("dinner")
            || lower.contains("breakfast") || lower.contains(" ate") || lower.contains("eat ") else {
            return false
        }

        let fallback = MealSuggestionContent.asProcessDefault(
            name: AppCopy.tSync("Repas noté par le coach", en: "Meal logged by the coach"),
            mealType: inferredMealType(from: combined),
            items: [MealSuggestionItem(
                name: AppCopy.tSync("Repas", en: "Meal"),
                quantity: AppCopy.tSync("1 portion", en: "1 serving"),
                role: AppCopy.tSync("Autre", en: "Other")
            )],
            prepMinutes: 10,
            prepSummary: String(combined.prefix(180)),
            coachTip: AppCopy.tSync("Validé depuis le coach.", en: "Logged from the coach."),
            tags: ["Coach"],
            imageAssetName: nil
        )
        WelcomePlanStore.shared.saveDraftMeal(dayId: day.id, meal: fallback, slot: fallback.timeSlot)
        return true
    }

    private static func inferredMealType(from text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("petit") {
            return AppCopy.tSync("Petit-déjeuner", en: "Breakfast")
        }
        if lower.contains("dîner") || lower.contains("diner") || lower.contains("soir")
            || lower.contains("dinner") {
            return AppCopy.tSync("Dîner", en: "Dinner")
        }
        if lower.contains("collation") || lower.contains("snack") {
            return AppCopy.tSync("Collation", en: "Snack")
        }
        if lower.contains("lunch") || lower.contains("déjeuner") || lower.contains("dejeuner") {
            return AppCopy.tSync("Déjeuner", en: "Lunch")
        }
        return AppCopy.tSync("Déjeuner", en: "Lunch")
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
