//
//  OnboardingComparisonChartView.swift
//  useprocess
//

import SwiftUI

struct OnboardingComparisonChartView: View {
    let regularProgress: CGFloat
    let processProgress: CGFloat
    let endLabel: String
    let isOptimized: Bool

    private let accent = OnboardingEstimationOpalTheme.accent

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { geo in
                let size = geo.size

                ZStack {
                    grid(in: size)

                    processGlow(in: size)

                    regularLine(in: size)
                        .trim(from: 0, to: regularProgress)
                        .stroke(
                            OnboardingEstimationOpalTheme.regularLine,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                        )

                    processLine(in: size, optimized: isOptimized)
                        .trim(from: 0, to: processProgress)
                        .stroke(
                            accent,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: accent.opacity(0.45), radius: 8, y: 2)

                    if regularProgress > 0.55 {
                        chartPill(
                            title: "Sans Process",
                            systemImage: "person.fill",
                            tint: OnboardingEstimationOpalTheme.regularPill,
                            foreground: Color.white.opacity(0.72)
                        )
                        .position(x: size.width * 0.36, y: size.height * 0.24)
                        .opacity(Double(min(1, (regularProgress - 0.55) * 2.5)))
                    }

                    if processProgress > 0.82 {
                        chartPill(
                            title: "Membres Process",
                            systemImage: "sparkles",
                            tint: accent.opacity(0.22),
                            foreground: accent
                        )
                        .position(
                            x: size.width * 0.78,
                            y: processEndY(in: size, optimized: isOptimized) - 28
                        )
                        .opacity(Double(min(1, (processProgress - 0.82) * 5)))
                    }

                    if processProgress >= 1 {
                        Circle()
                            .fill(accent)
                            .frame(width: 34, height: 34)
                            .overlay {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.75))
                            }
                            .position(
                                x: size.width,
                                y: processEndY(in: size, optimized: isOptimized)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(height: 210)

            HStack {
                Text("Aujourd'hui")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.38))

                Spacer()

                Text(endLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Drawing

    private func grid(in size: CGSize) -> some View {
        Path { path in
            for index in 1...3 {
                let y = size.height * CGFloat(index) / 4
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(OnboardingEstimationOpalTheme.gridLine, lineWidth: 1)
    }

    private func regularLine(in size: CGSize) -> Path {
        path(
            through: [
                CGPoint(x: 0, y: size.height * 0.18),
                CGPoint(x: size.width * 0.42, y: size.height * 0.22),
                CGPoint(x: size.width, y: size.height * 0.34)
            ]
        )
    }

    private func processLine(in size: CGSize, optimized: Bool) -> Path {
        let endY = processEndY(in: size, optimized: optimized)
        return path(
            through: [
                CGPoint(x: 0, y: size.height * 0.18),
                CGPoint(x: size.width * 0.34, y: size.height * 0.38),
                CGPoint(x: size.width * 0.72, y: endY * 0.92),
                CGPoint(x: size.width, y: endY)
            ]
        )
    }

    private func processGlow(in size: CGSize) -> some View {
        processLine(in: size, optimized: isOptimized)
            .trim(from: 0, to: processProgress)
            .stroke(
                accent.opacity(0.32),
                style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round)
            )
            .blur(radius: 14)
    }

    private func processEndY(in size: CGSize, optimized: Bool) -> CGFloat {
        size.height * (optimized ? 0.82 : 0.72)
    }

    private func path(through points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let control1 = CGPoint(
                    x: previous.x + (current.x - previous.x) / 3,
                    y: previous.y
                )
                let control2 = CGPoint(
                    x: current.x - (current.x - previous.x) / 3,
                    y: current.y
                )
                path.addCurve(to: current, control1: control1, control2: control2)
            }
        }
    }

    private func chartPill(
        title: String,
        systemImage: String,
        tint: Color,
        foreground: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint, in: Capsule())
    }
}
