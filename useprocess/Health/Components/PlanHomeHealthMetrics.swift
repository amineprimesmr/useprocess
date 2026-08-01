import Foundation

/// Métriques Santé lues ponctuellement pour la page Accueil — évite d'abonner toute la page à HealthManager.
struct PlanHomeHealthMetrics: Equatable {
    var stepsToday: Int = 0
    var waterLitersToday: Double = 0
    var sleepHours: Double = 0
    var hrv: Double = 0

    @MainActor
    static func fromTodaySnapshot() -> PlanHomeHealthMetrics {
        let snap = HealthManager.shared.todaySnapshot
        return PlanHomeHealthMetrics(
            stepsToday: snap.effort.steps,
            waterLitersToday: snap.nutrition.waterLiters,
            sleepHours: snap.sleep.sleepDuration,
            hrv: snap.vitals.hrv
        )
    }

    @MainActor
    func insightContext() -> FaceScanInsightContext {
        let targets = WelcomePlanStore.shared.plan?.personalizedTargets ?? .default
        return FaceScanInsightContext(
            sleepHours: sleepHours > 0 ? sleepHours : nil,
            hrv: hrv > 0 ? hrv : nil,
            steps: stepsToday > 0 ? stepsToday : nil,
            waterLiters: waterLitersToday > 0 ? waterLitersToday : nil,
            stepTarget: targets.dailySteps,
            hydrationTargetLiters: Double(targets.hydrationLitersPerDay),
            sleepTargetHours: targets.sleepHours
        )
    }
}
