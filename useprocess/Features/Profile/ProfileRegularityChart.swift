import SwiftUI

struct ProfileWeightChart: View {
    let points: [ProfileAnalyticsPoint]
    let metric: ProfileChartMetric
    var theme: AppTheme
    var compact: Bool = false

    @State private var drawProgress: CGFloat = 0

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private var values: [Double] {
        points.map(\.value).filter { $0 > 0 }
    }

    private var valueRange: (min: Double, max: Double) {
        metric.axisStyle.defaultRange(for: values)
    }

    var body: some View {
        ProfileWeightChartCanvas(
            values: values,
            valueRange: valueRange,
            axisLabels: axisLabels,
            metric: metric,
            theme: theme,
            compact: compact,
            drawProgress: drawProgress
        )
        .id("\(metric.id)-\(points.map(\.id).joined())")
        .onAppear(perform: animateChart)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.axisStyle.accessibilityLabel)
    }

    private func animateChart() {
        drawProgress = 0
        withAnimation(.easeInOut(duration: 0.85)) {
            drawProgress = 1
        }
    }

    private var axisLabels: [String] {
        guard !points.isEmpty else { return ["—", "—", "—", "—"] }
        let indices = [0, points.count / 3, points.count * 2 / 3, points.count - 1]
        return indices.map {
            Self.weekdayFormatter
                .string(from: points[min($0, points.count - 1)].date)
                .capitalized
        }
    }
}

private struct ProfileWeightChartCanvas: View {
    let values: [Double]
    let valueRange: (min: Double, max: Double)
    let axisLabels: [String]
    let metric: ProfileChartMetric
    let theme: AppTheme
    let compact: Bool
    let drawProgress: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ProfileWeightChartLayers(
                size: geometry.size,
                values: values,
                valueRange: valueRange,
                axisLabels: axisLabels,
                metric: metric,
                theme: theme,
                compact: compact,
                drawProgress: drawProgress
            )
        }
    }
}

private struct ProfileWeightChartLayers: View {
    let size: CGSize
    let values: [Double]
    let valueRange: (min: Double, max: Double)
    let axisLabels: [String]
    let metric: ProfileChartMetric
    let theme: AppTheme
    let compact: Bool
    let drawProgress: CGFloat

    private var chartWidth: CGFloat {
        max(size.width - yAxisWidth, 1)
    }

    private var chartHeight: CGFloat {
        max(size.height - xAxisHeight, 1)
    }

    private var yAxisWidth: CGFloat { compact ? 32 : 44 }
    private var xAxisHeight: CGFloat { compact ? 6 : 22 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ProfileWeightChartGrid(
                gridLines: compact ? 2 : 5,
                width: chartWidth,
                height: chartHeight,
                valueRange: valueRange,
                axisStyle: metric.axisStyle,
                theme: theme,
                compact: compact
            )
            if metric.showsChartArea {
                ProfileWeightChartArea(
                    values: values,
                    valueRange: valueRange,
                    width: chartWidth,
                    height: chartHeight,
                    metric: metric,
                    theme: theme,
                    drawProgress: drawProgress
                )
            }
            ProfileWeightChartLine(
                values: values,
                valueRange: valueRange,
                width: chartWidth,
                height: chartHeight,
                metric: metric,
                theme: theme,
                compact: compact,
                drawProgress: drawProgress
            )
            if values.count == 1 {
                ProfileWeightChartPointMarker(
                    value: values[0],
                    valueRange: valueRange,
                    width: chartWidth,
                    height: chartHeight,
                    metric: metric,
                    theme: theme
                )
            }
            ProfileWeightChartXAxis(
                labels: axisLabels,
                width: chartWidth,
                height: chartHeight,
                theme: theme,
                compact: compact
            )
        }
    }
}

private struct ProfileWeightChartGrid: View {
    let gridLines: Int
    let width: CGFloat
    let height: CGFloat
    let valueRange: (min: Double, max: Double)
    let axisStyle: ProfileChartAxisStyle
    let theme: AppTheme
    let compact: Bool

    var body: some View {
        ForEach(0..<gridLines, id: \.self) { index in
            ProfileWeightGridLine(
                index: index,
                gridLines: gridLines,
                width: width,
                height: height,
                valueRange: valueRange,
                axisStyle: axisStyle,
                theme: theme,
                compact: compact
            )
        }
    }
}

private struct ProfileWeightChartArea: View {
    let values: [Double]
    let valueRange: (min: Double, max: Double)
    let width: CGFloat
    let height: CGFloat
    let metric: ProfileChartMetric
    let theme: AppTheme
    let drawProgress: CGFloat

    var body: some View {
        ProfileAnalyticsAreaShape(values: values, valueMin: valueRange.min, valueMax: valueRange.max)
            .fill(metric.chartAreaGradient(theme: theme))
            .frame(width: width, height: height)
            .opacity(drawProgress)
    }
}

