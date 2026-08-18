//
//  OnboardingEstimationGraphView.swift
//  Process
//
//  Courbe descendante (gonflement → dégonflement) avec jalons intermédiaires.
//

import SwiftUI

struct OnboardingEstimationGraphView: View {
    @Environment(\.colorScheme) private var colorScheme

    let snapshot: OnboardingEstimationGraphSnapshot
    let curveAnimationProgress: Double

    private let graphCornerRadius: CGFloat = 20
    private let topInset: CGFloat = 44
    private let bottomInset: CGFloat = 8

    private var fillGradient: LinearGradient {
        let colors = strokeGradientColors
        return LinearGradient(
            stops: [
                .init(color: colors[0].opacity(0.55), location: 0.0),
                .init(color: colors[1].opacity(0.42), location: 0.4),
                .init(color: colors[2].opacity(0.18), location: 0.72),
                .init(color: Color.clear, location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var strokeGradientColors: [Color] {
        colorScheme == .dark
            ? [
                Color(red: 0.52, green: 0.88, blue: 1.0),
                Color(red: 0.34, green: 0.72, blue: 1.0),
                Color(red: 0.20, green: 0.56, blue: 0.98)
            ]
            : [
                Color(red: 0.28, green: 0.66, blue: 1.0),
                Color(red: 0.14, green: 0.50, blue: 0.96),
                Color(red: 0.08, green: 0.38, blue: 0.90)
            ]
    }

    private var markerBlue: Color {
        strokeGradientColors[1]
    }

    private var endpointDotColor: Color {
        colorScheme == .dark
            ? Color(red: 0.52, green: 0.88, blue: 1.0)
            : Color(red: 0.08, green: 0.38, blue: 0.90)
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { graphGeometry in
                let width = max(1, graphGeometry.size.width)
                let height = max(1, graphGeometry.size.height)
                let plotHeight = max(1, height - topInset - bottomInset)
                let points = Self.makePoints(
                    values: snapshot.descentValues,
                    width: width,
                    plotHeight: plotHeight,
                    topInset: topInset
                )

                ZStack {
                    RoundedRectangle(cornerRadius: graphCornerRadius)
                        .fill(OnboardingTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: graphCornerRadius)
                                .stroke(OnboardingTheme.cardBorder, lineWidth: 1)
                        )

                    chartHeader
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    gridLines(width: width, plotHeight: plotHeight, topInset: topInset)

                    if !points.isEmpty {
                        curveFill(points: points, width: width, height: height)
                        curveStroke(
                            points: points,
                            lineWidth: 5,
                            color: strokeGradientColors[2].opacity(0.35),
                            yOffset: 2,
                            blur: 3
                        )
                        curveStroke(
                            points: points,
                            lineWidth: 4,
                            gradient: strokeGradientColors
                        )

                        if let lastPoint = points.last {
                            Circle()
                                .fill(endpointDotColor)
                                .frame(width: 11, height: 11)
                                .position(lastPoint)
                                .opacity(curveAnimationProgress >= 0.98 ? 1 : 0)
                        }

                        ForEach(snapshot.intermediateMarkers, id: \.id) { milestone in
                            if let markerPoint = Self.pointOnCurve(
                                atFraction: milestone.fraction,
                                points: points
                            ) {
                                intermediateMarker(
                                    milestone: milestone,
                                    at: markerPoint,
                                    width: width,
                                    plotHeight: plotHeight,
                                    topInset: topInset
                                )
                                .opacity(curveAnimationProgress >= milestone.fraction ? 1 : 0)
                            }
                        }
                    }
                }
                .drawingGroup()
            }

            graphDateAxis
        }
        .padding(.horizontal, 40)
        .animation(nil, value: curveAnimationProgress)
    }

    private var chartHeader: some View {
        HStack {
            Text(OnboardingCopy.t("Ta trajectoire", en: "Your trajectory"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText.opacity(0.85))
                .padding(.leading, 12)
                .padding(.top, 12)

            Spacer()

            HStack(spacing: 4) {
                Text(OnboardingCopy.t("Dans", en: "In"))
                Text("\(snapshot.countdownDays)")
                    .fontWeight(.bold)
                Text(snapshot.countdownDays <= 1
                    ? OnboardingCopy.t("jour", en: "day")
                    : OnboardingCopy.t("jours", en: "days"))
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(OnboardingTheme.bodyText)
            .padding(.trailing, 12)
            .padding(.top, 12)
        }
    }

    private var graphDateAxis: some View {
        HStack(alignment: .top, spacing: 0) {
            axisDateLabel(
                caption: OnboardingCopy.t("Aujourd'hui", en: "Today"),
                dateText: formatGraphDate(snapshot.referenceDate),
                alignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            if let middle = snapshot.intermediateMarkers.first {
                axisDateLabel(
                    caption: middle.label,
                    dateText: formatGraphDate(middle.date),
                    alignment: .center
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }

            axisDateLabel(
                caption: OnboardingCopy.t("Objectif", en: "Goal"),
                dateText: formatGraphDate(snapshot.endDate),
                alignment: .trailing
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 40)
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private func axisDateLabel(
        caption: String,
        dateText: String,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(caption)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(OnboardingTheme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(dateText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OnboardingTheme.footnoteText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    @ViewBuilder
    private func gridLines(width: CGFloat, plotHeight: CGFloat, topInset: CGFloat) -> some View {
        Path { path in
            for index in 1...3 {
                let y = topInset + plotHeight * CGFloat(index) / 4
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
        }
        .stroke(OnboardingTheme.mutedFill, lineWidth: 1)
    }

    @ViewBuilder
    private func intermediateMarker(
        milestone: OnboardingGraphMilestone,
        at point: CGPoint,
        width: CGFloat,
        plotHeight: CGFloat,
        topInset: CGFloat
    ) -> some View {
        let markerX = width * CGFloat(milestone.fraction)
        let baselineY = topInset + plotHeight - 4

        ZStack {
            Path { path in
                path.move(to: CGPoint(x: markerX, y: point.y))
                path.addLine(to: CGPoint(x: markerX, y: baselineY))
            }
            .stroke(
                OnboardingTheme.primaryText.opacity(0.16),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )

            Circle()
                .fill(markerBlue)
                .frame(width: 9, height: 9)
                .position(point)

            Text(milestone.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(OnboardingTheme.cardBackground)
                        .overlay(
                            Capsule()
                                .stroke(OnboardingTheme.cardBorder, lineWidth: 1)
                        )
                )
                .position(x: min(max(markerX, 36), width - 36), y: max(topInset + 8, point.y - 18))
        }
    }

    @ViewBuilder
    private func curveFill(points: [CGPoint], width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            let bottomY = height + height * 4.0
            path.move(to: CGPoint(x: 0, y: bottomY))
            if let first = points.first {
                path.addLine(to: first)
            }
            addSmoothCurve(to: &path, points: points)
            if let last = points.last {
                path.addLine(to: CGPoint(x: last.x, y: bottomY))
            }
            path.addLine(to: CGPoint(x: 0, y: bottomY))
            path.closeSubpath()
        }
        .fill(fillGradient)
        .mask(alignment: .leading) {
            Rectangle()
                .frame(width: width * curveAnimationProgress)
        }
    }

    @ViewBuilder
    private func curveStroke(
        points: [CGPoint],
        lineWidth: CGFloat,
        color: Color? = nil,
        gradient: [Color]? = nil,
        yOffset: CGFloat = 0,
        blur: CGFloat = 0
    ) -> some View {
        Path { path in
            addSmoothCurve(to: &path, points: points, yOffset: yOffset)
        }
        .trimmedPath(from: 0, to: curveAnimationProgress)
        .stroke(
            gradient != nil
                ? AnyShapeStyle(LinearGradient(colors: gradient!, startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(color ?? OnboardingTheme.primaryText),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
        .blur(radius: blur)
    }

    /// Courbe lissée — coins arrondis, tout en gardant l'irrégularité des points.
    private func addSmoothCurve(to path: inout Path, points: [CGPoint], yOffset: CGFloat = 0) {
        guard !points.isEmpty else { return }

        let adjusted = points.map { CGPoint(x: $0.x, y: $0.y + yOffset) }
        path.move(to: adjusted[0])

        guard adjusted.count > 1 else { return }

        if adjusted.count == 2 {
            path.addLine(to: adjusted[1])
            return
        }

        for index in 1..<adjusted.count {
            let previous = adjusted[index - 1]
            let current = adjusted[index]
            let span = max(0.001, current.x - previous.x)
            let tension: CGFloat = 0.42

            let dy = current.y - previous.y
            let control1 = CGPoint(
                x: previous.x + span * tension,
                y: previous.y + dy * 0.08
            )
            let control2 = CGPoint(
                x: current.x - span * tension,
                y: current.y - dy * 0.08
            )
            path.addCurve(to: current, control1: control1, control2: control2)
        }
    }

    /// Gonflement en haut, dégonflement en bas.
    private static func makePoints(
        values: [Double],
        width: CGFloat,
        plotHeight: CGFloat,
        topInset: CGFloat
    ) -> [CGPoint] {
        guard !values.isEmpty else { return [] }

        let stepWidth = width / CGFloat(max(1, values.count - 1))
        var points: [CGPoint] = []

        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * stepWidth
            let clamped = min(1, max(0, value))
            let y = topInset + CGFloat(clamped) * plotHeight
            points.append(CGPoint(x: x, y: y))
        }

        return points
    }

    private static func pointOnCurve(atFraction fraction: Double, points: [CGPoint]) -> CGPoint? {
        guard let lastX = points.last?.x, lastX > 0 else { return nil }
        let targetX = lastX * CGFloat(fraction)

        for index in 1..<points.count {
            let current = points[index]
            let previous = points[index - 1]
            if current.x >= targetX {
                let span = max(0.001, current.x - previous.x)
                let t = (targetX - previous.x) / span
                return CGPoint(
                    x: targetX,
                    y: previous.y + (current.y - previous.y) * t
                )
            }
        }

        return points.last
    }

    private func formatGraphDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.currentLocale
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
