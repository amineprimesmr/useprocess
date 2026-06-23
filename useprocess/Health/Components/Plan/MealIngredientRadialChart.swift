import SwiftUI
import UIKit

// MARK: - Graphique radial « fleur » — détail repas (pixel-perfect mockup)

struct MealIngredientRadialChart: View {
    let segments: [MealChartSegment]
    let imageAssetName: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    // Tokens couleurs mockup
    private let innerPink = Color(red: 0.97, green: 0.34, blue: 0.60)
    private let midViolet = Color(red: 0.74, green: 0.56, blue: 0.96)
    private let outerBlue = Color(red: 0.48, green: 0.80, blue: 0.99)
    private let ghostFill = Color.white
    private let ghostStroke = Color(red: 0.90, green: 0.90, blue: 0.92)
    private let labelPrimary = Color(red: 0.10, green: 0.10, blue: 0.12)
    private let labelSecondary = Color(red: 0.42, green: 0.42, blue: 0.46)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            // Proportions calibrées sur la maquette
            let centerRadius = size * 0.168
            let ringGap = size * 0.034
            let petalWidth = size * 0.205
            let maxPetalLength = size * 0.305
            let labelDistance = centerRadius + ringGap + maxPetalLength * 0.90
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
                        ringGap: ringGap,
                        petalWidth: petalWidth,
                        maxPetalLength: maxPetalLength
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
        .frame(height: 372)
        .padding(.horizontal, 4)
        .onAppear { triggerAppearance() }
    }

    // MARK: - Pétale

    @ViewBuilder
    private func petalLayer(
        segment: MealChartSegment,
        index: Int,
        step: Double,
        centerRadius: CGFloat,
        ringGap: CGFloat,
        petalWidth: CGFloat,
        maxPetalLength: CGFloat
    ) -> some View {
        let rotation = step * Double(index)
        let offsetY = -(centerRadius + ringGap + maxPetalLength / 2)

        ZStack {
            FlowerPetalShape(progress: 1)
                .fill(ghostFill)
                .overlay {
                    FlowerPetalShape(progress: 1)
                        .stroke(ghostStroke, lineWidth: 1.2)
                }
                .shadow(color: .black.opacity(0.055), radius: 6, x: 0, y: 3)

            FlowerPetalShape(progress: petalProgress(for: segment))
                .fill(
                    LinearGradient(
                        colors: [innerPink, midViolet, outerBlue],
                        startPoint: UnitPoint(x: 0.5, y: 1.0),
                        endPoint: UnitPoint(x: 0.5, y: 0.0)
                    )
                )
                .clipShape(FlowerPetalShape(progress: 1))
        }
        .frame(width: petalWidth, height: maxPetalLength)
        .offset(y: offsetY)
        .rotationEffect(.degrees(rotation))
        .animation(petalSpring.delay(petalDelay(for: index)), value: appeared)
    }

    // MARK: - Centre

    @ViewBuilder
    private func centerGlow(radius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        innerPink.opacity(0.38),
                        innerPink.opacity(0.14),
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
                .frame(width: radius * 2 + 8, height: radius * 2 + 8)
                .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)

            Circle()
                .strokeBorder(Color.white, lineWidth: 3.5)
                .frame(width: radius * 2, height: radius * 2)

            OptionalAssetImage(
                name: imageAssetName,
                contentMode: .fill,
                width: radius * 2 - 1,
                height: radius * 2 - 1,
                foregroundStyle: Color.secondary
            )
            .clipShape(Circle())
        }
    }

    // MARK: - Labels

    private func label(for segment: MealChartSegment) -> some View {
        VStack(spacing: 2) {
            Text(segment.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(labelPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
            Text("\(Int(segment.percentage.rounded()))%")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(labelSecondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Animation

    private var petalSpring: Animation {
        .spring(response: 0.92, dampingFraction: 0.74)
    }

    private func petalProgress(for segment: MealChartSegment) -> CGFloat {
        let target = CGFloat(max(0.035, min(segment.percentage, 100) / 100))
        return appeared ? target : 0.015
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

// MARK: - Forme pétale (maquette)

private struct FlowerPetalShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let height = rect.height * max(0.015, min(progress, 1))
        let midX = rect.midX
        let baseY = rect.maxY
        let tipY = baseY - height

        // Base étroite, ventre large, capuchon arrondi (comme maquette)
        let baseHalf = rect.width * 0.065
        let maxHalf = rect.width * 0.495
        let bulgeY = baseY - height * 0.62
        let capControl = height * 0.18

        var path = Path()
        path.move(to: CGPoint(x: midX - baseHalf, y: baseY))

        path.addCurve(
            to: CGPoint(x: midX, y: tipY),
            control1: CGPoint(x: midX - maxHalf, y: bulgeY),
            control2: CGPoint(x: midX - maxHalf * 0.22, y: tipY + capControl)
        )

        path.addCurve(
            to: CGPoint(x: midX + baseHalf, y: baseY),
            control1: CGPoint(x: midX + maxHalf * 0.22, y: tipY + capControl),
            control2: CGPoint(x: midX + maxHalf, y: bulgeY)
        )

        path.closeSubpath()
        return path
    }
}
