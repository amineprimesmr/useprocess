//
//  FaceIDScanUI.swift
//  Process
//
//  UI scan visage — morph carré → cercle, ticks Face ID, vague cyan.
//

import SwiftUI

enum FaceIDScanColors {
    static let activeTick = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let inactiveTick = Color(white: 0.24)
    static let scanWave = Color(red: 0.35, green: 0.92, blue: 1.0)
    static let continueFill = Color(red: 0.13, green: 0.98, blue: 0.47)
}

enum FaceScanCaptureOverlayMode: Equatable {
    case orbitTicks
    case tiltHold
}

enum FaceScanTiltDirection: Equatable {
    case none
    case left
    case right
    /// Premier penché — les deux côtés sont acceptés.
    case either
}

// MARK: - Forme morph carré arrondi → cercle

enum FaceScanViewportMetrics {
    static let roundedCornerRadius: CGFloat = 30
    /// Débordement de l’anneau de ticks autour du cercle caméra (gap + trait actif, par côté × 2).
    static let tickRingOverflow: CGFloat = 42
    /// Scan onboarding — masque tête (plus haut que large, un peu plus long qu’une ellipse).
    static let onboardingOvalAspect: CGFloat = 1.36
    static let onboardingTickOverflow: CGFloat = 108
}

enum FaceScanViewportStyle: Equatable {
    case morphingRoundedSquare
    case onboardingFaceOval
}

nonisolated struct FaceMorphClipShape: InsettableShape {
    var morph: CGFloat
    var style: FaceScanViewportStyle = .morphingRoundedSquare
    private var insetAmount: CGFloat = 0

    init(morph: CGFloat, style: FaceScanViewportStyle = .morphingRoundedSquare) {
        self.morph = morph
        self.style = style
    }

    var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    func path(in rect: CGRect) -> Path {
        morphPath(in: rect, inset: insetAmount)
    }

    func inset(by amount: CGFloat) -> FaceMorphClipShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    private func morphPath(in rect: CGRect, inset: CGFloat) -> Path {
        guard rect.width.isFinite, rect.height.isFinite, rect.width > 0, rect.height > 0 else {
            return Path()
        }
        let adjusted = rect.insetBy(dx: inset, dy: inset)
        guard adjusted.width > 0, adjusted.height > 0 else { return Path() }

        switch style {
        case .onboardingFaceOval:
            return FaceScanOnboardingOvalShape().path(in: adjusted)
        case .morphingRoundedSquare:
            let maxRadius = min(adjusted.width, adjusted.height) / 2
            let safeMorph = morph.isFinite ? min(1, max(0, morph)) : 0
            let cornerRadius = FaceScanViewportMetrics.roundedCornerRadius
                + (maxRadius - FaceScanViewportMetrics.roundedCornerRadius) * safeMorph
            return RoundedRectangle(cornerRadius: max(0, cornerRadius), style: .continuous).path(in: adjusted)
        }
    }
}

