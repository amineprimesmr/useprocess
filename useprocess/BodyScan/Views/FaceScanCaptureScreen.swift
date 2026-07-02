import ARKit
import SwiftUI

enum FaceScanCapturePresentation: Equatable {
    case fullScreen
    case embeddedCard(viewportDiameter: CGFloat)
    /// Scan intégré à la carte « Dernier scan » sur l’accueil Plan.
    case inlineHome(viewportDiameter: CGFloat, phase: InlineHomePhase = .active)

    enum InlineHomePhase: Equatable {
        /// Aperçu compact — caméra AR live sans lancer le scan.
        case preview
        /// Scan actif avec contrôles.
        case active
    }
}

/// Écran de capture scan visage — plein écran ou carte intégrée (accueil).
struct FaceScanCaptureScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appTheme) private var appTheme

    var presentation: FaceScanCapturePresentation = .fullScreen
    var showsInlineHeader: Bool = true
    var matchedCameraID: String? = nil
    var matchedCameraNamespace: Namespace.ID? = nil
    var onBack: () -> Void = {}
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
    @State private var showGalleryPicker = false
    @State private var isImportingMedia = false
    @State private var importErrorMessage: String?

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
        if isInlinePreview { return false }
        return phase == .scanning || phase == .completed || isPositioningWellFramed
    }

    /// 0 = carré arrondi, 1 = cercle.
    private var viewportMorph: CGFloat {
        usesCircularViewport ? 1 : 0
    }

    private var showsFrameCorners: Bool {
        !isInlinePreview && phase == .positioning && !isPositioningWellFramed
    }

    private var showsScanRing: Bool {
        !isInlinePreview && (scanProgress > 0.005 || phase == .completed)
    }

    private var isEmbedded: Bool {
        switch presentation {
        case .embeddedCard, .inlineHome:
            return true
        case .fullScreen:
            return false
        }
    }

    private var isInlineHome: Bool {
        if case .inlineHome = presentation { return true }
        return false
    }

    private var isInlinePreview: Bool {
        if case .inlineHome(_, let phase) = presentation, phase == .preview {
            return true
        }
        return false
    }

    var body: some View {
        Group {
            switch presentation {
            case .fullScreen:
                fullScreenLayout
            case .embeddedCard(let viewportDiameter):
                embeddedCardLayout(viewportDiameter: viewportDiameter)
            case .inlineHome(let viewportDiameter, let phase):
                inlineHomeSectionLayout(viewportDiameter: viewportDiameter, phase: phase)
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
        .sheet(isPresented: $showGalleryPicker) {
            FaceScanGalleryImportPicker(
                onImage: { image in
                    showGalleryPicker = false
                    importImage(image)
                },
                onVideoURL: { url in
                    showGalleryPicker = false
                    importVideo(from: url)
                },
                onCancel: {
                    showGalleryPicker = false
                }
            )
            .ignoresSafeArea()
        }
        .alert(
            "Import impossible",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "Réessaie avec un autre fichier.")
        }
        .overlay {
            if isImportingMedia {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.large)
                    Text("Analyse du média…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Layouts

    private var fullScreenLayout: some View {
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
                    Spacer()
                        .frame(height: OnboardingConstants.backOnlyContentTopInset)

                    cameraSection(viewportSize: viewportSize)
                        .padding(.top, AdaptiveScreenLayout.isRegularWidth(horizontalSizeClass) ? 12 : 8)

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

                        importMediaButton
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                    }

                    bottomAction
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(safeArea.bottom + 16, 28))
                }
                .regularWidthContainer(maxWidth: AdaptiveScreenLayout.faceScanColumnMaxWidth)
            }
            .overlay(alignment: .top) {
                scanHeader
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private func embeddedCardLayout(viewportDiameter: CGFloat) -> some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(
                            isFlashEnabled
                                ? Color.white
                                : (appTheme.isDark ? Color(red: 0.07, green: 0.07, blue: 0.08) : Color(red: 0.94, green: 0.94, blue: 0.96))
                        )
                        .frame(width: viewportDiameter + 20, height: viewportDiameter + 20)
                        .shadow(color: .black.opacity(appTheme.isDark ? 0.45 : 0.14), radius: 20, y: 10)

                    cameraSection(viewportSize: viewportDiameter)
                }

                if isDeviceSupported, phase != .completed {
                    embeddedFlashToggle
                        .padding(.top, 6)
                        .padding(.trailing, 6)
                }
            }
            .frame(maxWidth: .infinity)

            embeddedControlsBlock
        }
    }

    private func inlineHomeSectionLayout(viewportDiameter: CGFloat, phase: FaceScanCapturePresentation.InlineHomePhase) -> some View {
        ZStack {
            if isFlashEnabled {
                Color.white
            }

            VStack(spacing: 14) {
                if phase == .active, showsInlineHeader {
                    inlineHomeScanHeader
                }

                ZStack(alignment: .top) {
                    if isFlashEnabled {
                        Circle()
                            .fill(Color.white)
                            .frame(width: viewportDiameter + 24, height: viewportDiameter + 24)
                    }

                    cameraSection(viewportSize: viewportDiameter)
                        .frame(width: viewportDiameter, height: viewportDiameter)
                        .frame(maxWidth: .infinity)

                    if phase == .active {
                        HStack(alignment: .top) {
                            if !showsInlineHeader, self.phase != .completed {
                                inlineDismissToggle
                                    .padding(.top, 8)
                                    .padding(.leading, 8)
                            }

                            Spacer(minLength: 0)

                            if isDeviceSupported, self.phase != .completed {
                                embeddedFlashToggle
                                    .padding(.top, 8)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                }

                if phase == .active {
                    embeddedControlsBlock
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: phase)
        .animation(.easeInOut(duration: 0.22), value: isFlashEnabled)
    }

    private var inlineHomeScanHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Scan du jour")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(appTheme.primaryText)
                Text(phase == .completed ? "Terminé" : "Cadre ton visage")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(appTheme.secondaryText)
            }

            Spacer(minLength: 0)

            Button {
                HapticManager.shared.impact(.light)
                FaceScanScreenFlash.shared.deactivate()
                onBack()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(appTheme.primaryText)
                    .frame(width: 34, height: 34)
                    .background {
                        Circle()
                            .fill(appTheme.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer le scan")
        }
    }

    private var embeddedControlsBlock: some View {
        VStack(spacing: 10) {
            embeddedInstructionBlock

            if let hint = frameHint, phase != .completed {
                FaceIDFrameHint(text: hint, isLightBackdrop: isFlashEnabled)
            }

            embeddedFlashStatusLabel

            if phase == .scanning || scanProgress > 0.02 {
                embeddedProgressBar
            }

            embeddedRetryButton
        }
        .padding(.horizontal, 4)
    }

    private var embeddedFlashToggle: some View {
        inlineChromeIconButton(
            systemImage: isFlashEnabled ? "bolt.fill" : "bolt.slash",
            tint: isFlashEnabled ? Color(red: 0.95, green: 0.78, blue: 0.12) : appTheme.secondaryText,
            accessibilityLabel: isFlashEnabled ? "Désactiver le flash" : "Activer le flash"
        ) {
            HapticManager.shared.impact(.light)
            userFlashOverride = true
            isFlashEnabled.toggle()
        }
    }

    private var inlineDismissToggle: some View {
        inlineChromeIconButton(
            systemImage: "xmark",
            tint: appTheme.secondaryText,
            accessibilityLabel: "Fermer le scan"
        ) {
            HapticManager.shared.impact(.light)
            FaceScanScreenFlash.shared.deactivate()
            onBack()
        }
    }

    private func inlineChromeIconButton(
        systemImage: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(appTheme.isDark ? Color.black.opacity(0.45) : Color.white.opacity(0.92))
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var embeddedInstructionBlock: some View {
        Text(instruction)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(instructionForeground)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 12)
            .animation(.easeInOut(duration: 0.2), value: instruction)
    }

    private var instructionForeground: Color {
        if isEmbedded {
            return isFlashEnabled ? Color.black.opacity(0.82) : appTheme.primaryText
        }
        return isFlashEnabled ? Color.black.opacity(0.88) : OnboardingTheme.primaryText
    }

    @ViewBuilder
    private var embeddedFlashStatusLabel: some View {
        if phase != .completed, isDeviceSupported {
            if isFlashEnabled {
                Label(
                    userFlashOverride ? "Flash activé" : "Flash auto",
                    systemImage: "bolt.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.55) : appTheme.onboardingAccent)
            } else if isLowLight {
                Label("Environnement sombre", systemImage: "moon.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appTheme.secondaryText)
            }
        }
    }

    private var embeddedProgressBar: some View {
        let safeProgress = scanProgress.isFinite
            ? min(1, max(0, scanProgress))
            : 0

        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(appTheme.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [appTheme.onboardingAccent, appTheme.glow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * safeProgress))
                        .animation(.easeInOut(duration: 0.3), value: safeProgress)
                }
            }
            .frame(height: 5)

            Text("\(Int(safeProgress * 100)) %")
                .font(.caption2.weight(.bold))
                .foregroundStyle(appTheme.secondaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var embeddedRetryButton: some View {
        if isDeviceSupported, scanProgress > 0.02, scanProgress < 1 {
            Button(action: restartScan) {
                Text("Recommencer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appTheme.onboardingAccent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Header

    private var scanHeader: some View {
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
        .frame(height: OnboardingConstants.backButtonSize, alignment: .center)
        .padding(.top, OnboardingConstants.headerBackButtonTopPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .zIndex(10)
    }

    // MARK: - Camera

    private func cameraSection(viewportSize: CGFloat) -> some View {
        let core = ZStack {
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
                            isPreviewOnly: isInlinePreview,
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
                    color: .black.opacity(isFlashEnabled ? (isInlineHome ? 0 : 0.12) : 0.35),
                    radius: isFlashEnabled && isInlineHome ? 0 : 14,
                    y: isFlashEnabled && isInlineHome ? 0 : 4
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
        .animation(.interpolatingSpring(duration: isInlineHome ? 0.62 : 0.55, bounce: isInlineHome ? 0.14 : 0.08), value: viewportMorph)
        .animation(.easeInOut(duration: 0.25), value: phase)
        .animation(.easeInOut(duration: 0.2), value: showsFrameCorners)
        .animation(.easeInOut(duration: 0.2), value: showsScanRing)

        return Group {
            if let matchedCameraID, let matchedCameraNamespace {
                core.matchedGeometryEffect(id: matchedCameraID, in: matchedCameraNamespace)
            } else {
                core
            }
        }
    }

    @ViewBuilder
    private func scannerOverlay(cameraDiameter: CGFloat) -> some View {
        ZStack {
            FaceIDTickProgressRing(
                activeSectors: activeTickSectors,
                cameraDiameter: cameraDiameter,
                isLightBackdrop: isFlashEnabled
            )

            if phase == .completed {
                FaceIDSuccessRing(diameter: cameraDiameter)
                    .transition(.scale.combined(with: .opacity))
            }
        }
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
    private var importMediaButton: some View {
        Button {
            HapticManager.shared.impact(.light)
            showGalleryPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold))
                Text("Importer photo ou vidéo")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.82) : OnboardingTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .glassStyle()
        .buttonBorderShape(.roundedRectangle(radius: 50))
        .disabled(isImportingMedia)
        .opacity(isImportingMedia ? 0.55 : 1)
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
            Text("Caméra avant requise")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
            Text("Utilise un appareil avec Face ID\n(iPhone ou iPad Pro), ou importe une photo / vidéo.")
                .font(.system(size: 15))
                .foregroundStyle(OnboardingTheme.footnoteText)
                .multilineTextAlignment(.center)
            importMediaButton
                .padding(.top, 4)
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

        HapticManager.shared.notification(.success)

        withAnimation(.easeInOut(duration: 0.28)) {
            phase = .completed
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(isInlineHome ? 520 : 380))
            guard capturedPayload?.scanId == payload.scanId else { return }
            onContinue(payload, markers)
        }
    }

    private func importImage(_ image: UIImage) {
        isImportingMedia = true
        Task { @MainActor in
            defer { isImportingMedia = false }
            do {
                let result = try FaceScanMediaImport.process(image: image)
                submitImportedMedia(result.0, markers: result.1)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func importVideo(from url: URL) {
        isImportingMedia = true
        Task { @MainActor in
            defer {
                isImportingMedia = false
                try? FileManager.default.removeItem(at: url)
            }
            do {
                let result = try await FaceScanMediaImport.process(videoSourceURL: url)
                submitImportedMedia(result.0, markers: result.1)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func submitImportedMedia(_ payload: FaceScanCapturePayload, markers: FaceWellnessMarkers) {
        capturedPayload = payload
        capturedMarkers = markers
        FaceScanScreenFlash.shared.deactivate(animated: true)
        isFlashEnabled = false
        HapticManager.shared.notification(.success)
        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .completed
        }
        onContinue(payload, markers)
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
