import Foundation

// MARK: - Store repas (extension WelcomePlanStore)

extension WelcomePlanStore {

    func validatedMealContent(for dayId: String, slot: MealTimeSlot? = nil) -> MealSuggestionContent? {
        guard let plan else { return nil }
        if let slot, let payload = plan.progress.validatedMealsBySlot[dayId]?[slot.rawValue] {
            return MealSuggestionContent.fromStored(payload)
        }
        if let payload = plan.progress.validatedMeals[dayId] {
            return MealSuggestionContent.fromStored(payload)
        }
        return nil
    }

    func saveValidatedMeal(
        dayId: String,
        meal: MealSuggestionContent,
        slot: MealTimeSlot? = nil
    ) {
        guard var current = plan else { return }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: dayId, in: current) else { return }

        let payload = meal.encodedForStorage()
        let resolvedSlot = slot ?? meal.timeSlot

        current.progress.validatedMeals[dayId] = payload
        var slots = current.progress.validatedMealsBySlot[dayId] ?? [:]
        slots[resolvedSlot.rawValue] = payload
        current.progress.validatedMealsBySlot[dayId] = slots

        appendMealHistory(dayId: dayId, meal: meal, slot: resolvedSlot, on: &current)
        mergeShoppingList(from: meal, dayId: dayId, on: &current)
        syncCoachOnMealValidation(meal: meal, dayId: dayId, on: &current)

        syncJournalDayCompletion(on: &current, dayId: dayId)
        savePlan(current)
    }

    /// Compat legacy string.
    func saveValidatedMeal(dayId: String, meal: String) {
        if let content = MealSuggestionContent.fromStored(meal) {
            saveValidatedMeal(dayId: dayId, meal: content)
        } else {
            guard var current = plan else { return }
            guard OriginPlanPresenter.isEditableJournalDay(dayId: dayId, in: current) else { return }
            current.progress.validatedMeals[dayId] = meal
            syncJournalDayCompletion(on: &current, dayId: dayId)
            savePlan(current)
        }
    }

    func addMealToShoppingList(_ meal: MealSuggestionContent, dayId: String?) {
        guard var current = plan else { return }
        mergeShoppingList(from: meal, dayId: dayId, on: &current)
        savePlan(current)
    }

    func toggleShoppingItem(_ id: String) {
        guard var current = plan else { return }
        guard let index = current.progress.shoppingList.firstIndex(where: { $0.id == id }) else { return }
        current.progress.shoppingList[index].isChecked.toggle()
        savePlan(current)
    }

    func removeShoppingItem(_ id: String) {
        guard var current = plan else { return }
        current.progress.shoppingList.removeAll { $0.id == id }
        savePlan(current)
    }

    func clearCheckedShoppingItems() {
        guard var current = plan else { return }
        current.progress.shoppingList.removeAll { $0.isChecked }
        savePlan(current)
    }

    var activeShoppingList: [MealShoppingItem] {
        plan?.progress.shoppingList.filter { !$0.isChecked } ?? []
    }

    func recentMealHistory(limit: Int = 14) -> [MealHistoryEntry] {
        guard let plan else { return [] }
        return plan.progress.mealHistory
            .sorted { $0.validatedAt > $1.validatedAt }
            .prefix(limit)
            .map { $0 }
    }

    func mealHistoryThisWeek() -> [MealHistoryEntry] {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return recentMealHistory(limit: 50).filter { $0.validatedAt >= weekAgo }
    }

    func saveMealFeedback(
        dayId: String,
        historyId: String?,
        rating: Int,
        feeling: MealFeeling,
        note: String = ""
    ) {
        guard var current = plan else { return }
        let entry = MealFeedbackEntry(
            dayId: dayId,
            mealHistoryId: historyId,
            rating: min(5, max(1, rating)),
            feeling: feeling,
            note: note
        )
        current.progress.mealFeedbacks.insert(entry, at: 0)
        current.progress.mealFeedbacks = Array(current.progress.mealFeedbacks.prefix(60))
        savePlan(current)

        CoachMemoryStore.shared.recordPlanAdjustment(
            "Feedback repas (\(feeling.rawValue), \(rating)/5) — \(note.isEmpty ? "sans note" : note)"
        )
    }

    func recentMealFeedbacks(limit: Int = 5) -> [MealFeedbackEntry] {
        Array((plan?.progress.mealFeedbacks ?? []).prefix(limit))
    }

    func adjustedProtocolScore(base: Int, itemName: String) -> Int {
        let feedbacks = recentMealFeedbacks(limit: 12)
        let relevant = feedbacks.filter { fb in
            guard let history = plan?.progress.mealHistory.first(where: { $0.id == fb.mealHistoryId }),
                  let content = history.content else { return false }
            return content.items.contains { $0.name.lowercased().contains(itemName.lowercased()) }
        }
        guard !relevant.isEmpty else { return base }

        let penalty = relevant.reduce(0) { partial, fb in
            partial + (fb.feeling == .heavy ? 8 : fb.feeling == .tired ? 5 : fb.feeling == .ok ? 2 : -2)
        }
        return min(100, max(40, base - penalty / max(relevant.count, 1)))
    }

    // MARK: - Private

    private func appendMealHistory(
        dayId: String,
        meal: MealSuggestionContent,
        slot: MealTimeSlot,
        on plan: inout FaceOriginPlan
    ) {
        let entry = MealHistoryEntry(
            dayId: dayId,
            mealPayload: meal.encodedForStorage(),
            mealSlot: slot,
            protocolScore: meal.protocolScore
        )
        plan.progress.mealHistory.insert(entry, at: 0)
        plan.progress.mealHistory = Array(plan.progress.mealHistory.prefix(120))
    }

    private func mergeShoppingList(
        from meal: MealSuggestionContent,
        dayId: String?,
        on plan: inout FaceOriginPlan
    ) {
        for item in meal.items {
            let exists = plan.progress.shoppingList.contains {
                !$0.isChecked && $0.name.lowercased() == item.name.lowercased()
            }
            guard !exists else { continue }
            plan.progress.shoppingList.insert(
                MealShoppingItem(name: item.name, quantity: item.quantity, dayId: dayId),
                at: 0
            )
        }
        plan.progress.shoppingList = Array(plan.progress.shoppingList.prefix(80))
    }

    private func syncCoachOnMealValidation(
        meal: MealSuggestionContent,
        dayId: String,
        on plan: inout FaceOriginPlan
    ) {
        plan.progress.lastCoachSyncAt = Date()
        let summary = "Repas validé : \(meal.name) (\(meal.mealType), score \(meal.protocolScore)/100) — \(meal.compactSummary.prefix(120))"
        CoachMemoryStore.shared.recordPlanAdjustment(summary)
        CoachConversationStore.invalidateDailyBriefCache()
    }
}