/// Masque visage onboarding — front large, menton plus étroit (pas une ellipse).
nonisolated struct FaceScanOnboardingOvalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 96
        for i in 0..<steps {
            let angle = Double(i) / Double(steps) * 2 * .pi
            let point = Self.contourPoint(in: rect, parametricAngle: angle)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    /// Point du contour pour un angle visuel (0 = droite, π/2 = bas, π = gauche, −π/2 = haut).
    /// Rayon depuis le centre — même repère que `FaceIDTickProgressRing`.
    static func rimPoint(in rect: CGRect, angle: Double) -> CGPoint {
        let path = FaceScanOnboardingOvalShape().path(in: rect)
        let dx = CGFloat(cos(angle))
        let dy = CGFloat(sin(angle))
        var lo: CGFloat = 0
        var hi = max(rect.width, rect.height)
        for _ in 0..<18 {
            let mid = (lo + hi) / 2
            let sample = CGPoint(x: rect.midX + dx * mid, y: rect.midY + dy * mid)
            if path.contains(sample) {
                lo = mid
            } else {
                hi = mid
            }
        }
        let radius = (lo + hi) / 2
        return CGPoint(x: rect.midX + dx * radius, y: rect.midY + dy * radius)
    }

    static func outwardNormal(in rect: CGRect, at angle: Double) -> CGVector {
        CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
    }

    /// Superellipse : front un peu plus large, joues, menton plus étroit — silhouette tête.
    private static func contourPoint(in rect: CGRect, parametricAngle: Double) -> CGPoint {
        let rx = rect.width / 2
        let ry = rect.height / 2
        let cosine = cos(parametricAngle)
        let sine = sin(parametricAngle)
        let exponent = 2.0 / 2.34
        let ax = CGFloat(copysign(pow(abs(cosine), exponent), cosine))
        let ay = CGFloat(copysign(pow(abs(sine), exponent), sine))
        let bottom = CGFloat(max(0, sine))
        let top = CGFloat(max(0, -sine))
        let foreheadWiden: CGFloat = 0.09
        let cheekRound: CGFloat = 0.04
        let chinTaper: CGFloat = 0.30
        let widthScale = 1
            + foreheadWiden * pow(top, 1.12)
            + cheekRound * pow(1 - abs(sine), 2.2)
            - chinTaper * pow(bottom, 1.45)
        let yShift = ry * 0.018 * (top - bottom)
        return CGPoint(
            x: rect.midX + rx * ax * widthScale,
            y: rect.midY + ry * ay + yShift
        )
    }
}

/// Liseré bleu dégradé sur le bord intérieur du masque caméra.
struct FaceScanOnboardingInnerEdgeGlow: View {
    var intensity: CGFloat = 1

    private let glow = Color(red: 0.46, green: 0.74, blue: 1.0)

    var body: some View {
        let strength = max(0, intensity)
        ZStack {
            FaceScanOnboardingOvalShape()
                .stroke(glow.opacity(0.14 * strength), lineWidth: 28)
                .blur(radius: 12)

            FaceScanOnboardingOvalShape()
                .stroke(glow.opacity(0.16 * strength), lineWidth: 10)
                .blur(radius: 5)

            FaceScanOnboardingOvalShape()
                .stroke(Color(red: 0.62, green: 0.84, blue: 1.0).opacity(0.12 * strength), lineWidth: 3)
                .blur(radius: 1.6)
        }
        .clipShape(FaceScanOnboardingOvalShape())
        .allowsHitTesting(false)
    }
}

// MARK: - Coins du cadre (positionnement — carré arrondi)

struct FaceScanFrameCornerBrackets: View {
    let size: CGFloat
    var armLength: CGFloat = 26
    var inset: CGFloat = 20
    var lineWidth: CGFloat = 2.5
    var color: Color = .white

    var body: some View {
        FaceScanCornerBracketsShape(armLength: armLength, inset: inset)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }
}

private struct FaceScanCornerBracketsShape: Shape {
    var armLength: CGFloat
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let len = armLength
        let i = inset
        let maxX = rect.maxX - inset
        let maxY = rect.maxY - inset

        // Haut-gauche
        path.move(to: CGPoint(x: i, y: i + len))
        path.addLine(to: CGPoint(x: i, y: i))
        path.addLine(to: CGPoint(x: i + len, y: i))

        // Haut-droite
        path.move(to: CGPoint(x: maxX - len, y: i))
        path.addLine(to: CGPoint(x: maxX, y: i))
        path.addLine(to: CGPoint(x: maxX, y: i + len))

        // Bas-droite
        path.move(to: CGPoint(x: maxX, y: maxY - len))
        path.addLine(to: CGPoint(x: maxX, y: maxY))
        path.addLine(to: CGPoint(x: maxX - len, y: maxY))

        // Bas-gauche
        path.move(to: CGPoint(x: i + len, y: maxY))
        path.addLine(to: CGPoint(x: i, y: maxY))
        path.addLine(to: CGPoint(x: i, y: maxY - len))

        return path
    }
}

// MARK: - Viewport (caméra + overlay, clip morph)

