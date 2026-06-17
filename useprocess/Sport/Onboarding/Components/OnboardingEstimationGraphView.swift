//
//  OnboardingEstimationGraphView.swift
//  Process
//
//  Courbe de progression vers 100 % du potentiel + jalon poids optionnel.
//

import SwiftUI

struct OnboardingEstimationGraphView: View {
    let snapshot: OnboardingEstimationGraphSnapshot
    let curveAnimationProgress: Double

    private let graphCornerRadius: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { graphGeometry in
                let width = max(1, graphGeometry.size.width)
                let height = max(1, graphGeometry.size.height)
                let points = Self.makePoints(
                    values: snapshot.normalizedValues,
                    width: width,
                    height: height
                )
                let milestonePoint = Self.pointOnCurve(
                    atFraction: OnboardingEstimationContext.weightMilestoneFraction,
                    points: points
                )

                ZStack {
                    RoundedRectangle(cornerRadius: graphCornerRadius)
                        .fill(OnboardingTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: graphCornerRadius)
                                .stroke(OnboardingTheme.cardBorder, lineWidth: 1)
                        )

                    VStack {
                        HStack {
                            Text("Ton potentiel")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(OnboardingTheme.primaryText.opacity(0.85))
                                .padding(.leading, 8)
                                .padding(.top, 12)

                            Spacer()

                            HStack(spacing: 4) {
                                Text("Dans")
                                Text("\(snapshot.countdownDays)")
                                    .fontWeight(.bold)
                                Text(snapshot.countdownDays <= 1 ? "jour" : "jours")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(OnboardingTheme.bodyText)
                            .padding(.trailing, 8)
                            .padding(.top, 12)
                        }
                        Spacer()
                    }

                    gridLines(width: width, height: height)

                    if !points.isEmpty {
                        curveFill(points: points, width: width, height: height)
                        curveStroke(
                            points: points,
                            lineWidth: 5,
                            color: OnboardingTheme.graphTooltip,
                            yOffset: 2,
                            blur: 3
                        )
                        curveStroke(
                            points: points,
                            lineWidth: 5,
                            gradient: [
                                Color(red: 0.77, green: 0.64, blue: 0.97),
                                Color(red: 0.6, green: 0.4, blue: 0.8),
                                Color(red: 0.42, green: 0.05, blue: 0.51)
                            ]
                        )
                        curveStroke(
                            points: points,
                            lineWidth: 1,
                            color: OnboardingTheme.softBorder,
                            yOffset: -2
                        )

                        if let lastPoint = points.last {
                            Circle()
                                .fill(OnboardingTheme.primaryText)
                                .frame(width: 12, height: 12)
                                .position(lastPoint)
                                .opacity(curveAnimationProgress >= 1 ? 1 : 0)
                        }

                        if let label = snapshot.weightMilestoneLabel,
                           let markerPoint = milestonePoint {
                            weightMilestoneMarker(
                                label: label,
                                at: markerPoint,
                                width: width,
                                height: height
                            )
                            .opacity(
                                curveAnimationProgress >= OnboardingEstimationContext.weightMilestoneFraction ? 1 : 0
                            )
                        }
                    }
                }
                .drawingGroup()
            }

            HStack {
                Text("Aujourd'hui")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingTheme.footnoteText)
                    .padding(.leading, 4)
                Spacer()
                Text(formatMonth(snapshot.projectedDate))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingTheme.footnoteText)
                    .padding(.trailing, 20)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
        .animation(nil, value: curveAnimationProgress)
    }

    @ViewBuilder
    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            for index in 1...3 {
                let y = height * CGFloat(index) / 4
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
        }
        .stroke(OnboardingTheme.mutedFill, lineWidth: 1)
    }

    @ViewBuilder
    private func weightMilestoneMarker(
        label: String,
        at point: CGPoint,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let markerX = width * CGFloat(OnboardingEstimationContext.weightMilestoneFraction)

        ZStack {
            Path { path in
                path.move(to: CGPoint(x: markerX, y: point.y))
                path.addLine(to: CGPoint(x: markerX, y: height - 12))
            }
            .stroke(
                OnboardingTheme.primaryText.opacity(0.18),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )

            Circle()
                .fill(Color(red: 0.6, green: 0.4, blue: 0.8))
                .frame(width: 10, height: 10)
                .position(point)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(OnboardingTheme.cardBackground)
                        .overlay(
                            Capsule()
                                .stroke(OnboardingTheme.cardBorder, lineWidth: 1)
                        )
                )
                .position(x: min(max(markerX, 44), width - 44), y: max(18, point.y - 22))
        }
    }

    @ViewBuilder
    private func curveFill(points: [CGPoint], width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            let bottomY = height + height * 8.0
            path.move(to: CGPoint(x: 0, y: bottomY))
            if let first = points.first {
                path.addLine(to: first)
            }
            addCurveSegments(to: &path, points: points)
            if let last = points.last {
                path.addLine(to: CGPoint(x: last.x, y: bottomY))
            }
            path.addLine(to: CGPoint(x: 0, y: bottomY))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.7, green: 0.55, blue: 0.85).opacity(0.7), location: 0.0),
                    .init(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.9), location: 0.4),
                    .init(color: Color(red: 0.4, green: 0.2, blue: 0.6), location: 0.5),
                    .init(color: Color.clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
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
            addCurveSegments(to: &path, points: points, yOffset: yOffset)
        }
        .trimmedPath(from: 0, to: curveAnimationProgress)
        .stroke(
            gradient != nil
                ? AnyShapeStyle(LinearGradient(colors: gradient!, startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(color ?? OnboardingTheme.primaryText),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .square, lineJoin: .round)
        )
        .blur(radius: blur)
    }

    private func addCurveSegments(to path: inout Path, points: [CGPoint], yOffset: CGFloat = 0) {
        for index in 0..<points.count {
            let point = CGPoint(x: points[index].x, y: points[index].y + yOffset)
            if index == 0 {
                path.move(to: point)
            } else {
                let previous = points[index - 1]
                let previousPoint = CGPoint(x: previous.x, y: previous.y + yOffset)
                let control1 = CGPoint(x: previousPoint.x + (point.x - previousPoint.x) / 3, y: previousPoint.y)
                let control2 = CGPoint(x: point.x - (point.x - previousPoint.x) / 3, y: point.y)
                path.addCurve(to: point, control1: control1, control2: control2)
            }
        }
    }

    private static func makePoints(values: [Double], width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard !values.isEmpty else { return [] }

        let stepWidth = width / CGFloat(max(1, values.count - 1))
        var points: [CGPoint] = []

        for (index, value) in values.enumerated() {
            let x = index == 0 ? 0 : CGFloat(index) * stepWidth
            let normalizedValue = min(1, max(0, value))
            let adjusted = 1.0 - normalizedValue
            let baseY = (CGFloat(adjusted) * height * 0.75) + (height * 0.20)
            let variationFactor = sin(normalizedValue * .pi)
            let seed = Double(index) * 0.314159
            let variation = CGFloat(sin(seed) * cos(seed * 2.5)) * 20 * CGFloat(variationFactor)
            let y = min(height * 0.95, max(height * 0.20, baseY + variation))
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

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date).capitalized
    }
}
