//
//  OnboardingEstimationGraphView.swift
//  Process
//
//  Graphique partagé pour les deux écrans d'estimation.
//

import SwiftUI

struct OnboardingEstimationGraphView: View {
    let projectedDate: Date
    let context: OnboardingEstimationContext
    let curveAnimationProgress: Double
    let useAcceleratedCurve: Bool

    private var curveData: [(date: Date, value: Double)] {
        GoalProjectionService.shared.generateProgressCurveData(
            startDate: Date(),
            endDate: projectedDate,
            currentValue: context.graphCurrentValue,
            targetValue: context.graphTargetValue,
            isWeightGoal: context.hasWeightGoal,
            weightGoal: context.weightGoal
        )
    }

    var body: some View {
        let screenWidth = ScreenMetrics.width - 80
        let calendar = Calendar.current
        let finalCountdownDays = max(
            0,
            calendar.dateComponents([.day], from: Date(), to: projectedDate).day ?? 0
        )

        VStack(spacing: 0) {
            GeometryReader { graphGeometry in
                let width = graphGeometry.size.width > 0 ? graphGeometry.size.width : screenWidth
                let height: CGFloat = 200
                let simplifiedData = simplifiedCurveData(useAcceleratedCurve: useAcceleratedCurve)
                let points = calculateSimpleSmoothPoints(
                    data: simplifiedData,
                    width: width,
                    height: height,
                    isAscending: context.graphIsAscending
                )

                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(OnboardingTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(OnboardingTheme.cardBorder, lineWidth: 1)
                        )

                    VStack {
                        HStack {
                            Text("Ta progression")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(OnboardingTheme.primaryText.opacity(0.85))
                                .padding(.leading, 8)
                                .padding(.top, 12)

                            Spacer()

                            HStack(spacing: 4) {
                                Text("Dans")
                                Text("\(finalCountdownDays)")
                                    .fontWeight(.bold)
                                Text(finalCountdownDays <= 1 ? "jour" : "jours")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(OnboardingTheme.bodyText)
                            .padding(.trailing, 8)
                            .padding(.top, 12)
                        }
                        Spacer()
                    }

                    Path { path in
                        for i in 1...3 {
                            let y = height * CGFloat(i) / 4
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(OnboardingTheme.mutedFill, lineWidth: 1)

                    if !points.isEmpty {
                        fillPath(points: points, height: height)
                        strokePath(points: points, lineWidth: 5, color: OnboardingTheme.graphTooltip, yOffset: 2, blur: 3)
                        strokePath(
                            points: points,
                            lineWidth: 5,
                            gradient: [
                                Color(red: 0.77, green: 0.64, blue: 0.97),
                                Color(red: 0.6, green: 0.4, blue: 0.8),
                                Color(red: 0.42, green: 0.05, blue: 0.51)
                            ]
                        )
                        strokePath(points: points, lineWidth: 1, color: OnboardingTheme.softBorder, yOffset: -2)

                        if curveAnimationProgress >= 1.0, let lastPoint = points.last {
                            Circle()
                                .fill(OnboardingTheme.primaryText)
                                .frame(width: 12, height: 12)
                                .position(lastPoint)
                        }
                    }
                }
            }
            .frame(height: 200)

            HStack {
                Text("Aujourd'hui")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingTheme.footnoteText)
                    .padding(.leading, 4)
                Spacer()
                Text(formatMonth(projectedDate))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingTheme.footnoteText)
                    .padding(.trailing, 20)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }

    private func simplifiedCurveData(useAcceleratedCurve: Bool) -> [Double] {
        let current = context.graphCurrentValue
        let target = context.graphTargetValue
        let minValue = min(current, target)
        let maxValue = max(current, target)
        let valueRange = max(maxValue - minValue, 0.1)

        var baseData: [Double]
        if curveData.count <= 6 {
            baseData = curveData.map { ($0.value - minValue) / valueRange }
        } else {
            let step = max(1, curveData.count / 6)
            baseData = Array(stride(from: 0, to: curveData.count, by: step).prefix(6)).map { index in
                (curveData[index].value - minValue) / valueRange
            }
        }

        guard useAcceleratedCurve, baseData.count >= 2 else { return baseData }

        let targetValue = context.graphIsAscending ? 1.0 : 0.0
        var accelerated = baseData
        let secondLastIndex = accelerated.count - 2
        accelerated[secondLastIndex] = baseData[secondLastIndex] + (targetValue - baseData[secondLastIndex]) * 0.95
        accelerated[accelerated.count - 1] = targetValue
        return accelerated
    }

    @ViewBuilder
    private func fillPath(points: [CGPoint], height: CGFloat) -> some View {
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
        .mask(
            GeometryReader { maskGeometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(OnboardingTheme.primaryText)
                        .frame(width: maskGeometry.size.width * curveAnimationProgress)
                    Spacer()
                }
            }
        )
    }

    @ViewBuilder
    private func strokePath(
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
                let prev = points[index - 1]
                let prevPoint = CGPoint(x: prev.x, y: prev.y + yOffset)
                let control1 = CGPoint(x: prevPoint.x + (point.x - prevPoint.x) / 3, y: prevPoint.y)
                let control2 = CGPoint(x: point.x - (point.x - prevPoint.x) / 3, y: point.y)
                path.addCurve(to: point, control1: control1, control2: control2)
            }
        }
    }

    private func calculateSimpleSmoothPoints(
        data: [Double],
        width: CGFloat,
        height: CGFloat,
        isAscending: Bool
    ) -> [CGPoint] {
        guard !data.isEmpty else { return [] }

        let stepWidth = width / CGFloat(max(1, data.count - 1))
        var points: [CGPoint] = []

        for (index, _) in data.enumerated() {
            let x = index == 0 ? 0 : CGFloat(index) * stepWidth
            let normalizedValue = data.count > 1 ? Double(index) / Double(data.count - 1) : 0
            let adjusted = isAscending ? (1.0 - normalizedValue) : normalizedValue
            let baseY = (CGFloat(adjusted) * height * 0.75) + (height * 0.20)
            let variationFactor = sin(adjusted * .pi)
            let seed = Double(index) * 0.314159
            let variation = CGFloat(sin(seed) * cos(seed * 2.5)) * 25 * CGFloat(variationFactor)
            let y = min(height * 0.95, max(height * 0.20, baseY + variation))
            points.append(CGPoint(x: x, y: y))
        }

        return points
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date).capitalized
    }
}
