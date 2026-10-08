import SwiftUI

/// Horloge légère — tick 1 Hz uniquement quand la page Accueil est active (remplace TimelineView permanent).
struct PlanHomePeriodicTicker<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.processTabIsActive) private var isTabActive
    let isActive: Bool
    let interval: TimeInterval
    @ViewBuilder let content: (Date) -> Content

    @State private var now = Date()

    init(
        isActive: Bool,
        interval: TimeInterval = 1,
        @ViewBuilder content: @escaping (Date) -> Content
    ) {
        self.isActive = isActive
        self.interval = interval
        self.content = content
    }

    var body: some View {
        content(now)
            .task(id: isActive && isTabActive && scenePhase == .active) {
                guard isActive && isTabActive && scenePhase == .active else { return }
                now = Date()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(max(0.1, interval))) } catch { return }
                    now = Date()
                }
            }
    }
}
