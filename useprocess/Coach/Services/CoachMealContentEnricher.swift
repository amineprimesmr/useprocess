import Foundation

/// Aligne une suggestion repas du coach sur le catalogue Process (image + ingrédients).
@MainActor
enum CoachMealContentEnricher {

    /// Quand l'IA répond en prose (sans MEAL_NAME / ITEM_*), retrouve le repas catalogue ou du jour.
    static func resolveLooseMeal(assistantText: String, userText: String?) -> MealSuggestionContent? {
        let assistant = assistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !assistant.isEmpty else { return nil }

        let planType = WelcomePlanStore.shared.plan?.nutritionPlanType ?? .threeMeals
        let slot = inferredSlot(from: userText) ?? inferredSlot(from: assistant) ?? .lunch
        let combined = "\(userText ?? "")\n\(assistant)"

        guard isMealConversation(userText: userText, assistantText: assistant) else { return nil }

        if let catalog = catalogMealMentioned(in: combined, preferredSlot: slot, planType: planType) {
            return enrich(catalog)
        }

        if let today = todayMeal(for: slot) {
            return enrich(today)
        }

        return nil
    }

    static func plainTextIntro(from assistantText: String, mealName: String) -> String? {
        let text = assistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let intro = MealSuggestionParser.coachIntro(from: text) {
            return intro
        }

        var intro: String
        if let range = text.range(of: mealName, options: [.caseInsensitive, .diacriticInsensitive]) {
            intro = String(text[..<range.lowerBound])
        } else {
            intro = text.components(separatedBy: ".").first ?? text
        }

        intro = intro
            .replacingOccurrences(of: "Valide-le dans l'app et c'est parti.", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Valide-le dans l'app.", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":—- "))

        if intro.count > 220 {
            intro = String(intro.prefix(217)) + "…"
        }

        return intro.isEmpty ? nil : intro
    }

    static func enrich(_ meal: MealSuggestionContent) -> MealSuggestionContent {
        let planType = WelcomePlanStore.shared.plan?.nutritionPlanType ?? .threeMeals
        let slot = meal.timeSlot

        guard var enriched = resolveCatalogMeal(meal, slot: slot, planType: planType) else {
            var fallback = meal
            fallback.imageAssetName = MealNutritionCatalog.resolvedImageAsset(
                for: meal,
                slot: slot,
                planType: planType
            )
            return fallback
        }

        if !meal.coachTip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            enriched.coachTip = meal.coachTip
        }

        if meal.protocolScore > 0, meal.showsScore {
            enriched.protocolScore = meal.protocolScore
            enriched.scoreSummary = meal.scoreSummary.isEmpty ? enriched.scoreSummary : meal.scoreSummary
            enriched.showsScore = true
            enriched.subScores = meal.subScores ?? enriched.subScores
        }

        if meal.prepMinutes > 0 {
            enriched.prepMinutes = meal.prepMinutes
        }
        if !meal.prepSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            enriched.prepSummary = meal.prepSummary
        }

