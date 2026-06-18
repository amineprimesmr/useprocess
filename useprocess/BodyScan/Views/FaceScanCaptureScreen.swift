import ARKit
import SwiftUI

/// Écran de capture TrueDepth — layout fixe, flash contrôlé, sans animation Dynamic Island.
struct FaceScanCaptureScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var onBack: () -> Void
    var onSkip: (() -> Void)? = nil
    var onContinue: (FaceScanCapturePayload, FaceWellnessMarkers) -> Void

    @State private var scanProgress: Double = 0
    @State private var ringProgress: Double = 0
    @State private var activeTickSectors: Set<Int> = []
    @State private var instruction = "Rapproche-toi pour que ton visage remplisse le cadre."
    @State private var frameHint: String?
    @State private var isFaceDetected = false
    @State private var isLowLight = false
    @State private var isDeviceSupported = ARFaceTrackingConfiguration.isSupported
    @State private var phase: FaceScanPhase = .positioning
    @State private var scanSessionID = UUID()
    @State private var capturedPayload: FaceScanCapturePayload?
    @State private var capturedMarkers: FaceWellnessMarkers?
    @State private var canSkipScan = false
    @State private var isFlashEnabled = false
    @State private var userFlashOverride = false

    private var cameraZoom: CGFloat {
        AdaptiveScreenLayout.faceScanCameraZoom(horizontalSizeClass: horizontalSizeClass)
    }

    private enum FaceScanPhase {
        case positioning
        case scanning
        case completed
    }

    /// Visage bien cadré en phase de positionnement (distance OK, pas de hint).
    private var isPositioningWellFramed: Bool {
        frameHint == nil && isFaceDetected
    }

    /// Une fois le scan lancé, on garde le cercle — les rotations faussent parfois le cadrage.
    private var usesCircularViewport: Bool {
        phase == .scanning || phase == .completed || isPositioningWellFramed
    }

    /// 0 = carré arrondi, 1 = cercle.
    private var viewportMorph: CGFloat {
        usesCircularViewport ? 1 : 0
    }

    private var showsFrameCorners: Bool {
        phase == .positioning && !isPositioningWellFramed
    }

    private var showsScanRing: Bool {
        scanProgress > 0.005 || phase == .completed
    }

    var body: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            let viewportSize = AdaptiveScreenLayout.faceScanViewportDiameter(
                width: geometry.size.width,
                height: geometry.size.height,
                horizontalSizeClass: horizontalSizeClass
            )

            ZStack {
                (isFlashEnabled ? Color.white : Color.black)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(safeArea: safeArea)
                        .padding(.top, safeArea.top + 6)

                    cameraSection(viewportSize: viewportSize)
                        .padding(.top, AdaptiveScreenLayout.isRegularWidth(horizontalSizeClass) ? 28 : 18)

                    instructionBlock
                        .padding(.top, 22)

                    if let hint = frameHint, phase != .completed {
                        FaceIDFrameHint(text: hint, isLightBackdrop: isFlashEnabled)
                            .padding(.top, 12)
                    }

                    flashStatusLabel
                        .padding(.top, 10)

                    Spacer(minLength: 12)

                    if phase != .completed {
                        retryScanButton
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                    }

                    bottomAction
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(safeArea.bottom + 16, 28))
                }
                .regularWidthContainer(maxWidth: AdaptiveScreenLayout.faceScanColumnMaxWidth)
            }
        }
        .onAppear {
            userFlashOverride = false
            isFlashEnabled = false
            FaceScanScreenFlash.shared.deactivate(animated: false)
        }
        .onDisappear {
            FaceScanScreenFlash.shared.deactivate()
        }
        .task {
            guard isDeviceSupported else {
                canSkipScan = true
                return
            }
            try? await Task.sleep(for: .seconds(6))
            guard phase != .completed else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                canSkipScan = true
            }
        }
        .onChange(of: isDeviceSupported) { _, supported in
            if !supported { canSkipScan = true }
        }
        .onChange(of: isLowLight) { _, low in
            guard !userFlashOverride else { return }
            // Auto ON uniquement — le flash éclaire la scène et fausse la détection lux.
            // Ne jamais auto-OFF sinon boucle clignotante.
            guard low, !isFlashEnabled else { return }
            isFlashEnabled = true
        }
        .onChange(of: isFaceDetected) { _, detected in
            guard isDeviceSupported, phase != .completed else { return }
            if !detected, phase == .scanning, scanProgress < 0.03 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .positioning
                }
            }
        }
        .onChange(of: scanProgress) { oldValue, value in
            if value > 0.005, phase == .positioning {
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = .scanning
                }
            }
            if value >= 1, phase != .completed, capturedPayload != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = .completed
                }
            } else if value < 0.03, oldValue > 0.15, phase == .scanning {
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .positioning
                    capturedPayload = nil
                    capturedMarkers = nil
                }
            }
        }
        .onChange(of: isFlashEnabled) { _, enabled in
            if enabled {
                FaceScanScreenFlash.shared.activate(animated: false)
            } else {
                FaceScanScreenFlash.shared.deactivate(animated: true)
            }
        }
    }

    // MARK: - Header

    private func header(safeArea: EdgeInsets) -> some View {
        HStack(spacing: 12) {
            OnboardingBackButton(action: {
                FaceScanScreenFlash.shared.deactivate()
                onBack()
            })

            Spacer(minLength: 0)

            if isDeviceSupported, phase != .completed {
                FaceScanFlashToggle(isEnabled: isFlashEnabled) {
                    userFlashOverride = true
                    isFlashEnabled.toggle()
                }
            }
        }
        .padding(.horizontal, OnboardingConstants.headerHorizontalPadding)
    }

    // MARK: - Camera

    private func cameraSection(viewportSize: CGFloat) -> some View {
        ZStack {
            if isDeviceSupported {
                FaceScannerViewport(
                    size: CGSize(width: viewportSize, height: viewportSize),
                    morphToCircle: viewportMorph,
                    camera: {
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
                        .scaleEffect(cameraZoom)
                    },
                    overlay: { EmptyView() }
                )
                .overlay {
                    FaceMorphClipShape(morph: viewportMorph)
                        .strokeBorder(
                            isFlashEnabled ? Color.black.opacity(0.08) : Color.white.opacity(0.18),
                            lineWidth: 1.5
                        )
                }
                .shadow(
                    color: .black.opacity(isFlashEnabled ? 0.12 : 0.35),
                    radius: 14,
                    y: 4
                )

                if showsFrameCorners {
                    FaceScanFrameCornerBrackets(size: viewportSize)
                        .transition(.opacity)
                }

                if showsScanRing {
                    scannerOverlay(cameraDiameter: viewportSize)
                        .transition(.opacity)
                }
            } else {
                unsupportedSection
                    .frame(width: viewportSize)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.interpolatingSpring(duration: 0.55, bounce: 0.08), value: viewportMorph)
        .animation(.easeInOut(duration: 0.25), value: phase)
        .animation(.easeInOut(duration: 0.2), value: showsFrameCorners)
        .animation(.easeInOut(duration: 0.2), value: showsScanRing)
    }

    @ViewBuilder
    private func scannerOverlay(cameraDiameter: CGFloat) -> some View {
        FaceIDTickProgressRing(
            activeSectors: activeTickSectors,
            cameraDiameter: cameraDiameter,
            isComplete: phase == .completed,
            isLightBackdrop: isFlashEnabled
        )
    }

    // MARK: - Copy

    private var instructionBlock: some View {
        Text(instruction)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.88) : OnboardingTheme.primaryText)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 32)
            .animation(.easeInOut(duration: 0.2), value: instruction)
    }

    @ViewBuilder
    private var flashStatusLabel: some View {
        if phase != .completed, isDeviceSupported {
            if isFlashEnabled {
                Label(
                    userFlashOverride ? "Flash activé" : "Flash auto — environnement sombre",
                    systemImage: "bolt.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.55) : .yellow)
            } else if isLowLight {
                Label("Environnement sombre — active le flash", systemImage: "moon.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.5) : OnboardingTheme.mutedText)
            }
        }
    }

    @ViewBuilder
    private var retryScanButton: some View {
        if isDeviceSupported, scanProgress > 0.02, scanProgress < 1 {
            Button(action: restartScan) {
                Text("Recommencer le scan")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.55) : OnboardingTheme.mutedText)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var bottomAction: some View {
        if phase == .completed, capturedPayload?.mesh.isValid == true, capturedMarkers != nil {
            FaceIDContinueButton {
                HapticManager.shared.impact(.medium)
                FaceScanScreenFlash.shared.deactivate()
                if let payload = capturedPayload, let markers = capturedMarkers {
                    onContinue(payload, markers)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else if canSkipScan {
            skipScanButton
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder
    private var skipScanButton: some View {
        if let onSkip {
            Button(action: {
                HapticManager.shared.impact(.medium)
                FaceScanScreenFlash.shared.deactivate()
                onSkip()
            }) {
                Text("CONTINUER SANS SCAN")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(isFlashEnabled ? Color.black : OnboardingTheme.actionButtonText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 50))
        }
    }

    private var unsupportedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "faceid")
                .font(.system(size: 48))
                .foregroundStyle(OnboardingTheme.mutedText)
            Text("TrueDepth requis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
            Text("Utilise un appareil avec Face ID\n(iPhone ou iPad Pro).")
                .font(.system(size: 15))
                .foregroundStyle(OnboardingTheme.footnoteText)
                .multilineTextAlignment(.center)
            skipScanButton
                .padding(.top, 8)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions

    private func handleCapture(_ payload: FaceScanCapturePayload) {
        guard payload.mesh.isValid, FaceScanQualityValidator.meshIsSolid(payload.mesh) else {
            restartScan()
            return
        }

        let markers = FaceWellnessAnalyzer.analyze(from: payload)
        capturedPayload = payload
        capturedMarkers = markers

        FaceScanScreenFlash.shared.deactivate(animated: true)
        isFlashEnabled = false

        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .completed
        }
    }

    private func restartScan() {
        scanSessionID = UUID()
        scanProgress = 0
        ringProgress = 0
        activeTickSectors = []
        isFaceDetected = false
        frameHint = nil
        instruction = "Place ton visage dans le cadre."
        capturedPayload = nil
        capturedMarkers = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .positioning
        }
    }
}

// MARK: - Flash toggle

struct FaceScanFlashToggle: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            Image(systemName: isEnabled ? "bolt.fill" : "bolt.slash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(
                    width: OnboardingConstants.backButtonSize,
                    height: OnboardingConstants.backButtonSize
                )
        }
        .glassStyle()
        .accessibilityLabel(isEnabled ? "Désactiver le flash écran" : "Activer le flash écran")
    }

    private var iconColor: Color {
        isEnabled ? Color(red: 0.95, green: 0.78, blue: 0.12) : OnboardingTheme.bodyText
    }
}
