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
    static let shellFill = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let meshTint = Color(red: 0.20, green: 0.84, blue: 1.0)
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
}

struct FaceMorphClipShape: InsettableShape {
    var morph: CGFloat
    private var insetAmount: CGFloat = 0

    init(morph: CGFloat) {
        self.morph = morph
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
        let maxRadius = min(adjusted.width, adjusted.height) / 2
        let safeMorph = morph.isFinite ? min(1, max(0, morph)) : 0
        let cornerRadius = FaceScanViewportMetrics.roundedCornerRadius
            + (maxRadius - FaceScanViewportMetrics.roundedCornerRadius) * safeMorph
        return RoundedRectangle(cornerRadius: max(0, cornerRadius), style: .continuous).path(in: adjusted)
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

// MARK: - Shell Dynamic Island → carré (conteneur sombre)

struct FaceDynamicIslandScanner<Camera: View, Overlay: View>: View {
    @Binding var isExpanding: Bool
    var showContent: Bool
    var morphToCircle: CGFloat
    @ViewBuilder let camera: (CGSize) -> Camera
    @ViewBuilder let overlay: (CGSize) -> Overlay

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let safeArea = geo.safeAreaInsets
            let haveDynamicIsland = safeArea.top >= 59
            let dynamicIslandWidth: CGFloat = 120
            let dynamicIslandHeight: CGFloat = 36
            let topOffset: CGFloat = haveDynamicIsland
                ? (11 + max(safeArea.top - 59, 0))
                : safeArea.top
            let expandedWidth = size.width - 30
            let expandedHeight = expandedWidth

            ZStack(alignment: .top) {
                if showContent {
                    shellBackground
                        .overlay {
                            GeometryReader { inner in
                                let cameraSize = inner.size
                                FaceScannerViewport(
                                    size: cameraSize,
                                    morphToCircle: morphToCircle,
                                    camera: { camera(cameraSize) },
                                    overlay: { overlay(cameraSize) }
                                )
                            }
                            .padding(80)
                            .compositingGroup()
                            .blur(radius: isExpanding ? 0 : 15)
                            .opacity(isExpanding ? 1 : 0)
                            .geometryGroup()
                        }
                        .frame(
                            width: isExpanding ? expandedWidth : dynamicIslandWidth,
                            height: isExpanding ? expandedHeight : dynamicIslandHeight
                        )
                        .offset(y: topOffset)
                        .animation(.interpolatingSpring(duration: 0.35, bounce: 0, initialVelocity: 0), value: isExpanding)
                        .animation(.interpolatingSpring(duration: 0.55, bounce: 0.08, initialVelocity: 0), value: morphToCircle)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var shellBackground: some View {
        if #available(iOS 26.0, *) {
            ConcentricRectangle(corners: .concentric(minimum: .fixed(30)), isUniform: true)
                .fill(FaceIDScanColors.shellFill)
        } else {
            RoundedRectangle(cornerRadius: isExpanding ? 30 : 18, style: .continuous)
                .fill(FaceIDScanColors.shellFill)
        }
    }
}

// MARK: - Viewport (caméra + overlay, clip morph)

struct FaceScannerViewport<Camera: View, Overlay: View>: View {
    let size: CGSize
    var morphToCircle: CGFloat
    @ViewBuilder let camera: () -> Camera
    @ViewBuilder let overlay: () -> Overlay

    var body: some View {
        let safeWidth = size.width.isFinite ? max(size.width, 1) : 1
        let safeHeight = size.height.isFinite ? max(size.height, 1) : 1
        let safeMorph = morphToCircle.isFinite ? min(1, max(0, morphToCircle)) : 0

        ZStack {
            camera()
                .clipShape(FaceMorphClipShape(morph: safeMorph))

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

// MARK: - Vague cyan de scan (Face ID)

struct FaceIDScanningWave: View {
    let diameter: CGFloat
    @State private var rotation: Double = 0
    @State private var pulse: CGFloat = 0.88

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            FaceIDScanColors.scanWave.opacity(0),
                            FaceIDScanColors.scanWave.opacity(0.6),
                            FaceIDScanColors.scanWave.opacity(0.12),
                            FaceIDScanColors.scanWave.opacity(0)
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: diameter * 0.94, height: diameter * 0.94)
                .rotationEffect(.degrees(rotation))
                .blur(radius: 1.2)

            FaceIDWaveArc()
                .stroke(
                    LinearGradient(
                        colors: [
                            FaceIDScanColors.scanWave.opacity(0.05),
                            FaceIDScanColors.scanWave.opacity(0.8),
                            FaceIDScanColors.scanWave.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: diameter * 0.8, height: diameter * 0.8)
                .rotationEffect(.degrees(rotation * 0.7))
                .scaleEffect(pulse)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = 1.04
            }
        }
    }
}

private struct FaceIDWaveArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(center: center, radius: radius, startAngle: .degrees(-65), endAngle: .degrees(65), clockwise: false)
        return path
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(OnboardingCopy.continueCTA)
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
