import SwiftUI

// MARK: - Public card

struct ReadinessScoreGaugeView: View {
    let score: Int
    let label: String
    let subtitle: String
    var showsDetails: Bool = false
    var isLoadingDetails: Bool = false
    var onDetails: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                ReadinessGaugeCanvas(
                    score: score,
                    isDark: isDark
                )
                .frame(height: ReadinessGaugeMetrics.canvasHeight)
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 10)

                gaugeLabels
                    .padding(.bottom, ReadinessGaugeMetrics.labelsBottomInset)
            }
            .frame(maxWidth: .infinity)
            .frame(height: ReadinessGaugeMetrics.totalHeight)

            if showsDetails, let onDetails {
                detailsButton(action: onDetails)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ReadinessGaugeMetrics.cardRadius, style: .continuous))
        .shadow(
            color: .black.opacity(isDark ? 0.35 : 0.07),
            radius: isDark ? 18 : 22,
            x: 0,
            y: isDark ? 10 : 12
        )
        .overlay {
            RoundedRectangle(cornerRadius: ReadinessGaugeMetrics.cardRadius, style: .continuous)
                .strokeBorder(
                    isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04),
                    lineWidth: 0.5
                )
        }
    }

    private var gaugeLabels: some View {
        VStack(spacing: ReadinessGaugeMetrics.labelSpacing) {
            Text(displayScore)
                .font(.system(size: ReadinessGaugeMetrics.scoreFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
                .minimumScaleFactor(0.85)
                .accessibilityLabel("Score readiness \(displayScore)")

            Text(displayLabel)
                .font(.system(size: ReadinessGaugeMetrics.statusFontSize, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: ReadinessGaugeMetrics.subtitleFontSize, weight: .regular))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
        }
    }

    private var displayScore: String {
        score > 0 ? "\(score)" : "—"
    }

    private var displayLabel: String {
        ReadinessGaugeCopy.displayStatusLabel(score: score, label: label)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if isDark {
            RoundedRectangle(cornerRadius: ReadinessGaugeMetrics.cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.14, blue: 0.16),
                            Color(red: 0.10, green: 0.10, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: ReadinessGaugeMetrics.cardRadius, style: .continuous)
                .fill(Color.white)
        }
    }

    @ViewBuilder
    private func detailsButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(isLoadingDetails ? "Analyse…" : "Comprendre mon score")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.onboardingAccent)
        }
        .buttonStyle(.plain)
        .disabled(isLoadingDetails)
    }
}

// MARK: - Copy helpers

enum ReadinessGaugeCopy {
    static func displayStatusLabel(score: Int, label: String) -> String {
        guard score > 0 else { return "En attente de données" }
        switch score {
        case 80...: return "Pic de forme"
        case 60..<80: return "État stable"
        case 40..<60: return "Récupération modérée"
        default: return "Priorité repos"
        }
    }

    static func subtitle(score: Int, factor: String?) -> String {
        if let factor, !factor.isEmpty {
            return factor
        }
        return defaultSubtitle(for: score)
    }

    static func defaultSubtitle(for score: Int) -> String {
        switch score {
        case 80...: return "Continue — tu es prêt à performer"
        case 60..<80: return "Continue — tu es sur la bonne voie"
        case 40..<60: return "Écoute ton corps aujourd'hui"
        case 1..<40: return "Priorité récupération et repos"
        default: return "Connecte Apple Santé pour calculer ton score"
        }
    }
}

// MARK: - Layout metrics

private enum ReadinessGaugeMetrics {
    static let cardRadius: CGFloat = 28
    static let canvasHeight: CGFloat = 242
    static let totalHeight: CGFloat = 306
    static let labelsBottomInset: CGFloat = 6
    static let labelSpacing: CGFloat = 6
    static let scoreFontSize: CGFloat = 64
    static let statusFontSize: CGFloat = 22
    static let subtitleFontSize: CGFloat = 15
    static let trackWidth: CGFloat = 52
    /// Portion du cercle complet (60 % → arc de 216°).
    static let arcSweepFraction: Double = 0.60
}

