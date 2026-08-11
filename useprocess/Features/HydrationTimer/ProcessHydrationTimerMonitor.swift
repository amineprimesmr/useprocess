import Foundation
import SwiftUI
import UIKit

/// Observe le prochain sip + politique « Dynamic Island seulement » (jamais d'écran verrouillé).
@MainActor
@Observable
final class ProcessHydrationTimerMonitor {
    static let shared = ProcessHydrationTimerMonitor()

    private var waitTask: Task<Void, Never>?
    private var lifecycleObservers: [NSObjectProtocol] = []

    private init() {
        registerLifecycleObservers()
    }

    /// Appelé très tôt au lancement — avant que l'utilisateur ne verrouille.
    func bootstrapAtLaunch() {
        ProcessHydrationTimerStore.shared.reload()
        Task {
            await enforceLockScreenPolicy()
            await restoreLiveActivityIfNeeded()
            refreshMonitoring()
        }
    }

    func refreshMonitoring() {
        waitTask?.cancel()
        waitTask = nil

        let store = ProcessHydrationTimerStore.shared
        guard store.isRunning, let nextSipAt = store.nextSipAt else { return }

        let delay = nextSipAt.timeIntervalSinceNow
        if delay <= 0.3 {
            waitTask = Task { @MainActor in
                await pushLiveActivityUpdateIfAllowed()
            }
            return
        }

        waitTask = Task { @MainActor in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            guard ProcessHydrationTimerStore.shared.isRunning else { return }
            await pushLiveActivityUpdateIfAllowed()
        }
    }

    func handleSceneBecameActive() {
        ProcessHydrationTimerStore.shared.reload()
        Task {
            await enforceLockScreenPolicy()
            await restoreLiveActivityIfNeeded()
            refreshMonitoring()
        }
    }

    func handleSceneWillBackground() {
        Task {
            // Laisse iOS basculer en mode verrouillé si besoin.
            try? await Task.sleep(for: .milliseconds(120))
            await enforceLockScreenPolicy()
        }
    }

    /// Supprime toute Live Activity tant que l'iPhone est verrouillé.
    func enforceLockScreenPolicy() async {
        guard !UIApplication.shared.isProtectedDataAvailable else { return }
        await ProcessHydrationTimerNotificationService.cancelAll()
        await ProcessHydrationTimerLiveActivityController.shared.endForDeviceLock()
    }

    private func pushLiveActivityUpdateIfAllowed() async {
        if UIApplication.shared.isProtectedDataAvailable {
            await ProcessHydrationTimerStore.shared.syncLiveActivityHydration()
        } else {
            await enforceLockScreenPolicy()
        }
    }

    private func restoreLiveActivityIfNeeded() async {
        let store = ProcessHydrationTimerStore.shared
        guard store.isRunning else { return }
        guard UIApplication.shared.isProtectedDataAvailable else { return }

        await ProcessHydrationTimerNotificationService.cancelAll()
        await store.syncLiveActivityHydration()
    }

    private func registerLifecycleObservers() {
        let center = NotificationCenter.default

        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    await ProcessHydrationTimerMonitor.shared.enforceLockScreenPolicy()
                }
            }
        )

        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.protectedDataDidBecomeAvailableNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    ProcessHydrationTimerStore.shared.reload()
                    await ProcessHydrationTimerMonitor.shared.restoreLiveActivityIfNeeded()
                    ProcessHydrationTimerMonitor.shared.refreshMonitoring()
                }
            }
        )

        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    await ProcessHydrationTimerMonitor.shared.handleSceneWillBackground()
                }
            }
        )
    }
}
