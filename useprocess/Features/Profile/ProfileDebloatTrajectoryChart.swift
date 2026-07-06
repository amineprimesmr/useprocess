import SwiftUI

/// Courbe trajectoire debloat — score composite journalier.
struct ProfileDebloatTrajectoryChart: View {
    @Environment(\.appTheme) private var theme

    let points: [DebloatTrajectoryPoint]
    let trend: TrajectoryTrend
    let velocityLabel: String

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ProfileMetricChartLayout.cardRadius, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            chartWell
        }
        .padding(ProfileMetricChartLayout.cardPadding)
        .background { cardBackground }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trajectoire debloat")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.secondaryText)

                if let latest = points.last {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(latest.compositeScore.rounded()))")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.primaryText)
                            .monospacedDigit()
                        Text("/ 100")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Image(systemName: trend.systemImage)
                    .font(.caption.weight(.bold))
                Text(velocityLabel)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(trendColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(trendColor.opacity(0.14), in: Capsule())
        }
    }

    private var trendColor: Color {
        switch trend {
        case .accelerating: return Color(red: 0.35, green: 0.78, blue: 0.45)
        case .stable: return Color(red: 1.0, green: 0.72, blue: 0.28)
        case .regressing: return Color(red: 0.92, green: 0.38, blue: 0.38)
        case .unknown: return theme.secondaryText
        }
    }

    @ViewBuilder
    private var chartWell: some View {
        VStack(alignment: .leading, spacing: 10) {
            if points.isEmpty {
                Text("Valide ton bilan du soir et fais des scans pour construire ta courbe.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: ProfileMetricChartLayout.chartHeight, alignment: .center)
            } else {
                ProfileDebloatTrajectoryChartRenderer(points: points, theme: theme)
                    .frame(height: ProfileMetricChartLayout.chartHeight)
            }

            legendRow
        }
        .padding(.horizontal, ProfileMetricChartLayout.wellPaddingH)
        .padding(.vertical, ProfileMetricChartLayout.wellPaddingV)
        .background(chartWellBackground)
    }

    private var legendRow: some View {
        HStack(spacing: 12) {
            legendDot(color: DebloatDayVerdict.excellent.chartColor, label: "Excellent")
            legendDot(color: DebloatDayVerdict.onTrack.chartColor, label: "OK")
            legendDot(color: DebloatDayVerdict.partial.chartColor, label: "Partiel")
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("Scan")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(theme.secondaryText.opacity(0.8))
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.secondaryText.opacity(0.85))
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = cardShape
        if #available(iOS 26.0, *) {
            shape.fill(.clear).glassEffect(ProcessGlass.regular, in: shape)
        } else {
            shape.fill(.clear).processGlassEffect(in: shape)
        }
    }

    private var chartWellBackground: some View {
        RoundedRectangle(cornerRadius: ProfileMetricChartLayout.wellRadius, style: .continuous)
            .fill(ProfileMetricChartLayout.chartWellFill(isDark: theme.isDark))
            .overlay(
                RoundedRectangle(cornerRadius: ProfileMetricChartLayout.wellRadius, style: .continuous)
                    .strokeBorder(ProfileMetricChartLayout.chartWellStroke(isDark: theme.isDark), lineWidth: 0.5)
            )
    }
}

private struct ProfileDebloatTrajectoryChartRenderer: View {
    let points: [DebloatTrajectoryPoint]
    let theme: AppTheme

    @State private var drawProgress: CGFloat = 0

    private var values: [Double] { points.map(\.compositeScore) }
    private var valueRange: (min: Double, max: Double) {
        let minV = max((values.min() ?? 0) - 8, 0)
        let maxV = min((values.max() ?? 100) + 8, 100)
        return (minV, maxV)
    }

    private var lineColor: Color {
        Color(red: 0.35, green: 0.78, blue: 0.45)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height - 20

            ZStack(alignment: .topLeading) {
                ProfileMetricChartGrid(lineCount: 4, width: width, height: height, theme: theme)

                ProfileAnalyticsAreaShape(values: values, valueMin: valueRange.min, valueMax: valueRange.max)
                    .fill(
                        LinearGradient(
                            colors: [lineColor.opacity(0.34), lineColor.opacity(0.08), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: height)
                    .opacity(drawProgress)

                ProfileAnalyticsLineShape(values: values, valueMin: valueRange.min, valueMax: valueRange.max)
                    .trim(from: 0, to: drawProgress)
                    .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: lineColor.opacity(0.65), radius: 6, y: 0)
                    .frame(width: width, height: height)

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let cgPoints = normalizedChartPoints(width: width, height: height)
                    if cgPoints.indices.contains(index) {
                        ZStack {
                            Circle()
                                .fill(point.verdict.chartColor)
                                .frame(width: 8, height: 8)
                            if point.hasScan {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 5, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(y: -10)
                            }
                        }
                        .position(cgPoints[index])
                        .opacity(drawProgress)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) {
                    drawProgress = 1
                }
            }
        }
    }

    private func normalizedChartPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let span = max(valueRange.max - valueRange.min, 0.5)
        let plotHeight = height - 18
        return values.enumerated().map { index, value in
            let normalized = (value - valueRange.min) / span
            return CGPoint(
                x: values.count == 1 ? width / 2 : width * CGFloat(index) / CGFloat(values.count - 1),
                y: plotHeight * (1 - CGFloat(normalized))
            )
        }
    }
}

private struct ProfileMetricChartGrid: View {
    let lineCount: Int
    let width: CGFloat
    let height: CGFloat
    let theme: AppTheme

    var body: some View {
        ForEach(0..<lineCount, id: \.self) { index in
            let y = height * CGFloat(index) / CGFloat(max(lineCount - 1, 1))
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(theme.secondaryText.opacity(theme.isDark ? 0.14 : 0.18), style: StrokeStyle(lineWidth: 0.5, dash: [4, 5]))
        }
    }
}
