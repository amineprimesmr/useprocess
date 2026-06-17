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

// MARK: - Forme morph carré arrondi → cercle

struct FaceMorphClipShape: Shape {
    var morph: CGFloat

    var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let maxRadius = min(rect.width, rect.height) / 2
        let cornerRadius = 30 + (maxRadius - 30) * morph
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
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
        ZStack {
            camera()
                .clipShape(FaceMorphClipShape(morph: morphToCircle))

            overlay()
        }
        .frame(width: size.width, height: size.height)
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
        .animation(.easeOut(duration: 0.12), value: sectorSignature)
        .animation(.easeOut(duration: 0.12), value: isComplete)
    }

    @ViewBuilder
    private func tickView(for index: Int) -> some View {
        let isActive = isComplete || activeSectors.contains(index)
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
            Text("Continuer")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(FaceIDScanColors.continueFill, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
