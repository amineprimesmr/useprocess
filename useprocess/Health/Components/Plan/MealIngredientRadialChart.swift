import SwiftUI
import UIKit

// MARK: - Graphique radial « fleur » — détail repas

struct MealIngredientRadialChart: View {
    let segments: [MealChartSegment]
    let imageAssetName: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let centerPink = Color(red: 0.96, green: 0.45, blue: 0.86)
    private let petalViolet = Color(red: 0.69, green: 0.64, blue: 0.98)
    private let petalBlue = Color(red: 0.48, green: 0.78, blue: 0.96)
    private let ghostFill = Color.white.opacity(0.96)
    private let labelPrimary = Color(red: 0.06, green: 0.07, blue: 0.09)
    private let labelSecondary = Color(red: 0.14, green: 0.15, blue: 0.19)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            let centerRadius = size * 0.145
            let petalWidth = size * 0.345
            let petalLength = size * 0.405
            let petalAnchorOverlap = size * 0.055
            let labelDistance = centerRadius + petalLength * 0.74
            let count = max(segments.count, 1)
            let step = 360.0 / Double(count)

            ZStack {
                centerGlow(radius: centerRadius)

                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    petalLayer(
                        segment: segment,
                        index: index,
                        step: step,
                        centerRadius: centerRadius,
                        petalWidth: petalWidth,
                        petalLength: petalLength,
                        petalAnchorOverlap: petalAnchorOverlap
                    )
                }

                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    let angleRad = (step * Double(index) - 90) * .pi / 180
                    label(for: segment)
                        .frame(width: petalWidth * 1.05)
                        .position(
                            x: center.x + cos(angleRad) * labelDistance,
                            y: center.y + sin(angleRad) * labelDistance
                        )
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.92)
                        .animation(
                            .easeOut(duration: 0.42).delay(labelDelay(for: index)),
                            value: appeared
                        )
                }

                centerPhoto(radius: centerRadius)
                    .position(center)
                    .scaleEffect(appeared ? 1 : 0.78)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.74, dampingFraction: 0.76).delay(0.06), value: appeared)
            }
        }
        .frame(height: 356)
        .padding(.horizontal, 0)
        .onAppear { triggerAppearance() }
    }

    // MARK: - Pétale

    @ViewBuilder
    private func petalLayer(
        segment: MealChartSegment,
        index: Int,
        step: Double,
        centerRadius: CGFloat,
        petalWidth: CGFloat,
        petalLength: CGFloat,
        petalAnchorOverlap: CGFloat
    ) -> some View {
        let rotation = step * Double(index)
        let offsetY = -(centerRadius + petalLength / 2 - petalAnchorOverlap)

        ZStack {
            FlowerPetalShape()
                .fill(ghostFill)
                .scaleEffect(x: 1.10, y: 1.13, anchor: .bottom)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)

            FlowerPetalShape()
                .fill(
                    RadialGradient(
                        colors: [
                            centerPink.opacity(0.78),
                            petalViolet.opacity(0.92),
                            petalBlue
                        ],
                        center: .bottom,
                        startRadius: 2,
                        endRadius: petalLength * 0.86
                    )
                )
        }
        .frame(width: petalWidth, height: petalLength)
        .offset(y: offsetY)
        .rotationEffect(.degrees(rotation))
        .scaleEffect(appeared ? visualScale(for: segment) : 0.58, anchor: .bottom)
        .opacity(appeared ? 1 : 0)
        .animation(petalSpring.delay(petalDelay(for: index)), value: appeared)
    }

    // MARK: - Centre

    @ViewBuilder
    private func centerGlow(radius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        centerPink.opacity(0.42),
                        centerPink.opacity(0.20),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: radius * 1.55
                )
            )
            .frame(width: radius * 2.8, height: radius * 2.8)
            .blur(radius: 8)
    }

    @ViewBuilder
    private func centerPhoto(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: radius * 2 + 16, height: radius * 2 + 16)
                .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 7)

            Circle()
                .strokeBorder(Color.white, lineWidth: 5)
                .frame(width: radius * 2 + 6, height: radius * 2 + 6)

            OptionalAssetImage(
                name: imageAssetName,
                contentMode: .fill,
                width: radius * 2,
                height: radius * 2,
                foregroundStyle: Color.secondary
            )
            .clipShape(Circle())
        }
    }

    // MARK: - Labels

    private func label(for segment: MealChartSegment) -> some View {
        VStack(spacing: 2) {
            Text(segment.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(labelPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .multilineTextAlignment(.center)
            Text("\(Int(segment.percentage.rounded()))%")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(labelSecondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Animation

    private var petalSpring: Animation {
        .spring(response: 0.82, dampingFraction: 0.78)
    }

    private func visualScale(for segment: MealChartSegment) -> CGFloat {
        let normalized = CGFloat(max(0, min(segment.percentage, 45)) / 45)
        return 0.82 + normalized * 0.18
    }

    private func petalDelay(for index: Int) -> Double {
        0.03 + Double(index) * 0.065
    }

    private func labelDelay(for index: Int) -> Double {
        0.32 + Double(index) * 0.045
    }

    private func triggerAppearance() {
        if reduceMotion {
            appeared = true
            return
        }
        appeared = false
        DispatchQueue.main.async { appeared = true }
    }
}

// MARK: - Forme pétale

private struct FlowerPetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        let midX = rect.midX
        let topY = rect.minY + rect.height * 0.03
        let bottomY = rect.maxY
        let topHalf = rect.width * 0.40
        let waistHalf = rect.width * 0.50
        let baseHalf = rect.width * 0.08

        var path = Path()
        path.move(to: CGPoint(x: midX - baseHalf, y: bottomY))
        path.addCurve(
            to: CGPoint(x: midX - topHalf, y: topY + rect.height * 0.24),
            control1: CGPoint(x: midX - waistHalf, y: bottomY - rect.height * 0.38),
            control2: CGPoint(x: midX - waistHalf, y: topY + rect.height * 0.12)
        )
        path.addQuadCurve(
            to: CGPoint(x: midX + topHalf, y: topY + rect.height * 0.24),
            control: CGPoint(x: midX, y: topY - rect.height * 0.09)
        )
        path.addCurve(
            to: CGPoint(x: midX + baseHalf, y: bottomY),
            control1: CGPoint(x: midX + waistHalf, y: topY + rect.height * 0.12),
            control2: CGPoint(x: midX + waistHalf, y: bottomY - rect.height * 0.38)
        )
        path.closeSubpath()
        return path
    }
}
