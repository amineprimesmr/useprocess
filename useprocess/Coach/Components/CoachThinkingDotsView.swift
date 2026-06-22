import SwiftUI

/// Indicateur « en cours » — 3 points animés, léger.
struct CoachThinkingDotsView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { timeline in
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
            .accessibilityLabel("Réponse en cours")
        }
    }

    private var dotColor: Color {
        colorScheme == .dark ? .white.opacity(0.85) : .black.opacity(0.75)
    }

    private func dotOpacity(index: Int, phase: TimeInterval) -> Double {
        let offset = Double(index) * 0.18
        let wave = sin((phase + offset) * 4.2)
        return 0.28 + (wave + 1) * 0.36
    }
}
