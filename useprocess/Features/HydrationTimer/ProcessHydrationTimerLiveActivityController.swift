import ActivityKit
import Foundation
import UIKit

@MainActor
final class ProcessHydrationTimerLiveActivityController {
    static let shared = ProcessHydrationTimerLiveActivityController()

    private var currentActivity: Activity<ProcessHydrationActivityAttributes>?

    var hasActiveActivity: Bool {
        if let currentActivity { return true }
        return !Activity<ProcessHydrationActivityAttributes>.activities.isEmpty
    }

    private init() {
        currentActivity = Activity<ProcessHydrationActivityAttributes>.activities.first
    }

    func startOrUpdate(from timerState: ProcessHydrationTimerState) async {
        await sync(from: timerState)
    }

    /// Mise à jour silencieuse — Dynamic Island uniquement (pas d'écran verrouillé).
    func sync(from timerState: ProcessHydrationTimerState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if !UIApplication.shared.isProtectedDataAvailable {
            await endForDeviceLock()
            return
        }

        let contentState = makeContentState(from: timerState)
        let content = ActivityContent(
            state: contentState,
            staleDate: staleDate(for: timerState)
        )

        if let activity = currentActivity ?? Activity<ProcessHydrationActivityAttributes>.activities.first {
            currentActivity = activity
            await activity.update(content)
            return
        }

        guard timerState.isRunning else { return }

        do {
            let attributes = ProcessHydrationActivityAttributes(startedAt: timerState.startedAt ?? Date())
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("Hydration Live Activity start failed: \(error)")
            #endif
        }
    }

    /// Coupe la Live Activity quand l'iPhone se verrouille → plus de bannière lock screen.
    func endForDeviceLock() async {
        await end()
    }

    func end() async {
        let activities = Activity<ProcessHydrationActivityAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }

    private func makeContentState(
        from timerState: ProcessHydrationTimerState
    ) -> ProcessHydrationActivityAttributes.ContentState {
        let milliliters = ProcessHydrationLogStore.shared.milliliters()
        return ProcessHydrationActivityAttributes.ContentState(
            nextSipAt: timerState.nextSipAt ?? Date().addingTimeInterval(60),
            milliliters: milliliters,
            targetMilliliters: timerState.targetMilliliters,
            intervalMinutes: timerState.intervalMinutes,
            phase: .countingDown
        )
    }

    private func staleDate(for timerState: ProcessHydrationTimerState) -> Date? {
        guard let nextSipAt = timerState.nextSipAt else { return nil }
        let buffer = TimeInterval(max(timerState.intervalMinutes, 15) * 60)
        return nextSipAt.addingTimeInterval(buffer)
    }
}