private struct ProfileWeightChartLine: View {
    let values: [Double]
    let valueRange: (min: Double, max: Double)
    let width: CGFloat
    let height: CGFloat
    let metric: ProfileChartMetric
    let theme: AppTheme
    let compact: Bool
    let drawProgress: CGFloat

    var body: some View {
        ProfileAnalyticsLineShape(values: values, valueMin: valueRange.min, valueMax: valueRange.max)
            .trim(from: 0, to: drawProgress)
            .stroke(
                metric.chartLineIsDashed ? AnyShapeStyle(metric.chartLineColor(theme: theme)) : AnyShapeStyle(metric.chartLineGradient(theme: theme)),
                style: StrokeStyle(
                    lineWidth: compact ? 2 : 2.5,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: metric.chartLineIsDashed ? [6, 4] : []
                )
            )
            .frame(width: width, height: height)
    }
}

private struct ProfileWeightChartPointMarker: View {
    let value: Double
    let valueRange: (min: Double, max: Double)
    let width: CGFloat
    let height: CGFloat
    let metric: ProfileChartMetric
    let theme: AppTheme

    var body: some View {
        let span = max(valueRange.max - valueRange.min, 0.5)
        let normalized = (value - valueRange.min) / span
        let y = height * (1 - CGFloat(normalized))

        Circle()
            .fill(metric.chartLineColor(theme: theme))
            .frame(width: 7, height: 7)
            .position(x: width / 2, y: y)
            .frame(width: width, height: height)
    }
}

private struct ProfileWeightChartXAxis: View {
    let labels: [String]
    let width: CGFloat
    let height: CGFloat
    let theme: AppTheme
    let compact: Bool

    private var axisBottom: CGFloat { compact ? 4 : 14 }

    var body: some View {
        ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
            Text(label)
                .font(.system(size: compact ? 9 : 10, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .position(
                    x: width * CGFloat(index) / CGFloat(max(labels.count - 1, 1)),
                    y: height + axisBottom
                )
        }
        .frame(width: width, height: height + axisBottom + 2)
    }
}

private struct ProfileWeightGridLine: View {
    let index: Int
    let gridLines: Int
    let width: CGFloat
    let height: CGFloat
    let valueRange: (min: Double, max: Double)
    let axisStyle: ProfileChartAxisStyle
    let theme: AppTheme
    let compact: Bool

    private var y: CGFloat {
        height * CGFloat(index) / CGFloat(max(gridLines - 1, 1))
    }

    private var showsLabel: Bool {
        !compact || index.isMultiple(of: 2)
    }

    private var labelValue: Double {
        let span = max(valueRange.max - valueRange.min, 0.5)
        let step = span / Double(max(gridLines - 1, 1))
        return valueRange.max - step * Double(index)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(theme.cardStroke.opacity(theme.isDark ? 0.35 : 0.5), lineWidth: 0.5)

            if showsLabel {
                Text(axisStyle.formatAxisLabel(labelValue))
                    .font(.system(size: compact ? 9 : 10, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .offset(x: width + 4, y: y - 6)
            }
        }
    }
}

struct ProfileAnalyticsLineShape: Shape {
    let values: [Double]
    var valueMin: Double?
    var valueMax: Double?

    func path(in rect: CGRect) -> Path {
        smoothPath(in: rect, closesToBottom: false)
    }

    func smoothPath(in rect: CGRect, closesToBottom: Bool) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }

        let minV = valueMin ?? values.min() ?? 0
        let maxV = valueMax ?? values.max() ?? 100
        let range = max(maxV - minV, 0.5)

        let points = values.enumerated().map { index, value in
            let normalized = (value - minV) / range
            return CGPoint(
                x: values.count == 1 ? rect.midX : rect.width * CGFloat(index) / CGFloat(values.count - 1),
                y: rect.height * (1 - CGFloat(normalized))
            )
        }

        if closesToBottom {
            path.move(to: CGPoint(x: points[0].x, y: rect.maxY))
            path.addLine(to: points[0])
        } else {
            path.move(to: points[0])
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = (previous.x + current.x) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: midpoint, y: previous.y),
                control2: CGPoint(x: midpoint, y: current.y)
            )
        }

        if closesToBottom, let last = points.last {
            path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

struct ProfileAnalyticsAreaShape: Shape {
    let values: [Double]
    var valueMin: Double?
    var valueMax: Double?

    func path(in rect: CGRect) -> Path {
        ProfileAnalyticsLineShape(values: values, valueMin: valueMin, valueMax: valueMax)
            .smoothPath(in: rect, closesToBottom: true)
    }
}

// Conservé pour compatibilité interne — alias vers le graphique poids.
typealias ProfileRegularityChart = ProfileWeightChart
