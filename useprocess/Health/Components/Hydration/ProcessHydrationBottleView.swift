import SwiftUI

/// Gourde Process — remplissage eau synchronisé + inclinaison gyroscope.
struct ProcessHydrationBottleView: View {
    var fillLevel: CGFloat
    var goalWatermarkLabel: String? = nil
    var goalWatermarkFontSize: CGFloat = 64
    var showsGlassWater: Bool = true

    @Environment(\.appTheme) private var theme
    @StateObject private var waterEngine = ProcessFluidWaterMotionEngine()

    private static let bottleAsset = "hydration_bottle"

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let bodyRect = ProcessHydrationBottleMetrics.bodyRect(in: size)
            let bodyMask = ProcessHydrationBottleBodyMaskShape(bodyRect: bodyRect)

            ZStack {
                bottleOverlay(size: size)
                bottleInteriorLayer(size: size, bodyRect: bodyRect, bodyMask: bodyMask)
            }
            .frame(width: size.width, height: size.height)
        }
        .aspectRatio(ProcessHydrationBottleMetrics.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { waterEngine.start() }
        .onDisappear { waterEngine.stop() }
        .onChange(of: fillLevel) { oldValue, newValue in
            let delta = newValue - oldValue
            guard delta > 0.008 else { return }
            if delta > 0.035 {
                waterEngine.celebratePour()
            } else {
                waterEngine.bumpWave()
            }
        }
    }

    @ViewBuilder
    private func bottleInteriorLayer(
        size: CGSize,
        bodyRect: CGRect,
        bodyMask: ProcessHydrationBottleBodyMaskShape
    ) -> some View {
        ZStack {
            if let goalWatermarkLabel {
                Text(goalWatermarkLabel)
                    .font(.system(size: goalWatermarkFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(watermarkColor)
                    .monospacedDigit()
                    .offset(y: size.height * 0.05)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            growingWaterGlassLayer(in: size, bodyRect: bodyRect)
        }
        .frame(width: size.width, height: size.height)
        .mask(bodyMask)
        .allowsHitTesting(false)
    }

    private var watermarkColor: Color {
        theme.isDark
            ? Color.white.opacity(0.48)
            : Color.white.opacity(0.78)
    }

    @ViewBuilder
    private func growingWaterGlassLayer(in size: CGSize, bodyRect: CGRect) -> some View {
        let shape = ProcessHydrationBottleWaterFillShape(
            fillLevel: fillLevel,
            bodyRect: bodyRect,
            roll: waterEngine.roll,
            pitch: waterEngine.pitch,
            wavePhase: waterEngine.wavePhase
        )

        Group {
            if #available(iOS 26.0, *), showsGlassWater {
                ZStack {
                    GlassEffectContainer {
                        shape
                            .fill(.clear)
                            .glassEffect(ProcessGlass.waterSurface, in: shape)
                    }

                    // Teinte dégradée translucide au-dessus du liquid glass.
                    shape.fill(Self.waterLiquidGradient)
                }
            } else {
                shape.fill(Self.waterLiquidGradient)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.82, dampingFraction: 0.78), value: fillLevel)
        .animation(nil, value: waterEngine.roll)
        .animation(nil, value: waterEngine.pitch)
        .animation(nil, value: waterEngine.wavePhase)
    }

    /// Dégradé goutte — cyan très clair / translucide → cobalt profond.
    private static var waterLiquidGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.55, green: 0.97, blue: 1.00, opacity: 0.28), location: 0),
                .init(color: Color(red: 0.05, green: 0.82, blue: 1.00, opacity: 0.38), location: 0.22),
                .init(color: Color(red: 0.00, green: 0.48, blue: 1.00, opacity: 0.52), location: 0.55),
                .init(color: Color(red: 0.00, green: 0.22, blue: 0.88, opacity: 0.62), location: 0.82),
                .init(color: Color(red: 0.00, green: 0.10, blue: 0.62, opacity: 0.72), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private func bottleOverlay(size: CGSize) -> some View {
        Image(Self.bottleAsset)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

enum ProcessHydrationBottleMetrics {
    /// Asset utilisateur — canvas carré, fichier copié tel quel (sans recadrage).
    static let aspectRatio: CGFloat = 1.0

    /// Zone utile de la gourde dans le PNG carré (pour rogner l’affichage, pas le fichier).
    static let canvasMinX: CGFloat = 0.343
    static let canvasMaxX: CGFloat = 0.658
    static let canvasMinY: CGFloat = 0.004
    static let canvasMaxY: CGFloat = 0.995

    static var contentWidthFraction: CGFloat { canvasMaxX - canvasMinX }
    static var contentHeightFraction: CGFloat { canvasMaxY - canvasMinY }
    static var trimmedAspectRatio: CGFloat { contentWidthFraction / contentHeightFraction }

    static func trimmedLayout(for height: CGFloat) -> (width: CGFloat, squareSide: CGFloat) {
        let squareSide = height / contentHeightFraction
        let width = squareSide * contentWidthFraction
        return (width, squareSide)
    }

    static let bodyMinX: CGFloat = 0.348
    static let bodyMaxX: CGFloat = 0.652
    static let bodyMinY: CGFloat = 0.238
    static let bodyMaxY: CGFloat = 0.978
    /// Légère extension du remplissage vers le haut (plein ≈ épaules).
    static let fillHeightBoost: CGFloat = 0.148
    static let bodyCornerRadiusFraction: CGFloat = 0.24

    static func bodyRect(in size: CGSize) -> CGRect {
        CGRect(
            x: size.width * bodyMinX,
            y: size.height * bodyMinY,
            width: size.width * (bodyMaxX - bodyMinX),
            height: size.height * (bodyMaxY - bodyMinY)
        )
    }

    static func bodyCornerRadius(in bodyRect: CGRect) -> CGFloat {
        bodyRect.width * bodyCornerRadiusFraction
    }
}

/// Masque corps gourde — coins bas arrondis comme le fond de la bouteille.
private struct ProcessHydrationBottleBodyMaskShape: InsettableShape {
    var bodyRect: CGRect
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = bodyRect.insetBy(dx: insetAmount, dy: insetAmount)
        let cornerRadius = max(0, ProcessHydrationBottleMetrics.bodyCornerRadius(in: bodyRect) - insetAmount)
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .path(in: insetRect)
    }

    func inset(by amount: CGFloat) -> ProcessHydrationBottleBodyMaskShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

private struct ProcessHydrationBottleWaterFillShape: Shape {
    var fillLevel: CGFloat
    var bodyRect: CGRect
    var roll: CGFloat
    var pitch: CGFloat
    var wavePhase: CGFloat

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<CGFloat, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(fillLevel, wavePhase),
                AnimatablePair(roll, pitch)
            )
        }
        set {
            fillLevel = newValue.first.first
            wavePhase = newValue.first.second
            roll = newValue.second.first
            pitch = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        guard bodyRect.width > 0, bodyRect.height > 0 else { return Path() }

        let cornerRadius = ProcessHydrationBottleMetrics.bodyCornerRadius(in: bodyRect)
        let clampedFill = min(1, max(0, fillLevel))
        let visibleFill = max(0.05, clampedFill)
        let boostedHeight = bodyRect.height * (1 + ProcessHydrationBottleMetrics.fillHeightBoost)
        let depth = visibleFill * boostedHeight
        let restY = max(bodyRect.minY, bodyRect.maxY - depth)
        let clampedRoll = max(-1, min(1, roll))
        let clampedPitch = max(-1, min(1, pitch))
        let segmentCount = 24

        var points: [CGPoint] = []
        points.reserveCapacity(segmentCount + 1)

        for index in 0...segmentCount {
            let t = CGFloat(index) / CGFloat(segmentCount)
            let x = bodyRect.minX + t * bodyRect.width
            let normalizedX = (t - 0.5) * 2
            let midY = restY - clampedPitch * depth * 0.08
            let slope = -clampedRoll * normalizedX * depth * 0.30
            let wave = CGFloat(sin(Double(wavePhase) + Double(x) * 0.035)) * 1.4
            let y = min(bodyRect.maxY - cornerRadius * 0.12, max(bodyRect.minY + 1, midY + slope + wave))
            points.append(CGPoint(x: x, y: y))
        }

        var path = Path()
        let bottomY = bodyRect.maxY
        let leftX = bodyRect.minX
        let rightX = bodyRect.maxX

        path.move(to: CGPoint(x: leftX + cornerRadius, y: bottomY))
        path.addLine(to: CGPoint(x: rightX - cornerRadius, y: bottomY))
        path.addQuadCurve(
            to: CGPoint(x: rightX, y: bottomY - cornerRadius),
            control: CGPoint(x: rightX, y: bottomY)
        )
        path.addLine(to: CGPoint(x: rightX, y: points.last?.y ?? bottomY))

        for index in stride(from: points.count - 1, through: 0, by: -1) {
            let current = points[index]
            if index == points.count - 1 {
                path.addLine(to: current)
            } else {
                let next = points[index + 1]
                let mid = CGPoint(x: (current.x + next.x) * 0.5, y: (current.y + next.y) * 0.5)
                path.addQuadCurve(to: current, control: mid)
            }
        }

        path.addLine(to: CGPoint(x: leftX, y: points.first?.y ?? bottomY))
        path.addQuadCurve(
            to: CGPoint(x: leftX + cornerRadius, y: bottomY),
            control: CGPoint(x: leftX, y: bottomY)
        )
        path.closeSubpath()
        return path
    }
}
