import SwiftUI

/// Évite de relancer les animations draw à chaque retour sur le profil.
enum ProfileChartAnimationGate {
    static var hasPlayedProfileIntro = false
}

// MARK: - Carte métrique (style WHOOP / Bevel)

enum ProfileMetricChartLayout {
    static let cardRadius: CGFloat = 28
    static let cardPadding: CGFloat = 18
    static let chartHeight: CGFloat = 132
    static let wellRadius: CGFloat = 18
    static let wellPaddingH: CGFloat = 10
    static let wellPaddingV: CGFloat = 12

    static func chartWellFill(isDark: Bool) -> Color {
        isDark ? Color.black.opacity(0.68) : Color.black.opacity(0.14)
    }

    static func chartWellStroke(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.08)
    }
}

struct ProfileMetricChartSection: View, Equatable {
    let metric: ProfileChartMetric
    let points: [ProfileAnalyticsPoint]
    let latestValue: Double?
    let deltaVsPrevious: Double?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.metric == rhs.metric
            && lhs.points == rhs.points
            && lhs.latestValue == rhs.latestValue
            && lhs.deltaVsPrevious == rhs.deltaVsPrevious
    }

    var body: some View {
        ProfileMetricChartSectionContent(
            metric: metric,
            points: points,
            latestValue: latestValue,
            deltaVsPrevious: deltaVsPrevious
        )
    }
}

private struct ProfileMetricChartSectionContent: View {
    @Environment(\.appTheme) private var theme

    let metric: ProfileChartMetric
    let points: [ProfileAnalyticsPoint]
    let latestValue: Double?
    let deltaVsPrevious: Double?

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ProfileMetricChartLayout.cardRadius, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(metric.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.secondaryText)

            chartWell
        }
        .padding(ProfileMetricChartLayout.cardPadding)
        .background { cardBackground }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
    }

    @ViewBuilder
    private var chartWell: some View {
        VStack(alignment: .leading, spacing: 10) {
            scoreRow

            if points.isEmpty {
                Text(latestValue != nil ? metric.emptySinglePointMessage : metric.emptyNoDataMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: ProfileMetricChartLayout.chartHeight, alignment: .center)
            } else {
                ProfileMetricChartRenderer(
                    points: points,
                    metric: metric,
                    theme: theme,
                    style: metric.visualStyle(pointCount: points.count)
                )
                .frame(height: ProfileMetricChartLayout.chartHeight)
                .drawingGroup()
            }

            if showsComparisonCaption {
                footerCaption
            }
        }
        .padding(.horizontal, ProfileMetricChartLayout.wellPaddingH)
        .padding(.vertical, ProfileMetricChartLayout.wellPaddingV)
        .background(chartWellBackground)
    }

    private var scoreRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let latestValue {
                let formatted = metric.formattedChartValue(latestValue)
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

            Spacer(minLength: 8)

            if let zone = metric.wellnessZone(for: latestValue) {
                ProfileChartStatusBadge(zone: zone)
            }
        }
    }

    private var showsComparisonCaption: Bool {
        deltaVsPrevious != nil
    }

    @ViewBuilder
    private var footerCaption: some View {
        ProfileMetricComparisonLabel(
            metric: metric,
            deltaVsPrevious: deltaVsPrevious,
            theme: theme
        )
        .font(.system(size: 12))
        .foregroundStyle(theme.secondaryText)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var cardBackground: some View {
        cardShape
            .fill(.clear)
            .processGlassEffect(in: cardShape, interactive: false)
    }

    private var chartWellBackground: some View {
        RoundedRectangle(cornerRadius: ProfileMetricChartLayout.wellRadius, style: .continuous)
            .fill(ProfileMetricChartLayout.chartWellFill(isDark: theme.isDark))
            .overlay {
                RoundedRectangle(cornerRadius: ProfileMetricChartLayout.wellRadius, style: .continuous)
                    .strokeBorder(ProfileMetricChartLayout.chartWellStroke(isDark: theme.isDark), lineWidth: 0.5)
            }
    }
}

private struct ProfileChartStatusBadge: View {
    let zone: FaceScanIndicators.WellnessZone