struct FaceScannerViewport<Camera: View, Overlay: View>: View {
    let size: CGSize
    var morphToCircle: CGFloat
    var style: FaceScanViewportStyle = .morphingRoundedSquare
    @ViewBuilder let camera: () -> Camera
    @ViewBuilder let overlay: () -> Overlay

    var body: some View {
        let safeWidth = size.width.isFinite ? max(size.width, 1) : 1
        let safeHeight = size.height.isFinite ? max(size.height, 1) : 1
        let safeMorph = morphToCircle.isFinite ? min(1, max(0, morphToCircle)) : 0

        ZStack {
            camera()
                .clipShape(FaceMorphClipShape(morph: safeMorph, style: style))

            overlay()
        }
        .frame(width: safeWidth, height: safeHeight)
    }
}

// MARK: - Anneau de ticks (progression rotation tête — traits à l'extérieur du cercle)

struct FaceIDTickProgressRing: View {
    /// Secteurs réellement visités (comme Face ID — pas un remplissage séquentiel).
    let activeSectors: Set<Int>
    /// Diamètre du cercle caméra ; les traits sont dessinés à l'extérieur.
    let cameraDiameter: CGFloat
    var tickCount: Int = 72
    var isComplete: Bool = false
    var isLightBackdrop: Bool = false

    private let gapFromCircle: CGFloat = 8
    private let activeTickLength: CGFloat = 13
    private let inactiveTickLength: CGFloat = 10
    private let tickWidth: CGFloat = 2.8

    private var cameraRadius: CGFloat { cameraDiameter / 2 }

    private var outerRadius: CGFloat {
        cameraRadius + gapFromCircle + activeTickLength
    }

    private var ringDiameter: CGFloat { outerRadius * 2 }

    private var inactiveTick: Color {
        isLightBackdrop ? Color.black.opacity(0.14) : FaceIDScanColors.inactiveTick
    }

    private var sectorSignature: Int {
        activeSectors.reduce(0) { $0 ^ ($1 &* 31) }
    }

