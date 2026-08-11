import Foundation

/// Après validation depuis la DI / notif — scroll accueil + animation eau + son.
@MainActor
@Observable
final class ProcessHydrationSipCelebrationCoordinator {
    static let shared = ProcessHydrationSipCelebrationCoordinator()

    private(set) var requestID: UUID?
    private(set) var fromMilliliters: Int = 0

    private init() {}

    func requestHomeCelebration(fromMilliliters: Int) {
        self.fromMilliliters = max(0, fromMilliliters)
        requestID = UUID()
        CoachPlanNavigationBridge.shared.focusHydrationOnHome()
    }

    func peekFromMilliliters() -> Int? {
        guard requestID != nil else { return nil }
        return fromMilliliters
    }

    @discardableResult
    func consumeFromMilliliters() -> Int? {
        guard requestID != nil else { return nil }
        defer { requestID = nil }
        return fromMilliliters
    }
}
