import SwiftUI

/// Barre de pas style Whoop — objectif 10 000, sous le titre du circuit lymphatique.
struct PlanLymphCircuitStepsBar: View {
    @ObservedObject private var healthManager = HealthManager.shared
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    private let target = 10_000

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shoeprints.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(progressColor)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            ticks
                .frame(maxWidth: .infinity)
                .frame(height: Layout.tickHeight)

            Text("\(percent)%")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(theme.isDark ? Color.white : theme.primaryText)
                .frame(minWidth: 36, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(height: Layout.height)
        .background {
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(cardFill)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            Task { await healthManager.syncHealthDataForDate(Date()) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await healthManager.syncHealthDataForDate(Date()) }
        }
    }

    private var steps: Int {
        healthManager.todaySnapshot.effort.steps
    }

    private var percent: Int {
        guard target > 0 else { return 0 }
        return min(100, max(0, Int((Double(steps) / Double(target) * 100).rounded(.down))))
    }

    /// Rouge (nul) → orange (moyen) → jaune (bof) → vert (bien) — même échelle que les scores repas.
    private var progressColor: Color {
        MealDebloatScorePalette.tieredColor(for: percent)
    }

    private var cardFill: Color {
        if theme.isDark {
            return Layout.cardDark
        }
        return Color(red: 0.94, green: 0.94, blue: 0.95)
    }

    private var inactiveTick: Color {
        if theme.isDark {
            return Layout.tickIdleDark
        }
        return Color.black.opacity(0.12)
    }

    private var accessibilityLabel: String {
        let nf = NumberFormatter()
        nf.locale = ProcessAppLanguage.shared.locale
        nf.numberStyle = .decimal
        let stepsText = nf.string(from: NSNumber(value: steps)) ?? "\(steps)"
        let targetText = nf.string(from: NSNumber(value: target)) ?? "\(target)"
        return AppCopy.t(
            "\(stepsText) pas sur \(targetText), \(percent) pour cent",
            en: "\(stepsText) steps of \(targetText), \(percent) percent"
        )
    }

    private var ticks: some View {
        let fillColor = progressColor
        return GeometryReader { geo in
            Canvas { context, size in
                let tickWidth = Layout.tickWidth
                let gap = Layout.tickGap
                let count = max(8, Int((size.width + gap) / (tickWidth + gap)))
                let totalTickWidth = CGFloat(count) * tickWidth
                let spacing = count > 1 ? (size.width - totalTickWidth) / CGFloat(count - 1) : 0
                let y = (size.height - Layout.tickHeight) / 2
                let filled = filledTickCount(count)

                for index in 0..<count {
                    let x = CGFloat(index) * (tickWidth + spacing)
                    let rect = CGRect(x: x, y: y, width: tickWidth, height: Layout.tickHeight)
                    let path = Path(
                        roundedRect: rect,
                        cornerSize: CGSize(width: tickWidth / 2, height: tickWidth / 2),
                        style: .continuous
                    )
                    context.fill(
                        path,
                        with: .color(index < filled ? fillColor : inactiveTick)
                    )
                }
            }
            .animation(.easeInOut(duration: 0.35), value: percent)
        }
    }

    private func filledTickCount(_ total: Int) -> Int {
        guard percent > 0, total > 0 else { return 0 }
        let raw = Int((Double(total) * Double(percent) / 100.0).rounded(.down))
        return min(total, max(1, raw))
    }

    private enum Layout {
        static let height: CGFloat = 52
        static let cornerRadius: CGFloat = 18
        static let tickHeight: CGFloat = 14
        static let tickWidth: CGFloat = 2.75
        static let tickGap: CGFloat = 2.75
        static let cardDark = Color(red: 46 / 255, green: 48 / 255, blue: 55 / 255)
        static let tickIdleDark = Color(red: 59 / 255, green: 60 / 255, blue: 67 / 255)
    }
}
