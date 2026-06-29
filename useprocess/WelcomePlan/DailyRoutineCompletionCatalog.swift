import Foundation

/// Validation granulaire des cartes « Routine quotidienne » (maintenir 5 s).
enum DailyRoutineCompletionCatalog {
    static let holdDurationSeconds: TimeInterval = 5

    static let morningCarouselItemIds: Set<String> = [
        "daily-routine-soleil",
        "daily-routine-eau"
    ]

    static func taskId(dayId: String, carouselItemId: String) -> String {
        "\(dayId).routine.\(carouselItemId)"
    }

    static func isCompleted(
        plan: FaceOriginPlan,
        dayId: String,
        carouselItemId: String
    ) -> Bool {
        plan.progress.status(for: taskId(dayId: dayId, carouselItemId: carouselItemId), dayId: dayId) == .completed
    }

    /// Aligne les leviers journal agrégés quand les sous-actions sont faites.
    static func syncAggregatedJournalTasks(on plan: inout FaceOriginPlan, dayId: String) {
        let morningDone = morningCarouselItemIds.allSatisfy {
            isCompleted(plan: plan, dayId: dayId, carouselItemId: $0)
        }
        if morningDone {
            markCompleted(on: &plan, taskId: "\(dayId).core.morning", dayId: dayId)
        }
    }

    private static func markCompleted(on plan: inout FaceOriginPlan, taskId: String, dayId: String) {
        let key = OriginPlanProgress.taskKey(dayId: dayId, taskId: taskId)
        guard plan.progress.taskStatuses[key] != .completed else { return }
        plan.progress.taskStatuses[key] = .completed
        plan.progress.completedTaskIds.insert(taskId)
    }
}
