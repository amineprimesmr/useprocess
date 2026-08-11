import AppIntents
import Foundation

/// Shortcuts / Siri — logue une gorgée (+500 ml par défaut).
struct ProcessHydrationLogSipIntent: AppIntent {
    static var title: LocalizedStringResource = "Drink water"
    static var description = IntentDescription("Log a hydration sip")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Milliliters")
    var milliliters: Int

    init() {
        milliliters = 500
    }

    init(milliliters: Int) {
        self.milliliters = milliliters
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let amount = milliliters > 0 ? milliliters : 500
        if ProcessHydrationTimerStore.shared.isRunning {
            _ = await ProcessHydrationTimerStore.shared.logSip(milliliters: amount, celebrateOnHome: true)
        } else {
            _ = ProcessHydrationLogStore.shared.addWater(
                milliliters: amount,
                dayId: nil,
                targetMilliliters: ProcessDailyTargets.hydrationTargetMilliliters
            )
        }
        ProcessHydrationTimerPresenter.shared.clear()
        return .result()
    }
}