    var body: some View {
        Text(zone.profileBadgeLabel)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(.black.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(zone.profileBadgeColor, in: Capsule(style: .continuous))
    }
}

// MARK: - Router graphiques

struct ProfileMetricChartRenderer: View {
    let points: [ProfileAnalyticsPoint]
    let metric: ProfileChartMetric
    let theme: AppTheme
    let style: ProfileChartVisualStyle

    var body: some View {
        switch style {
        case .splineGlow:
            ProfileMetricSplineChart(points: points, metric: metric, theme: theme)
        case .lineArea:
            ProfileMetricLineAreaChart(points: points, metric: metric, theme: theme)
        case .barTrend:
            ProfileMetricBarTrendChart(points: points, metric: metric, theme: theme)
        case .dashedLine:
            ProfileMetricDashedLineChart(points: points, metric: metric, theme: theme)
        }
    }
}

// MARK: - Shared chart helpers

private enum ProfileMetricChartAxis {
    @MainActor
    static var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }

    @MainActor
    static func xLabels(for points: [ProfileAnalyticsPoint], maxLabels: Int = 7) -> [String] {
        guard !points.isEmpty else { return [] }
        if points.count <= maxLabels {
            return points.map {
                weekdayFormatter
                    .string(from: $0.date)
                    .uppercased()
                    .replacingOccurrences(of: ".", with: "")
            }
        }
        let indices = (0..<maxLabels).map {
            $0 * (points.count - 1) / (maxLabels - 1)
        }
        return indices.map { index in
            weekdayFormatter
                .string(from: points[index].date)
                .uppercased()
                .replacingOccurrences(of: ".", with: "")
        }
    }

    static func normalizedPoints(
        values: [Double],
        range: (min: Double, max: Double),
        in size: CGSize,
        yAxisWidth: CGFloat = 0
    ) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let span = max(range.max - range.min, 0.5)
        let width = max(size.width - yAxisWidth, 1)
        let height = size.height - 18

        return values.enumerated().map { index, value in
            let normalized = (value - range.min) / span
            return CGPoint(
                x: yAxisWidth + (values.count == 1 ? width / 2 : width * CGFloat(index) / CGFloat(values.count - 1)),
                y: height * (1 - CGFloat(normalized))
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

private struct ProfileMetricChartXAxis: View {
    let labels: [String]
    let width: CGFloat
    let height: CGFloat
    let theme: AppTheme

    var body: some View {
        ZStack {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.secondaryText.opacity(0.75))
                    .position(
                        x: width * CGFloat(index) / CGFloat(max(labels.count - 1, 1)),
                        y: height + 10
                    )
            }
        }
        .frame(width: width, height: height + 20)
    }
}

// MARK: - Spline + glow (VFC)

private struct ProfileMetricSplineChart: View {
    let points: [ProfileAnalyticsPoint]
    let metric: ProfileChartMetric
    let theme: AppTheme

    @State private var drawProgress: CGFloat = ProfileChartAnimationGate.hasPlayedProfileIntro ? 1 : 0

    private var values: [Double] { points.map(\.value) }
    private var valueRange: (min: Double, max: Double) {
        metric.axisStyle.defaultRange(for: values)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height - 20
            let color = metric.chartLineColor(theme: theme)
            let cgPoints = ProfileMetricChartAxis.normalizedPoints(
                values: values,
                range: valueRange,
                in: CGSize(width: width, height: height)
            )

            ZStack(alignment: .topLeading) {
                ProfileMetricChartGrid(lineCount: 4, width: width, height: height, theme: theme)

                ProfileAnalyticsAreaShape(values: values, valueMin: valueRange.min, valueMax: valueRange.max)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.34), color.opacity(0.08), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: height)
                    .opacity(drawProgress)

                ProfileAnalyticsLineShape(values: values, valueMin: valueRange.min, valueMax: valueRange.max)
                    .trim(from: 0, to: drawProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: color.opacity(0.65), radius: 6, y: 0)
                    .frame(width: width, height: height)

                ForEach(Array(cgPoints.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .shadow(color: color.opacity(0.8), radius: 4)
                        .position(point)
                        .opacity(drawProgress)
                }

                ProfileMetricChartXAxis(
                    labels: ProfileMetricChartAxis.xLabels(for: points),
                    width: width,
                    height: height,
                    theme: theme
                )
            }
        }
        .onAppear(perform: playIntroIfNeeded)
    }

    private func playIntroIfNeeded() {
        guard !ProfileChartAnimationGate.hasPlayedProfileIntro else {
            drawProgress = 1
            return
        }
        drawProgress = 0
        withAnimation(.easeOut(duration: 0.9)) { drawProgress = 1 }
        ProfileChartAnimationGate.hasPlayedProfileIntro = true
    }
}

