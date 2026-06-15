import ARKit
import SwiftUI

/// Écran de capture TrueDepth réutilisable (onboarding + Santé).
struct FaceScanCaptureScreen: View {
    var onBack: () -> Void
    var onContinue: (FaceScanCapturePayload, FaceWellnessMarkers) -> Void

    @State private var scanProgress: Double = 0
    @State private var ringProgress: Double = 0
    @State private var activeTickSectors: Set<Int> = []
    @State private var instruction = "Place ton visage dans le cadre."
    @State private var frameHint: String?
    @State private var isFaceDetected = false
    @State private var isLowLight = false
    @State private var isDeviceSupported = ARFaceTrackingConfiguration.isSupported
    @State private var phase: FaceScanPhase = .positioning
    @State private var scanSessionID = UUID()
    @State private var showContent = false
    @State private var isExpanding = false
    @State private var morphToCircle: CGFloat = 0
    @State private var capturedPayload: FaceScanCapturePayload?
    @State private var capturedMarkers: FaceWellnessMarkers?

    private enum FaceScanPhase {
        case positioning
        case scanning
        case completed
    }

    var body: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            let haveDynamicIsland = safeArea.top >= 59
            let dynamicIslandHeight: CGFloat = 36
            let topOffset: CGFloat = haveDynamicIsland
                ? (11 + max(safeArea.top - 59, 0))
                : safeArea.top
            let expandedHeight = geometry.size.width - 30
            let scannerBottom = topOffset + (isExpanding ? expandedHeight : dynamicIslandHeight)
            let ringDiameter = expandedHeight - 160

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                if phase != .completed {
                    screenFlashOverlay(topOffset: topOffset, expandedHeight: expandedHeight)
                }

                if !isDeviceSupported {
                    unsupportedSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    FaceDynamicIslandScanner(
                        isExpanding: $isExpanding,
                        showContent: showContent,
                        morphToCircle: morphToCircle,
                        camera: { cameraSize in
                            FaceMeshScanView(
                                progress: $scanProgress,
                                ringProgress: $ringProgress,
                                activeTickSectors: $activeTickSectors,
                                instruction: $instruction,
                                frameHint: $frameHint,
                                isFaceDetected: $isFaceDetected,
                                isDeviceSupported: $isDeviceSupported,
                                isLowLight: $isLowLight,
                                onComplete: handleCapture
                            )
                            .id(scanSessionID)
                            .frame(width: cameraSize.width, height: cameraSize.height)
                        },
                        overlay: { cameraSize in
                            scannerOverlay(viewportSize: cameraSize, ringDiameter: ringDiameter)
                        }
                    )
                    .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: scannerBottom + 28)

                    instructionSection

                    if let hint = frameHint, phase != .completed {
                        FaceIDFrameHint(text: hint)
                            .padding(.top, 12)
                    }

                    if isLowLight, phase != .completed {
                        Label("Flash écran", systemImage: "bolt.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .padding(.top, 8)
                    } else if phase != .completed {
                        Label("Éclairage écran", systemImage: "sun.max.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow.opacity(0.85))
                            .padding(.top, 8)
                    }

                    Spacer(minLength: 16)

                    bottomAction
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(safeArea.bottom + 16, 28))
                }

