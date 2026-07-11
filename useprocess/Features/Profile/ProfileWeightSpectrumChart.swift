import SwiftUI

enum ProfileWeightSpectrumPalette {
    static let purple = Color(red: 0.482, green: 0.380, blue: 1.0)
    static let tooltipBackground = Color.black
}

enum ProfileWeightSpectrumBuilder {
    static func latestPoints(
        from history: [ProfileAnalyticsPoint],
        limit: Int
    ) -> [ProfileAnalyticsPoint] {
        history
            .filter { $0.value > 0 }
            .sorted { $0.date < $1.date }
            .suffix(max(limit, 1))
            .map { $0 }
    }
}

// MARK: - Graphique

struct ProfileWeightSpectrumChart: View {
    let history: [ProfileAnalyticsPoint]
    var theme: AppTheme

    @State private var revealProgress: CGFloat = 0

    private let chartHeight: CGFloat = 148
    private let visibleSampleCount: Int = 30

    private var points: [ProfileAnalyticsPoint] {
        ProfileWeightSpectrumBuilder.latestPoints(from: history, limit: visibleSampleCount)
    }

    private var latestPoint: ProfileAnalyticsPoint? {
        points.last
    }

    private var valueRange: (min: Double, max: Double) {
        let values = points.map(\.value)
        guard let minV = values.min(), let maxV = values.max() else {
            return (70, 75)
        }
        if minV == maxV {
            return (minV - 0.8, maxV + 0.8)
        }
        let padding = max(0.35, (maxV - minV) * 0.22)
        return (minV - padding, maxV + padding)
    }

    var body: some View {
        chartCanvas
            .frame(height: chartHeight + 44)
            .padding(.top, 4)
            .onAppear {
                revealProgress = 0
                withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
                    revealProgress = 1
                }
            }
            .onChange(of: history) { _, _ in
                revealProgress = 0
                withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
                    revealProgress = 1
                }
            }
    }

    private var chartCanvas: some View {
        GeometryReader { geometry in
            let size = CGSize(width: geometry.size.width, height: chartHeight)
            let chartPoints = normalizedPoints(in: size)

            ZStack(alignment: .bottom) {
                Path { path in
                    for (index, point) in chartPoints.enumerated() {
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                }
                .trim(from: 0, to: revealProgress)
                .stroke(
                    ProfileWeightSpectrumPalette.purple,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .frame(width: geometry.size.width, height: chartHeight)

                if let latestPoint,
                   let latestCGPoint = chartPoints.last {
                    Circle()
                        .fill(ProfileWeightSpectrumPalette.purple)
                        .frame(width: 9, height: 9)
                        .position(
                            x: min(max(latestCGPoint.x, 4.5), max(geometry.size.width - 4.5, 4.5)),
                            y: latestCGPoint.y
                        )
                        .opacity(revealProgress)

                    tooltip(
                        value: latestPoint.value,
                        point: latestCGPoint,
                        canvasWidth: geometry.size.width
                    )
                }
            }
            .frame(width: geometry.size.width, height: chartHeight + 44)
            .allowsHitTesting(false)
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !points.isEmpty, size.width > 0, size.height > 0 else { return [] }

        let span = max(valueRange.max - valueRange.min, 0.5)
        let verticalPadding: CGFloat = 22
        let drawableHeight = max(size.height - verticalPadding * 2, 1)

        if points.count == 1, let value = points.first?.value {
            let y = yPosition(for: value, drawableHeight: drawableHeight, verticalPadding: verticalPadding)
            return [
                CGPoint(x: 0, y: y),
                CGPoint(x: size.width, y: y)
            ]
        }

        return points.enumerated().map { index, point in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1)),
                y: yPosition(
                    for: point.value,
                    drawableHeight: drawableHeight,
                    verticalPadding: verticalPadding,
                    span: span
                )
            )
        }
    }

    private func yPosition(
        for value: Double,
        drawableHeight: CGFloat,
        verticalPadding: CGFloat,
        span: Double? = nil
    ) -> CGFloat {
        let resolvedSpan = span ?? max(valueRange.max - valueRange.min, 0.5)
        let normalized = (value - valueRange.min) / resolvedSpan
        return verticalPadding + drawableHeight * (1 - CGFloat(normalized))
    }

    private func tooltip(
        value: Double,
        point: CGPoint,
        canvasWidth: CGFloat
    ) -> some View {
        let x = min(max(point.x, 48), max(canvasWidth - 48, 48))
        let y = max(20, point.y - 30)

        return VStack(spacing: 0) {
            Text(formattedTooltipValue(value))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(ProfileWeightSpectrumPalette.tooltipBackground)
                )
                .overlay(alignment: .bottom) {
                    TooltipCaret()
                        .fill(ProfileWeightSpectrumPalette.tooltipBackground)
                        .frame(width: 10, height: 5)
                        .offset(y: 4)
                }
        }
        .position(x: x, y: y)
        .opacity(revealProgress)
        .animation(.spring(response: 0.58, dampingFraction: 0.86), value: revealProgress)
        .animation(.spring(response: 0.58, dampingFraction: 0.86), value: history)
    }

    private func formattedTooltipValue(_ value: Double) -> String {
        let text = String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
        return "\(text) kg"
    }

}

private struct TooltipCaret: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Section profil

struct ProfileWeightStatisticsSection: View {
    @Environment(\.appTheme) private var theme

    let history: [ProfileAnalyticsPoint]
    let latestValue: Double?
    let deltaVsPrevious: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBlock

            if history.isEmpty, latestValue == nil {
                Text(ProfileChartMetric.weight.emptyNoDataMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
                    .padding(.horizontal, ProfileTheme.horizontalPadding)
            } else {
                ProfileWeightSpectrumChart(
                    history: effectiveHistory,
                    theme: theme
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Poids")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.secondaryText)

            scoreRow

            if showsComparisonCaption {
                footerCaption
            }
        }
        .padding(.horizontal, ProfileTheme.horizontalPadding)
    }

    private var scoreRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let latestValue {
                let formatted = ProfileChartMetric.weight.formattedChartValue(latestValue)
                Text(formatted.main)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                if !formatted.unit.isEmpty {
                    Text(formatted.unit)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
            } else {
                Text("—")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private var showsComparisonCaption: Bool {
        deltaVsPrevious != nil
    }

    private var effectiveHistory: [ProfileAnalyticsPoint] {
        if !history.isEmpty { return history }
        guard let latestValue else { return [] }
        return [
            ProfileAnalyticsPoint(
                id: "weight-fallback",
                date: Calendar.current.startOfDay(for: Date()),
                value: latestValue
            )
        ]
    }

    @ViewBuilder
    private var footerCaption: some View {
        ProfileMetricComparisonLabel(
            metric: .weight,
            deltaVsPrevious: deltaVsPrevious,
            theme: theme
        )
        .font(.system(size: 12))
        .foregroundStyle(theme.secondaryText)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
}
