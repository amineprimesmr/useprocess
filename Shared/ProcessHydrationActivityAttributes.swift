import Foundation
import ActivityKit

/// Shared between the app and the ProcessWidgets Live Activity extension.
nonisolated struct ProcessHydrationActivityAttributes: ActivityAttributes {
    nonisolated enum Phase: String, Codable, Hashable, Sendable {
        case countingDown
        case drinkNow
    }

    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var nextSipAt: Date
        var milliliters: Int
        var targetMilliliters: Int
        var intervalMinutes: Int
        var phase: Phase

        var progress: Double {
            guard targetMilliliters > 0 else { return 0 }
            return min(1, Double(milliliters) / Double(targetMilliliters))
        }

        var litersLabel: String {
            let current = String(format: "%g", Double(milliliters) / 1000.0)
            let target = String(format: "%g", Double(targetMilliliters) / 1000.0)
            return "\(current) / \(target) L"
        }

        /// Phase effective côté widget — bascule en drinkNow dès que `nextSipAt` est dépassé,
        /// même si l'app n'a pas encore poussé la mise à jour (background / stale).
        func effectivePhase(at date: Date = Date()) -> Phase {
            if phase == .drinkNow { return .drinkNow }
            if nextSipAt <= date { return .drinkNow }
            return .countingDown
        }
    }

    var startedAt: Date
}
