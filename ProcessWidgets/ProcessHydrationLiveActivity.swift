import ActivityKit
import SwiftUI
import WidgetKit

struct ProcessHydrationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ProcessHydrationActivityAttributes.self) { context in
            // Fallback lock screen : même UI compacte que la DI (pas de bandeau noir vide).
            ProcessHydrationPhaseView(state: context.state) { _ in
                HStack(spacing: 8) {
                    ProcessHydrationDropIcon.compactImage(side: 16)
                    ProcessHydrationCompactTimer(nextSipAt: context.state.nextSipAt)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ProcessHydrationPhaseView(state: context.state) { phase in
                        ProcessHydrationExpandedLeading(state: context.state, phase: phase)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ProcessHydrationPhaseView(state: context.state) { phase in
                        ProcessHydrationExpandedTrailing(state: context.state, phase: phase)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProcessHydrationPhaseView(state: context.state) { phase in
                        ProcessHydrationExpandedBottom(state: context.state, phase: phase)
                    }
                }
            } compactLeading: {
                ProcessHydrationDropIcon.compactImage(side: 17)
            } compactTrailing: {
                ProcessHydrationCompactTimer(
                    nextSipAt: context.state.nextSipAt
                )
            } minimal: {
                ProcessHydrationCompactTimer(
                    nextSipAt: context.state.nextSipAt,
                    minimal: true
                )
            }
            .widgetURL(
                context.state.effectivePhase() == .drinkNow
                    ? ProcessHydrationDeepLink.sipURL(milliliters: 500)
                    : ProcessHydrationDeepLink.openURL
            )
            .keylineTint(ProcessHydrationLiveActivityPalette.accent)
        }
    }
}

// MARK: - Phase auto-refresh à l'échéance du timer (sans attendre l'app)

private struct ProcessHydrationPhaseView<Content: View>: View {
    let state: ProcessHydrationActivityAttributes.ContentState
    @ViewBuilder let content: (ProcessHydrationActivityAttributes.Phase) -> Content

    var body: some View {
        if state.phase == .drinkNow || state.nextSipAt <= Date() {
            content(state.effectivePhase())
        } else {
            TimelineView(.explicit([state.nextSipAt])) { timeline in
                content(state.effectivePhase(at: timeline.date))
            }
        }
    }
}

// MARK: - Expanded regions (pas de if au niveau DynamicIsland builder)

private struct ProcessHydrationExpandedLeading: View {
    let state: ProcessHydrationActivityAttributes.ContentState
    let phase: ProcessHydrationActivityAttributes.Phase

    var body: some View {
        Group {
            if phase == .drinkNow {
                ProcessHydrationDrinkNowLeadingRow()
            } else {
                ProcessHydrationDropIcon.image(side: 40)
                    .padding(.leading, 2)
            }
        }
    }
}

private struct ProcessHydrationExpandedTrailing: View {
    let state: ProcessHydrationActivityAttributes.ContentState
    let phase: ProcessHydrationActivityAttributes.Phase

    var body: some View {
        Group {
            if phase == .drinkNow {
                ProcessHydrationLogDropButton(side: 44)
            } else {
                ProcessHydrationExpandedTimer(nextSipAt: state.nextSipAt)
                    .padding(.trailing, 2)
            }
        }
    }
}

private struct ProcessHydrationExpandedBottom: View {
    let state: ProcessHydrationActivityAttributes.ContentState
    let phase: ProcessHydrationActivityAttributes.Phase

    var body: some View {
        ProcessHydrationHydrationProgressBar(
            progress: state.progress,
            litersLabel: state.litersLabel,
            accent: ProcessHydrationLiveActivityPalette.accent,
            emphasize: phase == .drinkNow
        )
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
}

private struct ProcessHydrationExpandedTimer: View {
    let nextSipAt: Date

    private var range: ClosedRange<Date> {
        Date.now...max(nextSipAt, Date.now.addingTimeInterval(1))
    }

    var body: some View {
        Text(timerInterval: range, countsDown: true)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(minWidth: 72, alignment: .trailing)
    }
}

private struct ProcessHydrationHydrationProgressBar: View {
    let progress: Double
    let litersLabel: String
    let accent: Color
    var emphasize: Bool = false

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let fillWidth = max(8, width * clampedProgress)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.85),
                                    Color(red: 0.18, green: 0.62, blue: 0.98)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)
                        .shadow(color: accent.opacity(emphasize ? 0.55 : 0.35), radius: emphasize ? 6 : 4, y: 1)

                    if emphasize {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.35))
                            .frame(width: min(fillWidth, 28), height: 5)
                            .blur(radius: 2)
                            .offset(x: max(0, fillWidth - 34))
                    }
                }
            }
            .frame(height: 7)

            HStack {
                Text(ProcessHydrationCopy.hydrationTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 8)

                Text(litersLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Drink now row (réf. maquette)

private struct ProcessHydrationDrinkNowLeadingRow: View {
    var body: some View {
        HStack(spacing: 10) {
            ProcessHydrationDropIcon.image(side: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(ProcessHydrationCopy.goLabel)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(ProcessHydrationCopy.drinkReminderLine)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ProcessHydrationLiveActivityPalette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.leading, 2)
    }
}

private struct ProcessHydrationLogDropButton: View {
    let side: CGFloat

    var body: some View {
        Link(destination: ProcessHydrationDeepLink.sipURL(milliliters: 500)) {
            ProcessHydrationDropIcon.image(side: side * 0.82)
                .frame(width: side, height: side)
        }
    }
}

private struct ProcessHydrationCompactTimer: View {
    let nextSipAt: Date
    var minimal: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, nextSipAt.timeIntervalSince(timeline.date))
            let isDue = remaining <= 0

            Text(ProcessHydrationCountdownFormatting.compactLabel(for: remaining))
                .font(.system(size: minimal ? 11 : 13, weight: .bold, design: .rounded))
                .foregroundStyle(
                    isDue
                        ? ProcessHydrationLiveActivityPalette.accent
                        : .white
                )
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(minWidth: minimal ? 28 : 44, alignment: .trailing)
        }
    }
}

private enum ProcessHydrationLiveActivityPalette {
    static let accent = Color(red: 0.32, green: 0.78, blue: 0.96)
}