    var body: some View {
        ZStack {
            ForEach(0..<tickCount, id: \.self) { index in
                tickView(for: index)
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .animation(.smooth(duration: 0.28), value: sectorSignature)
        .animation(.smooth(duration: 0.28), value: isComplete)
    }

    @ViewBuilder
    private func tickView(for index: Int) -> some View {
        let isActive = activeSectors.contains(index)
        let length = isActive ? activeTickLength : inactiveTickLength
        let radialOffset = cameraRadius + gapFromCircle + length / 2

        Capsule()
            .fill(isActive ? FaceIDScanColors.activeTick : inactiveTick)
            .frame(width: tickWidth, height: length)
            .shadow(
                color: isActive ? FaceIDScanColors.activeTick.opacity(0.5) : .clear,
                radius: 2.5
            )
            .offset(y: -radialOffset)
            .rotationEffect(.degrees(Double(index) / Double(tickCount) * 360 - 90))
            .animation(.smooth(duration: 0.22), value: isActive)
    }
}

// MARK: - Anneau onboarding — une rangée, vague cyan selon la tête

struct FaceIDOnboardingTickProgressRing: View {
    let activeSectors: Set<Int>
    var waveSector: Int = -1
    let ovalSize: CGSize
    var engineTickCount: Int = 72
    var visualTickCount: Int = 72
    var isComplete: Bool = false
    var isLightBackdrop: Bool = false

    private let gapFromMask: CGFloat = 10
    private let tickLength: CGFloat = 9.6
    private let filledRestExtra: CGFloat = 3.2
    private let peakExtraLength: CGFloat = 8.2
    private let tickWidth: CGFloat = 4.28
    private let filledRestWidth: CGFloat = 0.35
    private let peakExtraWidth: CGFloat = 0.55

    private var ringSize: CGSize {
        let extra = (gapFromMask + tickLength + peakExtraLength) * 2 + 24
        return CGSize(width: ovalSize.width + extra, height: ovalSize.height + extra)
    }

    private var inactiveTick: Color {
        isLightBackdrop ? Color.black.opacity(0.09) : Color.white.opacity(0.18)
    }

    private var filledSignature: Int {
        activeSectors.reduce(0) { $0 ^ ($1 &* 31) }
    }

    var body: some View {
        let ovalFrame = CGRect(
            x: (ringSize.width - ovalSize.width) / 2,
            y: (ringSize.height - ovalSize.height) / 2,
            width: ovalSize.width,
            height: ovalSize.height
        )
        let waveVisual = resolvedWaveVisualIndex()

        ZStack {
            ForEach(0..<visualTickCount, id: \.self) { index in
                let rotationDegrees = Double(index) / Double(visualTickCount) * 360 - 90
                let rotationRadians = rotationDegrees * .pi / 180
                let visualAngle = atan2(-cos(rotationRadians), sin(rotationRadians))
                let rim = FaceScanOnboardingOvalShape.rimPoint(in: ovalFrame, angle: visualAngle)
                let normal = FaceScanOnboardingOvalShape.outwardNormal(in: ovalFrame, at: visualAngle)
                let filled = activeSectors.contains(engineSector(for: index))
                let amount = waveAmount(for: index, waveVisual: waveVisual)
                let length = tickLength + (filled ? filledRestExtra : 0) + peakExtraLength * amount
                let width = tickWidth + (filled ? filledRestWidth : 0) + peakExtraWidth * amount
                let radialCenter = CGPoint(
                    x: rim.x + normal.dx * (gapFromMask + length / 2),
                    y: rim.y + normal.dy * (gapFromMask + length / 2)
                )
                let color = tickColor(amount: amount, filled: filled)

                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: width, height: length)
                    .rotationEffect(.degrees(rotationDegrees))
                    .position(radialCenter)
                    .shadow(
                        color: amount > 0.12 ? FaceIDScanColors.scanWave.opacity(0.10 + 0.42 * amount) : .clear,
                        radius: amount > 0.12 ? (1.4 + 5.5 * amount) : 0
                    )
            }

            if let blob = peakBlob(waveVisual: waveVisual, ovalFrame: ovalFrame) {
                Circle()
                    .fill(FaceIDScanColors.scanWave.opacity(0.16 * blob.amount))
                    .frame(width: 12, height: 12)
                    .blur(radius: 6)
                    .position(blob.point)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: ringSize.width, height: ringSize.height)
        .animation(.easeOut(duration: 0.12), value: filledSignature)
        .animation(nil, value: waveSector)
        .animation(.smooth(duration: 0.26), value: isComplete)
        .allowsHitTesting(false)
    }

    private func engineSector(for visualIndex: Int) -> Int {
        if visualTickCount == engineTickCount {
            return visualIndex % engineTickCount
        }
        return Int((Double(visualIndex) + 0.5) / Double(visualTickCount) * Double(engineTickCount)) % engineTickCount
    }

    private func resolvedWaveVisualIndex() -> Int {
        if isComplete { return 0 }
        let center: Int
        if waveSector >= 0 {
            center = waveSector
        } else if let mean = circularMeanSector() {
            center = mean
        } else {
            return -1
        }
        if visualTickCount == engineTickCount {
            return ((center % visualTickCount) + visualTickCount) % visualTickCount
        }
        return Int((Double(center) + 0.5) / Double(engineTickCount) * Double(visualTickCount)) % visualTickCount
    }

    private func circularMeanSector() -> Int? {
        guard !activeSectors.isEmpty else { return nil }
        var x = 0.0
        var y = 0.0
        for sector in activeSectors {
            let angle = Double(sector) / Double(engineTickCount) * 2 * .pi
            x += cos(angle)
            y += sin(angle)
        }
        let angle = atan2(y, x)
        let normalized = angle < 0 ? angle + 2 * .pi : angle
        return Int(normalized / (2 * .pi) * Double(engineTickCount)) % engineTickCount
    }

    private func waveAmount(for visualIndex: Int, waveVisual: Int) -> CGFloat {
        if isComplete { return 0.55 }
        guard waveVisual >= 0 else { return 0 }

        let distance = circularDistance(visualIndex, waveVisual, visualTickCount)
        let lobe = 9
        guard distance < lobe else { return 0 }

        let t = Double(distance) / Double(lobe)
        return CGFloat(0.5 * (1 + cos(t * .pi)))
    }

    private func circularDistance(_ a: Int, _ b: Int, _ count: Int) -> Int {
        let delta = abs(a - b)
        return min(delta, count - delta)
    }

    private func tickColor(amount: CGFloat, filled: Bool) -> Color {
        if amount <= 0.001 {
            return filled
                ? Color(red: 0.08, green: 0.42, blue: 0.78)
                : inactiveTick
        }
        let t = Double(amount)
        let stops: [(Double, (Double, Double, Double))] = [
            (0.00, (0.16, 0.42, 0.62)),
            (0.28, (0.18, 0.55, 0.82)),
            (0.55, (0.32, 0.72, 0.96)),
            (0.78, (0.52, 0.86, 1.00)),
            (1.00, (0.78, 0.95, 1.00))
        ]
        let (from, to) = adjacentStops(t, in: stops)
        let span = max(to.0 - from.0, 0.0001)
        let local = (t - from.0) / span
        return Color(
            red: from.1.0 + (to.1.0 - from.1.0) * local,
            green: from.1.1 + (to.1.1 - from.1.1) * local,
            blue: from.1.2 + (to.1.2 - from.1.2) * local
        )
    }

    private func adjacentStops(
        _ t: Double,
        in stops: [(Double, (Double, Double, Double))]
    ) -> ((Double, (Double, Double, Double)), (Double, (Double, Double, Double))) {
        for index in 0..<(stops.count - 1) where t <= stops[index + 1].0 {
            return (stops[index], stops[index + 1])
        }
        return (stops[stops.count - 2], stops[stops.count - 1])
    }

    private func peakBlob(waveVisual: Int, ovalFrame: CGRect) -> (point: CGPoint, amount: CGFloat)? {
        guard !isComplete, waveVisual >= 0, !activeSectors.isEmpty else { return nil }
        let amount = waveAmount(for: waveVisual, waveVisual: waveVisual)
        guard amount > 0.35 else { return nil }
        let rotationDegrees = Double(waveVisual) / Double(visualTickCount) * 360 - 90
        let rotationRadians = rotationDegrees * .pi / 180
        let visualAngle = atan2(-cos(rotationRadians), sin(rotationRadians))
        let rim = FaceScanOnboardingOvalShape.rimPoint(in: ovalFrame, angle: visualAngle)
        let normal = FaceScanOnboardingOvalShape.outwardNormal(in: ovalFrame, at: visualAngle)
        let length = tickLength + peakExtraLength * amount
        let point = CGPoint(
            x: rim.x + normal.dx * (gapFromMask + length / 2),
            y: rim.y + normal.dy * (gapFromMask + length / 2)
        )
        return (point, amount)
    }
}

// MARK: - Anneau vert de maintien (penché latéral)

struct FaceIDTiltHoldRing: View {
    var progress: Double
    let cameraDiameter: CGFloat
    var isEngaged: Bool
    var isLightBackdrop: Bool = false

    private let strokeWidth: CGFloat = 5.5
    private let gapFromCircle: CGFloat = 10

    private var ringDiameter: CGFloat {
        cameraDiameter + (gapFromCircle + strokeWidth) * 2
    }

    private var trackColor: Color {
        isLightBackdrop ? Color.black.opacity(0.12) : Color.white.opacity(0.16)
    }

    var body: some View {
        ZStack {
            if isEngaged {
                Circle()
                    .stroke(FaceIDScanColors.activeTick.opacity(0.22), lineWidth: strokeWidth + 8)
                    .frame(width: ringDiameter, height: ringDiameter)
                    .blur(radius: 3)
                    .scaleEffect(1.015)
            }

            Circle()
                .stroke(trackColor, lineWidth: strokeWidth)
                .frame(width: ringDiameter, height: ringDiameter)

            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(
                    FaceIDScanColors.activeTick,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: FaceIDScanColors.activeTick.opacity(isEngaged ? 0.55 : 0.25),
                    radius: isEngaged ? 5 : 2
                )
        }
        .animation(.smooth(duration: 0.34), value: progress)
        .animation(.smooth(duration: 0.28), value: isEngaged)
    }
}

// MARK: - Silhouette d’inclinaison (par-dessus la caméra)

struct FaceScanTiltArrowHint: View {
    let direction: FaceScanTiltDirection
    let cameraDiameter: CGFloat
    var isEngaged: Bool
    var isLightBackdrop: Bool = false

    /// 0 = droit, 1 = penché — joué une seule fois par côté.
    @State private var tiltAmount: CGFloat = 0
    @State private var demoTask: Task<Void, Never>?

    private let maxTiltDegrees: Double = 32

    private var accentColor: Color {
        if isEngaged { return FaceIDScanColors.activeTick.opacity(0.9) }
        return isLightBackdrop ? Color.black.opacity(0.85) : Color.white.opacity(0.92)
    }

    private var silhouetteSize: CGFloat {
        cameraDiameter * 0.70
    }

    /// Gauche d’abord (`.either` / `.left`), puis droite.
    private var tiltSign: Double {
        switch direction {
        case .left, .either: return -1
        case .right: return 1
        case .none: return 0
        }
    }

    private var currentRotation: Double {
        Double(tiltAmount) * maxTiltDegrees * tiltSign
    }

    var body: some View {
        Group {
            if direction != .none {
                Image("face_tilt_silhouette")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(accentColor)
                    .frame(width: silhouetteSize, height: silhouetteSize)
                    .rotationEffect(.degrees(currentRotation))
                    .shadow(
                        color: (isLightBackdrop ? Color.white : Color.black).opacity(0.3),
                        radius: 5,
                        y: 1
                    )
                    .opacity(isEngaged ? 0.28 : 0.85)
                    .allowsHitTesting(false)
                    .accessibilityLabel(OnboardingCopy.t("Penche la tête comme la silhouette", en: "Tilt your head like the silhouette"))
            }
        }
        // Même taille que le cercle caméra — centré par-dessus, sans décaler la page.
        .frame(width: cameraDiameter, height: cameraDiameter)
        .onAppear { playTiltDemoOnce() }
        .onChange(of: direction) { _, _ in playTiltDemoOnce() }
        .onDisappear {
            demoTask?.cancel()
            demoTask = nil
        }
    }

    /// Droit → penche une fois, puis reste penché (pas de boucle).
    private func playTiltDemoOnce() {
        demoTask?.cancel()
        demoTask = nil
        tiltAmount = 0
        guard direction != .none else { return }

        demoTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.85)) {
                tiltAmount = 1
            }
        }
    }
}

// MARK: - Anneau vert succès

struct FaceIDSuccessRing: View {
    let diameter: CGFloat
    @State private var scale: CGFloat = 0.94

    var body: some View {
        Circle()
            .stroke(FaceIDScanColors.activeTick, lineWidth: 3)
            .frame(width: diameter, height: diameter)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    scale = 1
                }
            }
    }
}

// MARK: - Hint

struct FaceIDFrameHint: View {
    let text: String
    var isLightBackdrop: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isLightBackdrop ? Color.black.opacity(0.75) : OnboardingTheme.primaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isLightBackdrop ? Color.black.opacity(0.06) : Color.clear)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .environment(\.colorScheme, isLightBackdrop ? .light : .dark)
    }
}

// MARK: - Continuer

struct FaceIDContinueButton: View {
    var title: String = OnboardingCopy.continueCTA
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(FaceIDScanColors.continueFill, in: Capsule())
        }
        .buttonStyle(.processPlain)
        .contentShape(Capsule())
        .highPriorityGesture(
            TapGesture().onEnded {
                action()
            }
        )
    }
}
