import Foundation
import SwiftUI

/// Popup Dynamic Island affiché juste après un scan — streak animée + barre de progression.
@MainActor
@Observable
final class ScanCompletionToastPresenter {
    static let shared = ScanCompletionToastPresenter()

    /// Durée d'affichage avant fermeture automatique.
    private static let visibleDuration: Duration = .milliseconds(4500)

    private init() {}

    var isPresented = false

    private var autoDismissTask: Task<Void, Never>?

    private(set) var message = DynamicIslandToastMessage(
        symbol: "flame.fill",
        symbolFont: .system(size: 32, weight: .semibold),
        symbolForegroundStyle: (.white, ProcessStreakPalette.flame),
        title: "",
        message: ""
    )

    func presentScanCompleted(streakBefore: Int, streakAfter: Int, nextMilestoneDays: Int?) {
        message = .scanCompleted(
            streakBefore: streakBefore,
            streakAfter: streakAfter,
            nextMilestoneDays: nextMilestoneDays
        )
        HapticManager.shared.impact(.medium)
        isPresented = true
        scheduleAutoDismiss()
    }

    func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        isPresented = false
    }

    /// Sans cette fermeture, `isPresented` restait bloqué à `true` : la fenêtre
    /// overlay gardait `isUserInteractionEnabled = true` et son calque plein écran
    /// interceptait **tous** les taps de l'app, définitivement.
    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        let duration = Self.visibleDuration
        autoDismissTask = Task { @MainActor in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self.autoDismissTask = nil
            self.isPresented = false
        }
    }
}