        return enriched
    }

    private static func resolveCatalogMeal(
        _ meal: MealSuggestionContent,
        slot: MealTimeSlot,
        planType: NutritionPlanType
    ) -> MealSuggestionContent? {
        if let exact = ProcessDebloatMealLibrary.catalogMeal(
            matchingName: meal.name,
            slot: slot,
            planType: planType
        ) {
            return merge(parsed: meal, catalog: exact)
        }

        if let fuzzy = bestCatalogMatch(for: meal, slot: slot, planType: planType) {
            return merge(parsed: meal, catalog: fuzzy)
        }

        return nil
    }

    private static func merge(parsed: MealSuggestionContent, catalog: MealSuggestionContent) -> MealSuggestionContent {
        var merged = catalog
        merged.mealType = parsed.mealType.isEmpty ? catalog.mealType : parsed.mealType

        if hasUsableItems(parsed.items) {
            merged.items = parsed.items
        }

        if !parsed.coachTip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.coachTip = parsed.coachTip
        }

        if parsed.showsScore {
            merged.protocolScore = parsed.protocolScore
            merged.scoreSummary = parsed.scoreSummary
            merged.showsScore = true
            merged.subScores = parsed.subScores ?? catalog.subScores
        }

        if parsed.prepMinutes > 0 {
            merged.prepMinutes = parsed.prepMinutes
        }
        if !parsed.prepSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.prepSummary = parsed.prepSummary
        }
        if !parsed.tags.isEmpty {
            merged.tags = parsed.tags
        }

        return merged
    }

    private static func hasUsableItems(_ items: [MealSuggestionItem]) -> Bool {
        guard items.count >= 3 else { return false }
        let placeholders = Set(["voir détail", "réessayer", "repas"])
        return items.contains { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !name.isEmpty && !placeholders.contains(name)
        }
    }

    private static func bestCatalogMatch(
        for meal: MealSuggestionContent,
        slot: MealTimeSlot,
        planType: NutritionPlanType
    ) -> MealSuggestionContent? {
        let candidates = ProcessDebloatMealLibrary.catalogMeals(for: slot)
        let query = normalized(meal.name)

        var best: MealSuggestionContent?
        var bestScore = 0

        for candidate in candidates {
            let score = nameMatchScore(query: query, candidate: normalized(candidate.name))
            if score > bestScore {
                bestScore = score
                best = candidate
            }
        }

        return bestScore >= 4 ? best : nil
    }

    private static func nameMatchScore(query: String, candidate: String) -> Int {
        guard !query.isEmpty, !candidate.isEmpty else { return 0 }
        if query == candidate { return 10 }
        if query.contains(candidate) || candidate.contains(query) { return 8 }

        let queryTokens = Set(tokenize(query))
        let candidateTokens = Set(tokenize(candidate))
        let overlap = queryTokens.intersection(candidateTokens).count
        return overlap >= 2 ? overlap + 2 : 0
    }

    private static func normalized(_ raw: String) -> String {
        raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokenize(_ raw: String) -> [String] {
        normalized(raw)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }

    private static func isMealConversation(userText: String?, assistantText: String) -> Bool {
        if let userText, CoachMealMessageDetector.isMealRelated(userText: userText) {
            return true
        }
        let lower = assistantText.lowercased()
        let hints = [
            "repas", "dîner", "diner", "déjeuner", "dejeuner", "petit-déjeuner", "collation",
            "ingrédient", "catalogue", "déjà dans l'app", "deja dans l'app", "manger ce soir"
        ]
        return hints.contains { lower.contains($0) }
    }

    private static func inferredSlot(from text: String?) -> MealTimeSlot? {
        guard let text else { return nil }
        let lower = text.lowercased()
        if lower.contains("petit") || lower.contains("matin") || lower.contains("breakfast") {
            return .breakfast
        }
        if lower.contains("dîner") || lower.contains("diner") || lower.contains("soir") {
            return .dinner
        }
        if lower.contains("collation") || lower.contains("snack") {
            return .snack
        }
        if lower.contains("déjeuner") || lower.contains("dejeuner") || lower.contains("midi") || lower.contains("lunch") {
            return .lunch
        }
        return nil
    }

    private static func todayMeal(for slot: MealTimeSlot) -> MealSuggestionContent? {
        guard let plan = WelcomePlanStore.shared.plan,
              let day = OriginPlanPresenter.todayDay(in: plan) else { return nil }
        let meal = PlanDayMealsProvider.resolvedMeal(
            plan: plan,
            day: day,
            slot: slot,
            store: WelcomePlanStore.shared
        )
        return meal.isValid ? meal : nil
    }

    private static func catalogMealMentioned(
        in text: String,
        preferredSlot: MealTimeSlot,
        planType: NutritionPlanType
    ) -> MealSuggestionContent? {
        let haystack = normalized(text)
        guard !haystack.isEmpty else { return nil }

        var best: MealSuggestionContent?
        var bestScore = 0

        for meal in ProcessDebloatMealLibrary.allCatalogMeals {
            let nameNorm = normalized(meal.name)
            guard nameNorm.count >= 8 else { continue }

            var score = 0
            if haystack.contains(nameNorm) {
                score = nameNorm.count + 20
            } else {
                score = nameMatchScore(query: nameNorm, candidate: haystack)
                guard score >= 6 else { continue }
            }

            if meal.timeSlot == preferredSlot { score += 40 }
            if planType.slots.contains(meal.timeSlot) { score += 10 }

            if score > bestScore {
                bestScore = score
                best = meal
            }
        }

        return best
    }
}