// MARK: - Ligne + aire (pas / effort)

private struct ProfileMetricLineAreaChart: View {
    let points: [ProfileAnalyticsPoint]
    let metric: ProfileChartMetric
    let theme: AppTheme

    @State private var drawProgress: CGFloat = ProfileChartAnimationGate.hasPlayedProfileIntro ? 1 : 0

    private var values: [Double] { points.map(\.value) }
    private var valueRange: (min: Double, max: Double) {
        metric.axisStyle.defaultRange(for: values)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height - 20
            let color = metric.chartLineColor(theme: theme)

            ZStack(alignment: .topLeading) {
                ProfileMetricChartGrid(lineCount: 4, width: width, height: height, theme: theme)

                ProfileAnalyticsAreaShape(values: values, valueMin: valueRange.min, valueMax: valueRange.max)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.38), color.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: height)
                    .opacity(drawProgress)

                ProfileAnalyticsLineShape(values: values, valueMin: valueRange.min, valueMax: valueRange.max)
                    .trim(from: 0, to: drawProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: width, height: height)

                ProfileMetricChartXAxis(
                    labels: ProfileMetricChartAxis.xLabels(for: points),
                    width: width,
                    height: height,
                    theme: theme
                )
            }
        }
        .onAppear(perform: playIntroIfNeeded)
    }

    private func playIntroIfNeeded() {
        guard !ProfileChartAnimationGate.hasPlayedProfileIntro else {
            drawProgress = 1
            return
        }
        drawProgress = 0
        withAnimation(.easeOut(duration: 0.85)) { drawProgress = 1 }
        ProfileChartAnimationGate.hasPlayedProfileIntro = true
    }
}

// MARK: - Barres + tendance (régularité)

private struct ProfileMetricBarTrendChart: View {
    let points: [ProfileAnalyticsPoint]
    let metric: ProfileChartMetric
    let theme: AppTheme

    @State private var drawProgress: CGFloat = ProfileChartAnimationGate.hasPlayedProfileIntro ? 1 : 0

    private var values: [Double] { points.map(\.value) }
    private var valueRange: (min: Double, max: Double) {
        metric.axisStyle.defaultRange(for: values)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height - 20
            let color = metric.chartLineColor(theme: theme)
            let cgPoints = ProfileMetricChartAxis.normalizedPoints(
                values: values,
                range: valueRange,
                in: CGSize(width: width, height: height)
            )
            let barWidth = max(6, min(18, width / CGFloat(max(values.count * 2, 1))))

            ZStack(alignment: .topLeading) {
                ProfileMetricChartGrid(lineCount: 5, width: width, height: height, theme: theme)

                ForEach(Array(values.enumerated()), id: \.offset) { index, _ in
                    let span = max(valueRange.max - valueRange.min, 0.5)
                    let normalized = (values[index] - valueRange.min) / span
                    let barHeight = height * CGFloat(normalized) * drawProgress
                    let isLatest = index == values.count - 1
                    let x = cgPoints[index].x

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isLatest ? color : theme.secondaryText.opacity(theme.isDark ? 0.22 : 0.16))
                        .frame(width: barWidth, height: max(barHeight, 4))
                        .position(x: x, y: height - barHeight / 2)
                }

                if cgPoints.count > 1 {
                    Path { path in
                        path.move(to: cgPoints[0])
                        for index in 1..<cgPoints.count {
                            let previous = cgPoints[index - 1]
                            let current = cgPoints[index]
                            let midpoint = (previous.x + current.x) / 2
                            path.addCurve(
                                to: current,
                                control1: CGPoint(x: midpoint, y: previous.y),
                                control2: CGPoint(x: midpoint, y: current.y)
                            )
                        }
                    }
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        theme.primaryText.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 4])
                    )
                }

                if let last = cgPoints.last {
                    Text(metric.axisStyle.formatAxisLabel(values.last ?? 0))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.primaryText.opacity(0.9))
                        .position(x: last.x, y: max(last.y - 12, 8))
                        .opacity(drawProgress)
                }

                ProfileMetricChartXAxis(
                    labels: ProfileMetricChartAxis.xLabels(for: points),
                    width: width,
                    height: height,
                    theme: theme
                )
            }
        }
        .onAppear(perform: playIntroIfNeeded)
    }

    private func playIntroIfNeeded() {
        guard !ProfileChartAnimationGate.hasPlayedProfileIntro else {
            drawProgress = 1
            return
        }
        drawProgress = 0
        withAnimation(.easeOut(duration: 0.9)) { drawProgress = 1 }
        ProfileChartAnimationGate.hasPlayedProfileIntro = true
    }
}

