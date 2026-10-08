import SwiftUI

/// Indicateur « en cours » — 3 points animés, léger.
struct CoachThinkingDotsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.processTabIsActive) private var isTabActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.45, paused: !isTabActive || scenePhase != .active || reduceMotion)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(dotColor)
                        .frame(width: 7, height: 7)
                        .opacity(dotOpacity(index: index, phase: phase))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .accessibilityLabel(AppCopy.t("Réponse en cours", en: "Response in progress"))
        }
    }

    private var dotColor: Color {
        theme.isDark ? .white.opacity(0.85) : .black.opacity(0.75)
    }

    private func dotOpacity(index: Int, phase: TimeInterval) -> Double {
        let offset = Double(index) * 0.18
        let wave = sin((phase + offset) * 4.2)
        return 0.28 + (wave + 1) * 0.36
    }
}