                if phase != .completed {
                    faceScanBackButton
                }
            }
        }
        .onAppear {
            FaceScanScreenFlash.shared.activate(animated: false)
        }
        .onDisappear {
            FaceScanScreenFlash.shared.deactivate()
        }
        .task {
            guard isDeviceSupported else { return }
            showContent = true
            try? await Task.sleep(for: .seconds(0.05))
            isExpanding = true
        }
        .onChange(of: isFaceDetected) { _, detected in
            guard isDeviceSupported, phase != .completed else { return }
            if detected {
                withAnimation(.interpolatingSpring(duration: 0.55, bounce: 0.08, initialVelocity: 0)) {
                    morphToCircle = 1
                }
                if phase == .positioning {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        phase = .scanning
                    }
                }
            } else if phase == .scanning, scanProgress < 0.05 {
                withAnimation(.interpolatingSpring(duration: 0.45, bounce: 0, initialVelocity: 0)) {
                    morphToCircle = 0
                    phase = .positioning
                }
            }
        }
        .onChange(of: scanProgress) { _, value in
            if value >= 1, phase != .completed {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    phase = .completed
                    morphToCircle = 1
                }
            }
        }
    }

    @ViewBuilder
    private func screenFlashOverlay(topOffset: CGFloat, expandedHeight: CGFloat) -> some View {
        let centerY = topOffset + expandedHeight / 2
        ZStack {
            Color.white.opacity(0.18)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.white,
                    Color.white.opacity(0.88),
                    Color.white.opacity(0.35),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: centerY / max(UIScreen.main.bounds.height, 1)),
                startRadius: 20,
                endRadius: expandedHeight * 0.95
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func scannerOverlay(viewportSize: CGSize, ringDiameter: CGFloat) -> some View {
        let ringSize = min(viewportSize.width, viewportSize.height) + 14

        ZStack {
            if morphToCircle > 0.5 {
                switch phase {
                case .positioning, .scanning:
                    FaceIDTickProgressRing(
                        activeSectors: activeTickSectors,
                        diameter: ringSize
                    )
                    if phase == .scanning {
                        FaceIDScanningWave(diameter: min(viewportSize.width, viewportSize.height) * 0.92)
                    }
                case .completed:
                    FaceIDSuccessRing(diameter: ringSize)
                    FaceIDTickProgressRing(
                        activeSectors: activeTickSectors,
                        diameter: ringSize,
                        isComplete: false
                    )
                }
            }
        }
        .opacity(morphToCircle)
        .animation(.easeOut(duration: 0.25), value: morphToCircle)
    }

    private var unsupportedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "faceid")
                .font(.system(size: 52))
                .foregroundStyle(OnboardingTheme.mutedText)
            Text("TrueDepth requis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
            Text("Utilise un iPhone avec Face ID\n(iPhone X ou plus récent).")
                .font(.system(size: 15))
                .foregroundStyle(OnboardingTheme.footnoteText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private var instructionSection: some View {
        Text(instruction)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(OnboardingTheme.primaryText)
            .multilineTextAlignment(phase == .completed ? .trailing : .center)
            .frame(maxWidth: .infinity, alignment: phase == .completed ? .trailing : .center)
            .lineSpacing(4)
            .padding(.horizontal, 32)
            .animation(.easeInOut(duration: 0.25), value: instruction)
    }

    @ViewBuilder
    private var bottomAction: some View {
        if phase == .completed, capturedPayload?.mesh.isValid == true, capturedMarkers != nil {
            FaceIDContinueButton {
                HapticManager.shared.impact(.medium)
                if let payload = capturedPayload, let markers = capturedMarkers {
                    onContinue(payload, markers)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var faceScanBackButton: some View {
        VStack {
            HStack {
                OnboardingBackButton(action: {
                    FaceScanScreenFlash.shared.deactivate()
                    onBack()
                })
                Spacer()
            }
            .padding(.horizontal, OnboardingConstants.headerHorizontalPadding)
            .padding(.top, OnboardingConstants.headerBackButtonTopPadding)
            Spacer()
        }
        .allowsHitTesting(true)
    }

    private func handleCapture(_ payload: FaceScanCapturePayload) {
        guard payload.mesh.isValid else { return }
        guard FaceScanQualityValidator.meshIsSolid(payload.mesh) else { return }

        let markers = FaceWellnessAnalyzer.analyze(from: payload)
        capturedPayload = payload
        capturedMarkers = markers

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            phase = .completed
            morphToCircle = 1
        }
    }
}