// MARK: - Ligne pointillée (poids)

private struct ProfileMetricDashedLineChart: View {
    let points: [ProfileAnalyticsPoint]
    let metric: ProfileChartMetric
    let theme: AppTheme

    @State private var drawProgress: CGFloat = ProfileChartAnimationGate.hasPlayedProfileIntro ? 1 : 0

    private var values: [Double] { points.map(\.value) }
    private var valueRange: (min: Double, max: Double) {
        metric.axisStyle.defaultRange(for: values)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 36
            let height = geometry.size.height - 20
            let color = metric.chartLineColor(theme: theme)
            let cgPoints = ProfileMetricChartAxis.normalizedPoints(
                values: values,
                range: valueRange,
                in: CGSize(width: width, height: height),
                yAxisWidth: 0
            )

            ZStack(alignment: .topLeading) {
                ProfileMetricChartGrid(lineCount: 4, width: width, height: height, theme: theme)
                    .offset(x: 32)

                ForEach(0..<4, id: \.self) { index in
                    let span = max(valueRange.max - valueRange.min, 0.5)
                    let labelValue = valueRange.max - span * Double(index) / 3.0
                    Text(metric.axisStyle.formatAxisLabel(labelValue))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.secondaryText.opacity(0.7))
                        .position(x: 14, y: height * CGFloat(index) / 3)
                }

                ProfileAnalyticsLineShape(values: values, valueMin: valueRange.min, valueMax: valueRange.max)
                    .trim(from: 0, to: drawProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4]))
                    .frame(width: width, height: height)
                    .offset(x: 32)

                if let last = cgPoints.last {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .position(x: last.x + 32, y: last.y)
                        .opacity(drawProgress)
                }

                ProfileMetricChartXAxis(
                    labels: ProfileMetricChartAxis.xLabels(for: points),
                    width: width,
                    height: height,
                    theme: theme
                )
                .offset(x: 32)
            }
        }
        .onAppear(perform: playIntroIfNeeded)
    }

    private func playIntroIfNeeded() {
        guard !ProfileChartAnimationGate.hasPlayedProfileIntro else {
            drawProgress = 1
            return
        }
        drawProgress = 0
        withAnimation(.easeOut(duration: 0.85)) { drawProgress = 1 }
        ProfileChartAnimationGate.hasPlayedProfileIntro = true
    }
}

// MARK: - Légende évolution

struct ProfileMetricComparisonLabel: View {
    let metric: ProfileChartMetric
    let deltaVsPrevious: Double?
    let theme: AppTheme

    private var deltaThreshold: Double { metric.deltaThreshold }

    var body: some View {
        if let deltaVsPrevious, abs(deltaVsPrevious) >= deltaThreshold {
            HStack(spacing: 0) {
                Text(AppCopy.t("Évolution : ", en: "Change: "))
                Text(metric.axisStyle.formatDelta(deltaVsPrevious))
                    .foregroundStyle(deltaColor(deltaVsPrevious))
                    .fontWeight(.bold)
                Text(AppCopy.t(" vs période précédente.", en: " vs. previous period."))
            }
        } else if deltaVsPrevious != nil {
            Text(AppCopy.t("Stable vs la période précédente.", en: "Stable vs. previous period."))
        }
    }

    private func deltaColor(_ delta: Double) -> Color {
        let isPositive = metric.lowerDeltaIsPositive ? delta <= 0 : delta >= 0
        return isPositive ? ProfilePerformancePalette.peach : ProfilePerformancePalette.blue
    }
}

typealias ProfileWeightSection = ProfileMetricChartSection
typealias ProfileRegularitySection = ProfileMetricChartSection