// MARK: - Canvas gauge

private struct ReadinessGaugeCanvas: View {
    let score: Int
    let isDark: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: CGFloat {
        CGFloat(min(max(score, 0), 100)) / 100
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                Canvas { context, size in
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    drawGauge(in: &context, size: size, time: time)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private func drawGauge(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let spec = ReadinessGaugeGeometry(size: size)
        let palette = ReadinessGaugePalette(isDark: isDark)
        let clip = spec.effectClipPath

        context.drawLayer { layer in
            layer.clip(to: clip)

            let trackArc = spec.trackArcPath
            let trackStyle = spec.trackStrokeStyle

            layer.stroke(trackArc, with: .color(palette.trackBase), style: trackStyle)
            drawTrackBevel(in: &layer, spec: spec, palette: palette)

            if progress > 0.001 {
                let endTheta = spec.thetaLeft - Double(progress) * spec.totalSweep
                let roundEnd = progress >= 0.999
                let progressPath = spec.progressSectorPath(to: endTheta, roundEnd: roundEnd)
                let gradientStart = spec.point(theta: spec.thetaLeft, radius: spec.centerlineRadius)
                let gradientEnd = spec.point(theta: endTheta, radius: spec.centerlineRadius)

                layer.fill(
                    progressPath,
                    with: .linearGradient(
                        palette.progressLinearGradient,
                        startPoint: gradientStart,
                        endPoint: gradientEnd
                    )
                )

                drawProgressParticles(
                    in: &layer,
                    spec: spec,
                    palette: palette,
                    endTheta: endTheta,
                    progressPath: progressPath,
                    time: time
                )

                drawProgressRelief(in: &layer, spec: spec, palette: palette, endTheta: endTheta)
                if !roundEnd {
                    drawProgressSeparator(in: &layer, spec: spec, palette: palette, endTheta: endTheta)
                }
            }

            drawTickMarks(in: &layer, spec: spec, palette: palette)
        }
    }

    private func drawTrackBevel(
        in context: inout GraphicsContext,
        spec: ReadinessGaugeGeometry,
        palette: ReadinessGaugePalette
    ) {
        let trim = spec.endpointTrim
        let innerR = spec.centerlineRadius - spec.trackWidth * 0.34
        let bevelStart = spec.thetaLeft - trim
        let bevelEnd = spec.thetaRight + trim

        context.stroke(
            spec.openArc(from: bevelStart, to: bevelEnd, radius: innerR),
            with: .linearGradient(
                palette.trackTopShadowGradient,
                startPoint: spec.point(theta: bevelStart, radius: innerR),
                endPoint: spec.point(theta: .pi / 2, radius: innerR)
            ),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .butt, lineJoin: .round)
        )
    }

    private func drawProgressParticles(
        in context: inout GraphicsContext,
        spec: ReadinessGaugeGeometry,
        palette: ReadinessGaugePalette,
        endTheta: Double,
        progressPath: Path,
        time: TimeInterval
    ) {
        let filledSweep = spec.thetaLeft - endTheta
        guard filledSweep > 0.08 else { return }

        let particleCount = max(12, min(34, Int(progress * 38)))
        let margin = spec.endpointTrim * 0.45

        context.drawLayer { layer in
            layer.clip(to: progressPath)

            for index in 0..<particleCount {
                let seed = Double(index) + 1

                let baseT = particleFract(seed * 0.173 + 0.11)
                let arcDrift = sin(time * (0.95 + seed * 0.11) + seed * 2.3) * 0.08
                let t = min(max(baseT + arcDrift, 0.06), 0.94)
                let theta = spec.thetaLeft - t * filledSweep
                guard theta > endTheta + margin else { continue }

                let baseRadial = 0.22 + 0.56 * particleFract(seed * 0.307)
                let radialDrift = sin(time * (1.25 + seed * 0.09) + seed * 1.6) * 0.10
                let radialMix = min(max(baseRadial + radialDrift, 0.14), 0.88)
                let radius = spec.innerRadius + (spec.outerRadius - spec.innerRadius) * radialMix

                let twinkle = 0.55 + 0.45 * sin(time * (1.85 + seed * 0.14) + seed * 1.1)
                let size = CGFloat(2.2 + particleFract(seed * 0.89) * 3.2) * CGFloat(0.78 + twinkle * 0.32)
                let opacity = min(1, (palette.particleOpacityBase + 0.48 * particleFract(seed * 0.641)) * twinkle)

                let center = spec.point(theta: theta, radius: radius)
                let rect = CGRect(
                    x: center.x - size * 0.5,
                    y: center.y - size * 0.5,
                    width: size,
                    height: size
                )
                let specularCenter = CGPoint(
                    x: rect.midX - size * palette.particleSpecularOffset.x,
                    y: rect.midY - size * palette.particleSpecularOffset.y
                )
                layer.opacity = opacity
                layer.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        palette.particleGradient,
                        center: specularCenter,
                        startRadius: 0,
                        endRadius: size * palette.particleSpecularRadius
                    )
                )
                layer.opacity = 1
            }
        }
    }

    private func particleFract(_ value: Double) -> Double {
        value - floor(value)
    }

    private func drawProgressRelief(
        in context: inout GraphicsContext,
        spec: ReadinessGaugeGeometry,
        palette: ReadinessGaugePalette,
        endTheta: Double
    ) {
        let rimRadius = spec.centerlineRadius + spec.trackWidth * 0.30
        let rimStart = spec.thetaLeft - spec.endpointTrim * 0.35
        let rimEnd = endTheta - 0.12

        guard rimEnd > rimStart + 0.05 else { return }

        context.stroke(
            spec.openArc(from: rimStart, to: rimEnd, radius: rimRadius),
            with: .linearGradient(
                palette.specularRimGradient,
                startPoint: spec.point(theta: rimStart, radius: rimRadius),
                endPoint: spec.point(theta: rimEnd, radius: rimRadius)
            ),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .butt, lineJoin: .round)
        )

        // Reflet au sommet de l'arc uniquement — jamais à la limite du score (évite le point lumineux).
        guard endTheta <= .pi / 2, spec.thetaLeft >= .pi / 2 else { return }

        let blobCenter = spec.point(
            theta: .pi / 2,
            radius: spec.centerlineRadius - spec.trackWidth * 0.10
        )
        let blobWidth = spec.trackWidth * 0.36
        let blobHeight = spec.trackWidth * 0.22

        let rect = CGRect(
            x: blobCenter.x - blobWidth * 0.5,
            y: blobCenter.y - blobHeight * 0.42,
            width: blobWidth,
            height: blobHeight
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                palette.progressSpotGradient,
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 0,
                endRadius: max(blobWidth, blobHeight) * 0.38
            )
        )
    }

    private func drawProgressSeparator(
        in context: inout GraphicsContext,
        spec: ReadinessGaugeGeometry,
        palette: ReadinessGaugePalette,
        endTheta: Double
    ) {
        let path = tickLine(
            spec: spec,
            theta: endTheta,
            innerRadius: spec.innerRadius + 1,
            outerRadius: spec.outerRadius - 1
        )
        context.stroke(
            path,
            with: .color(palette.progressSeparator),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .butt)
        )
    }

    private func drawTickMarks(
        in context: inout GraphicsContext,
        spec: ReadinessGaugeGeometry,
        palette: ReadinessGaugePalette
    ) {
        let tickCount = 11
        let tickInset = spec.trackWidth * 0.14
        let tickLength = spec.trackWidth * 0.16
        let inner = spec.innerRadius + tickInset
        let outer = inner + tickLength

        for index in 0...tickCount {
            let t = Double(index) / Double(tickCount)
            let theta = spec.thetaLeft - t * spec.totalSweep

            let path = tickLine(spec: spec, theta: theta, innerRadius: inner, outerRadius: outer)
            context.stroke(
                path,
                with: .color(palette.tick.opacity(0.78)),
                style: StrokeStyle(lineWidth: 0.9, lineCap: .round)
            )
        }
    }

    private func tickLine(
        spec: ReadinessGaugeGeometry,
        theta: Double,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) -> Path {
        var path = Path()
        path.move(to: spec.point(theta: theta, radius: innerRadius))
        path.addLine(to: spec.point(theta: theta, radius: outerRadius))
        return path
    }
}

