import SwiftUI

/// Horloge légère — tick 1 Hz uniquement quand la page Accueil est active (remplace TimelineView permanent).
struct PlanHomePeriodicTicker<Content: View>: View {
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
            .task(id: isActive) {
                guard isActive else { return }
                now = Date()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(interval))
                    now = Date()
                }
            }
    }
}
