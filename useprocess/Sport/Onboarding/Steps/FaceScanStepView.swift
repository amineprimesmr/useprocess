import ARKit
import SwiftUI

/// Scan visage Face ID — carré → cercle, ticks yaw, analyse complète.
struct FaceScanStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var onComplete: () -> Void
    var onBack: () -> Void

    @State private var scanProgress: Double = 0
    @State private var ringProgress: Double = 0
    @State private var activeTickSectors: Set<Int> = []
    @State private var instruction = "Placez votre visage dans le cadre."
    @State private var frameHint: String?
    @State private var isFaceDetected = false
    @State private var isDeviceSupported = ARFaceTrackingConfiguration.isSupported
    @State private var phase: FaceScanPhase = .positioning
    @State private var scanSessionID = UUID()
    @State private var showContent = false
    @State private var isExpanding = false
    @State private var morphToCircle: CGFloat = 0
    @State private var capturedMesh: FaceMesh3DData?

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

    // MARK: - Overlay Face ID

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
                        isComplete: true
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
                .foregroundStyle(.white.opacity(0.5))
            Text("TrueDepth requis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            Text("Utilisez un iPhone avec Face ID\n(iPhone X ou plus récent).")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private var instructionSection: some View {
        Text(instruction)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.white)
            .multilineTextAlignment(phase == .completed ? .trailing : .center)
            .frame(maxWidth: .infinity, alignment: phase == .completed ? .trailing : .center)
            .lineSpacing(4)
            .padding(.horizontal, 32)
            .animation(.easeInOut(duration: 0.25), value: instruction)
    }

    @ViewBuilder
    private var bottomAction: some View {
        if phase == .completed, capturedMesh?.isValid == true {
            FaceIDContinueButton {
                HapticManager.shared.impact(.medium)
                onComplete()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var faceScanBackButton: some View {
        VStack {
            HStack {
                OnboardingBackButton(action: onBack)
                Spacer()
            }
            .padding(.horizontal, OnboardingConstants.headerHorizontalPadding)
            .padding(.top, OnboardingConstants.headerBackButtonTopPadding)
            Spacer()
        }
        .allowsHitTesting(true)
    }

    // MARK: - Capture

    private func handleCapture(_ payload: FaceScanCapturePayload) {
        guard payload.mesh.isValid else { return }

        let result = FaceWellnessAnalyzer.analyze(from: payload)
        viewModel.onboardingFaceMesh = payload.mesh
        viewModel.onboardingFaceMarkers = result
        viewModel.isFaceAnalysisCompleted = true
        OnboardingFaceMarkersStore.save(markers: result, mesh: payload.mesh)
        capturedMesh = payload.mesh

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            phase = .completed
            morphToCircle = 1
        }
    }
}