// MARK: - Geometry

private struct ReadinessGaugeGeometry {
    let size: CGSize
    let center: CGPoint
    let baselineY: CGFloat
    let centerlineRadius: CGFloat
    let trackWidth: CGFloat
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let endpointTrim: Double

    /// Arc de 216° (60 % du cercle), symétrique autour du sommet.
    let totalSweep: Double
    let halfSweep: Double
    let thetaLeft: Double
    let thetaRight: Double

    var trackArcPath: Path {
        openArc(from: thetaLeft, to: thetaRight, radius: centerlineRadius)
    }

    var trackStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: trackWidth, lineCap: .round, lineJoin: .round)
    }

    var progressStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: trackWidth - 1.5, lineCap: .butt, lineJoin: .miter)
    }

    /// Remplissage : cap arrondi au départ (gauche), coupe droite à la limite du score.
    func progressSectorPath(to endTheta: Double, roundEnd: Bool) -> Path {
        annularSectorWithCaps(
            from: thetaLeft,
            to: endTheta,
            roundStart: true,
            roundEnd: roundEnd
        )
    }

    func annularSectorWithCaps(
        from startTheta: Double,
        to endTheta: Double,
        roundStart: Bool,
        roundEnd: Bool
    ) -> Path {
        var path = Path()
        appendArcPoints(to: &path, from: startTheta, to: endTheta, radius: outerRadius, moveToFirst: true)

        if roundEnd {
            appendRoundEndCap(to: &path, at: endTheta, connectsOuterToInner: true)
        } else {
            appendSquareEnd(to: &path, at: endTheta)
        }

        appendArcPoints(to: &path, from: endTheta, to: startTheta, radius: innerRadius, moveToFirst: false)

        if roundStart {
            appendRoundEndCap(to: &path, at: startTheta, connectsOuterToInner: false)
        } else {
            appendSquareEnd(to: &path, at: startTheta)
        }

        path.closeSubpath()
        return path
    }

    private var endCapRadius: CGFloat { trackWidth * 0.5 }

    private func appendArcPoints(
        to path: inout Path,
        from startTheta: Double,
        to endTheta: Double,
        radius: CGFloat,
        moveToFirst: Bool
    ) {
        let steps = max(Int(abs(startTheta - endTheta) / (.pi / 90)), 4)
        for index in 0...steps {
            let t = Double(index) / Double(steps)
            let theta = startTheta + (endTheta - startTheta) * t
            let arcPoint = point(theta: theta, radius: radius)
            if index == 0, moveToFirst {
                path.move(to: arcPoint)
            } else {
                path.addLine(to: arcPoint)
            }
        }
    }

    private func appendSquareEnd(to path: inout Path, at theta: Double) {
        path.addLine(to: point(theta: theta, radius: innerRadius))
    }

    private func appendRoundEndCap(
        to path: inout Path,
        at theta: Double,
        connectsOuterToInner: Bool
    ) {
        let hub = point(theta: theta, radius: centerlineRadius)
        let outer = point(theta: theta, radius: outerRadius)
        let inner = point(theta: theta, radius: innerRadius)
        let outerAngle = Angle(radians: atan2(outer.y - hub.y, outer.x - hub.x))
        let innerAngle = Angle(radians: atan2(inner.y - hub.y, inner.x - hub.x))

        if connectsOuterToInner {
            path.addArc(
                center: hub,
                radius: endCapRadius,
                startAngle: outerAngle,
                endAngle: innerAngle,
                clockwise: theta >= .pi / 2
            )
        } else {
            path.addArc(
                center: hub,
                radius: endCapRadius,
                startAngle: innerAngle,
                endAngle: outerAngle,
                clockwise: theta < .pi / 2
            )
        }
    }

    var effectClipPath: Path {
        var path = annularSector(from: thetaLeft, to: thetaRight)
        let capRadius = trackWidth * 0.5
        for theta in [thetaLeft, thetaRight] {
            let hub = point(theta: theta, radius: centerlineRadius)
            path.addEllipse(in: CGRect(
                x: hub.x - capRadius,
                y: hub.y - capRadius,
                width: capRadius * 2,
                height: capRadius * 2
            ))
        }
        return path
    }

    var trackClipPath: Path {
        effectClipPath
    }

    init(size: CGSize) {
        self.size = size
        trackWidth = ReadinessGaugeMetrics.trackWidth
        totalSweep = 2 * .pi * ReadinessGaugeMetrics.arcSweepFraction
        halfSweep = .pi * ReadinessGaugeMetrics.arcSweepFraction
        thetaLeft = .pi / 2 + halfSweep
        thetaRight = .pi / 2 - halfSweep
        endpointTrim = totalSweep * 0.055

        let horizontalInset: CGFloat = 12
        let usableWidth = max(size.width - horizontalInset * 2, 1)
        centerlineRadius = usableWidth * 0.36
        outerRadius = centerlineRadius + trackWidth * 0.5
        innerRadius = centerlineRadius - trackWidth * 0.5

        let endpointDrop = CGFloat(max(sin(halfSweep - .pi / 2), 0)) * centerlineRadius + trackWidth * 0.5
        let bottomClearance: CGFloat = 14
        baselineY = size.height - bottomClearance - endpointDrop
        center = CGPoint(x: size.width * 0.5, y: baselineY)
    }

    func annularSector(
        from startTheta: Double,
        to endTheta: Double,
        innerRadius innerR: CGFloat? = nil,
        outerRadius outerR: CGFloat? = nil
    ) -> Path {
        let innerValue = innerR ?? innerRadius
        let outerValue = outerR ?? outerRadius
        let steps = max(Int(abs(startTheta - endTheta) / (.pi / 90)), 4)

        var path = Path()
        for index in 0...steps {
            let t = Double(index) / Double(steps)
            let theta = startTheta + (endTheta - startTheta) * t
            let point = point(theta: theta, radius: outerValue)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        for index in stride(from: steps, through: 0, by: -1) {
            let t = Double(index) / Double(steps)
            let theta = startTheta + (endTheta - startTheta) * t
            path.addLine(to: point(theta: theta, radius: innerValue))
        }

        path.closeSubpath()
        return path
    }

    func openArc(from startTheta: Double, to endTheta: Double, radius: CGFloat) -> Path {
        let steps = max(Int(abs(startTheta - endTheta) / (.pi / 90)), 4)
        var path = Path()
        for index in 0...steps {
            let t = Double(index) / Double(steps)
            let theta = startTheta + (endTheta - startTheta) * t
            let point = point(theta: theta, radius: radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    func point(theta: Double, radius: CGFloat? = nil) -> CGPoint {
        let r = radius ?? centerlineRadius
        return CGPoint(
            x: center.x + cos(theta) * r,
            y: baselineY - sin(theta) * r
        )
    }

    /// Point le plus haut (sin max) dans la portion remplie [endTheta … thetaLeft]
    func peakHighlightTheta(endTheta: Double) -> Double {
        let lo = endTheta
        let hi = thetaLeft
        if lo <= .pi / 2, hi >= .pi / 2 { return .pi / 2 }
        return sin(lo) >= sin(hi) ? lo : hi
    }
}

// MARK: - Palette

private struct ReadinessGaugePalette {
    let trackBase: Color
    let outerShadow: Color
    let progressGlow: Color
    let tick: Color
    let needle: Color
    let needleGlow: Color
    let progressSeparator: Color
    let sparkle: Color
    let particleGradient: Gradient
    let particleOpacityBase: Double
    let particleSpecularOffset: CGPoint
    let particleSpecularRadius: CGFloat
    let progressLinearGradient: Gradient
    let progressConicGradient: Gradient
    let trackTopShadowGradient: Gradient
    let trackBottomGlowGradient: Gradient
    let progressSpotGradient: Gradient
    let progressBottomShadowGradient: Gradient
    let specularRimGradient: Gradient
    let innerRimHighlightGradient: Gradient
    let endpointCapGradient: Gradient

    init(isDark: Bool) {
        let baseBlue = Color(red: 0.66, green: 0.70, blue: 0.97)
        let midBlue = Color(red: 0.60, green: 0.62, blue: 0.96)
        let deepViolet = Color(red: 0.56, green: 0.50, blue: 0.94)

        if isDark {
            trackBase = Color(red: 0.20, green: 0.21, blue: 0.28)
            outerShadow = Color.black.opacity(0.45)
            progressGlow = Color(red: 0.55, green: 0.48, blue: 0.98).opacity(0.38)
            tick = Color.white
            needle = Color.white.opacity(0.85)
            needleGlow = Color.white.opacity(0.35)
            progressSeparator = Color.white.opacity(0.42)
            sparkle = Color.white
            particleOpacityBase = 0.62
            particleSpecularOffset = CGPoint(x: 0.18, y: 0.22)
            particleSpecularRadius = 0.72
            particleGradient = Gradient(stops: [
                .init(color: Color.white.opacity(1.0), location: 0.0),
                .init(color: Color.white.opacity(0.88), location: 0.38),
                .init(color: Color.white.opacity(0.28), location: 1.0)
            ])
            progressConicGradient = Gradient(stops: [
                .init(color: baseBlue.opacity(0.94), location: 0.00),
                .init(color: midBlue.opacity(0.97), location: 0.26),
                .init(color: deepViolet.opacity(0.99), location: 0.54),
                .init(color: midBlue.opacity(0.95), location: 0.80),
                .init(color: baseBlue.opacity(0.92), location: 1.00)
            ])
            progressLinearGradient = Gradient(colors: [
                baseBlue.opacity(0.92),
                midBlue.opacity(0.96),
                deepViolet.opacity(0.98),
                midBlue.opacity(0.94)
            ])
            trackTopShadowGradient = Gradient(colors: [
                Color.black.opacity(0.28),
                Color.black.opacity(0.08),
                Color.clear
            ])
            trackBottomGlowGradient = Gradient(colors: [
                Color.clear,
                Color.white.opacity(0.10),
                Color.white.opacity(0.04)
            ])
            progressSpotGradient = Gradient(stops: [
                .init(color: Color.white.opacity(0.95), location: 0.0),
                .init(color: Color.white.opacity(0.55), location: 0.38),
                .init(color: Color.white.opacity(0.12), location: 0.72),
                .init(color: Color.clear, location: 1.0)
            ])
            progressBottomShadowGradient = Gradient(colors: [
                Color.clear,
                Color.black.opacity(0.22),
                Color.black.opacity(0.35)
            ])
            specularRimGradient = Gradient(stops: [
                .init(color: Color.white.opacity(0.0), location: 0.0),
                .init(color: Color.white.opacity(0.55), location: 0.30),
                .init(color: Color.white.opacity(0.95), location: 0.50),
                .init(color: Color.white.opacity(0.30), location: 0.78),
                .init(color: Color.white.opacity(0.0), location: 1.0)
            ])
            innerRimHighlightGradient = Gradient(colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.18),
                Color.white.opacity(0.0)
            ])
            endpointCapGradient = Gradient(colors: [
                Color.white.opacity(0.12),
                Color.white.opacity(0.28),
                Color.white.opacity(0.12)
            ])
        } else {
            trackBase = Color(red: 0.88, green: 0.89, blue: 0.95)
            outerShadow = Color.black.opacity(0.10)
            progressGlow = Color(red: 0.55, green: 0.48, blue: 0.95).opacity(0.30)
            tick = Color.black
            needle = Color(red: 0.38, green: 0.38, blue: 0.44)
            needleGlow = Color.black.opacity(0.12)
            progressSeparator = Color.black.opacity(0.22)
            sparkle = Color.black
            particleOpacityBase = 0.72
            particleSpecularOffset = CGPoint(x: 0.16, y: 0.20)
            particleSpecularRadius = 0.68
            particleGradient = Gradient(stops: [
                .init(color: Color.white.opacity(0.72), location: 0.0),
                .init(color: Color.black.opacity(0.92), location: 0.34),
                .init(color: Color.black.opacity(0.55), location: 1.0)
            ])
            progressConicGradient = Gradient(stops: [
                .init(color: Color(red: 0.76, green: 0.81, blue: 0.99), location: 0.00),
                .init(color: Color(red: 0.68, green: 0.72, blue: 0.98), location: 0.26),
                .init(color: Color(red: 0.62, green: 0.60, blue: 0.97), location: 0.52),
                .init(color: Color(red: 0.58, green: 0.54, blue: 0.95), location: 0.78),
                .init(color: Color(red: 0.64, green: 0.68, blue: 0.98), location: 1.00)
            ])
            progressLinearGradient = Gradient(colors: [
                Color(red: 0.76, green: 0.81, blue: 0.99),
                Color(red: 0.68, green: 0.72, blue: 0.98),
                Color(red: 0.62, green: 0.60, blue: 0.97),
                Color(red: 0.58, green: 0.54, blue: 0.95)
            ])
            trackTopShadowGradient = Gradient(colors: [
                Color.black.opacity(0.14),
                Color.black.opacity(0.05),
                Color.clear
            ])
            trackBottomGlowGradient = Gradient(colors: [
                Color.clear,
                Color.white.opacity(0.55),
                Color.white.opacity(0.20)
            ])
            progressSpotGradient = Gradient(stops: [
                .init(color: Color.white.opacity(1.0), location: 0.0),
                .init(color: Color.white.opacity(0.62), location: 0.36),
                .init(color: Color.white.opacity(0.16), location: 0.70),
                .init(color: Color.clear, location: 1.0)
            ])
            progressBottomShadowGradient = Gradient(colors: [
                Color.clear,
                Color.black.opacity(0.10),
                Color.black.opacity(0.18)
            ])
            specularRimGradient = Gradient(stops: [
                .init(color: Color.white.opacity(0.0), location: 0.0),
                .init(color: Color.white.opacity(0.62), location: 0.28),
                .init(color: Color.white.opacity(1.0), location: 0.50),
                .init(color: Color.white.opacity(0.38), location: 0.76),
                .init(color: Color.white.opacity(0.0), location: 1.0)
            ])
            innerRimHighlightGradient = Gradient(colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.35),
                Color.white.opacity(0.0)
            ])
            endpointCapGradient = Gradient(colors: [
                Color.black.opacity(0.06),
                Color.black.opacity(0.14),
                Color.black.opacity(0.06)
            ])
        }
    }
}

#Preview("Readiness Gauge") {
    VStack(spacing: 20) {
        ReadinessScoreGaugeView(
            score: 48,
            label: "Récupération modérée",
            subtitle: "Écoute ton corps aujourd'hui",
            showsDetails: true,
            onDetails: {}
        )
        .padding(.horizontal, 16)

        ReadinessScoreGaugeView(
            score: 84,
            label: "Prêt à performer",
            subtitle: "Sommeil dans ta norme",
            showsDetails: false
        )
        .padding(.horizontal, 16)
    }
    .padding(.vertical, 24)
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
