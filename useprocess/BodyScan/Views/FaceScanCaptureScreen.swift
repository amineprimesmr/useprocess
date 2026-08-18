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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    var presentation: FaceScanCapturePresentation = .fullScreen
    var showsInlineHeader: Bool = true
    var matchedCameraID: String? = nil
    var matchedCameraNamespace: Namespace.ID? = nil
    var onBack: () -> Void = {}
    var onSkip: (() -> Void)? = nil
    var showsMediaImport: Bool = false
    var compactSkipAction: Bool = false
    var skipButtonTitle: String = AppCopy.t("Passer pour le moment", en: "Skip for now")
    var allowsScreenFlash: Bool = true
    var isCameraSessionActive: Bool = true
    /// Pas de phase « penche la tête ».
    var skipsHeadTiltPhase: Bool = true
    /// Cadre ovale visage (même design que l’onboarding).
    var usesOnboardingFaceOval: Bool = false
    /// Fond app (`ProcessBackgroundPalette`) au lieu du canvas scan onboarding.
    var usesAppScreenBackground: Bool = false
    /// Chrono 3-2-1 à la place du titre, à l’arrivée sur l’écran.
    var playsArrivalCountdown: Bool = false
    var onContinue: (FaceScanCapturePayload, FaceWellnessMarkers) -> Void

    @State private var scanProgress: Double = 0
    @State private var ringProgress: Double = 0
    @State private var activeTickSectors: Set<Int> = []
    @State private var currentTickSector: Int = -1
    @State private var overlayMode: FaceScanCaptureOverlayMode = .orbitTicks
    @State private var tiltHoldProgress: Double = 0
    @State private var tiltDirection: FaceScanTiltDirection = .none
    @State private var tiltIsEngaged: Bool = false
    @State private var instruction = AppCopy.t("Rapproche-toi pour que ton visage remplisse le cadre.", en: "Move closer so your face fills the frame.")

    private var onboardingCanvasColor: Color {
        if isFlashEnabled { return .white }
        if usesAppScreenBackground {
            return ProcessBackgroundPalette.base(for: colorScheme)
        }
        return FaceScanWhoopPalette.canvas
    }
    @State private var frameHint: String?
    @State private var isFaceDetected = false
    @State private var isLowLight = false
    @State private var isDeviceSupported = ARFaceTrackingConfiguration.isSupported
    @State private var phase: FaceScanPhase = .positioning
    @State private var scanSessionID = UUID()
    @State private var inlineMeshResetNonce = 0
    @State private var capturedPayload: FaceScanCapturePayload?
    @State private var capturedMarkers: FaceWellnessMarkers?
    @State private var canSkipScan = false
    @State private var isFlashEnabled = false
    @State private var userFlashOverride = false
    @State private var showGalleryPicker = false
    @State private var isImportingMedia = false
    @State private var importErrorMessage: String?
    /// Aperçu immédiat pendant l’import — même language visuel que l’écran analyse.
    @State private var importingPreviewImage: UIImage?
    @State private var hasSubmittedCapture = false
    @State private var captureSessionPaused = false
    @State private var didFinishArrivalCountdown = false
    @State private var arrivalCountdownValue = 3
    @State private var arrivalCountdownTask: Task<Void, Never>?
    @State private var isArrivalCameraRevealed = false

    private var cameraZoom: CGFloat {
        AdaptiveScreenLayout.faceScanCameraZoom(horizontalSizeClass: horizontalSizeClass)
    }

    private enum FaceScanPhase {
        case positioning
        case scanning
        case completed
    }

    private var isARSessionActive: Bool {
        isCameraSessionActive && scenePhase == .active && !captureSessionPaused && phase != .completed
    }
    private var isPositioningWellFramed: Bool {
        frameHint == nil && isFaceDetected
    }

    /// Visage détecté + distance OK (cadrage validé ou « ne bouge plus » avant le démarrage).
    private var isOnboardingFaceCalibrated: Bool {
        guard isFaceDetected else { return false }
        if frameHint == nil { return true }
        let hint = frameHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return hint == AppCopy.tSync(
            "Ne bouge plus. Le scan va démarrer.",
            en: "Hold still. The scan is about to start."
        )
    }

    /// Masque bleu + anneau de tirets onboarding — uniquement quand le cadrage est bon ou le scan actif.
    private var showsOnboardingScanCalibrationChrome: Bool {
        guard usesOnboardingFaceOval, !isInlinePreview, !isArrivalCountdownActive, !scanBlockedByLighting else { return false }
        if phase == .scanning || phase == .completed || scanProgress > 0.005 { return true }
        return isOnboardingFaceCalibrated
    }

    /// Une fois le scan lancé, on garde le cercle — les rotations faussent parfois le cadrage.
    private var usesCircularViewport: Bool {
        if usesOnboardingFaceOval { return true }
        if isInlinePreview { return false }
        return phase == .scanning || phase == .completed || isPositioningWellFramed
    }

    /// 0 = carré arrondi, 1 = cercle / ovale onboarding.
    private var viewportMorph: CGFloat {
        if usesOnboardingFaceOval { return 1 }
        return usesCircularViewport ? 1 : 0
    }

    private var showsFrameCorners: Bool {
        if usesOnboardingFaceOval { return false }
        return !isInlinePreview && phase == .positioning && !isPositioningWellFramed && !scanBlockedByLighting
    }

    private var viewportStyle: FaceScanViewportStyle {
        usesOnboardingFaceOval ? .onboardingFaceOval : .morphingRoundedSquare
    }

    private var showsScanRing: Bool {
        if usesOnboardingFaceOval {
            return showsOnboardingScanCalibrationChrome
        }
        return !isInlinePreview && (scanProgress > 0.005 || phase == .completed)
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

    private var isArrivalCountdownActive: Bool {
        playsArrivalCountdown && !didFinishArrivalCountdown && !isEmbedded
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
            startArrivalCountdownIfNeeded()
        }
        .onDisappear {
            arrivalCountdownTask?.cancel()
            arrivalCountdownTask = nil
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
            guard allowsScreenFlash, !isInlinePreview, !usesOnboardingFaceOval else { return }
            guard !userFlashOverride else { return }
            guard low, !isFlashEnabled else { return }
            isFlashEnabled = true
        }
        .onChange(of: scanBlockedByLighting) { _, blocked in
            guard blocked, phase == .scanning else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                phase = .positioning
            }
        }
        .onChange(of: isFaceDetected) { _, detected in
            guard isDeviceSupported, phase != .completed else { return }
            if !detected, phase == .scanning, scanProgress < 0.03 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .positioning
                }
            }
        }
        .onChange(of: isInlinePreview) { _, isPreview in
            guard isInlineHome else { return }
            if isPreview {
                userFlashOverride = false
                isFlashEnabled = false
                FaceScanScreenFlash.shared.deactivate()
                resetCaptureState(instruction: "")
            } else {
                instruction = AppCopy.t("Rapproche-toi pour que ton visage remplisse le cadre.", en: "Move closer so your face fills the frame.")
                frameHint = nil
            }
        }
        .onChange(of: scanProgress) { oldValue, value in
            guard !isInlinePreview else { return }
            if value > 0.005, phase == .positioning {
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = .scanning
                }
            }
            if value >= 1, phase != .completed, capturedPayload != nil {
                phase = .completed
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
                guard allowsScreenFlash, !isInlinePreview else {
                    FaceScanScreenFlash.shared.deactivate(animated: true)
                    return
                }
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
            AppCopy.t("Import impossible", en: "Import failed"),
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button(AppCopy.t("OK", en: "OK"), role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? AppCopy.t("Réessaie avec un autre fichier.", en: "Try another file."))
        }
        .overlay {
            if isImportingMedia {
                mediaImportAnalysisOverlay
            }
        }
    }

    // MARK: - Layouts

    private var fullScreenLayout: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            let squareDiameter = AdaptiveScreenLayout.faceScanViewportDiameter(
                width: geometry.size.width,
                height: geometry.size.height,
                horizontalSizeClass: horizontalSizeClass
            )
            let ovalWidth: CGFloat = {
                guard usesOnboardingFaceOval else { return squareDiameter }
                if AdaptiveScreenLayout.isRegularWidth(horizontalSizeClass) {
                    return min(280, geometry.size.width - 160)
                }
                return min(geometry.size.width - 128, 248)
            }()
            let viewportSize = usesOnboardingFaceOval
                ? CGSize(width: ovalWidth, height: ovalWidth * FaceScanViewportMetrics.onboardingOvalAspect)
                : CGSize(width: squareDiameter, height: squareDiameter)

            ZStack {
                if usesOnboardingFaceOval {
                    onboardingCanvasColor
                        .ignoresSafeArea()
                } else {
                    (isFlashEnabled ? Color.white : Color.black)
                        .ignoresSafeArea()
                }

                if usesOnboardingFaceOval {
                    onboardingReferenceLayout(viewportSize: viewportSize, safeArea: safeArea)
                } else {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: OnboardingConstants.backOnlyContentTopInset)

                        cameraSection(viewportSize: viewportSize)
                            .padding(.top, AdaptiveScreenLayout.isRegularWidth(horizontalSizeClass) ? 12 : 8)
                            .padding(.horizontal, 0)
                            .allowsHitTesting(phase != .completed)

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
                                .padding(.bottom, 4)

                            if onSkip != nil {
                                skipScanButton
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 8)
                            }

                            if showsMediaImport {
                                importMediaButton
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 8)
                            }
                        }

                        bottomAction
                            .padding(.horizontal, 24)
                            .padding(.bottom, max(safeArea.bottom + 16, 28))
                            .zIndex(20)
                    }
                    .regularWidthContainer(maxWidth: AdaptiveScreenLayout.faceScanColumnMaxWidth)
                }
            }
            .overlay(alignment: .top) {
                if !usesOnboardingFaceOval {
                    scanHeader
                }
            }
        }
        .ignoresSafeArea()
        .processClearUIKitHostingBackground()
        .background(
            isFlashEnabled
                ? Color.white
                : (usesOnboardingFaceOval ? onboardingCanvasColor : Color.black)
        )
    }

    private func onboardingReferenceLayout(viewportSize: CGSize, safeArea: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: OnboardingConstants.headerBackButtonTopPadding)

            HStack(spacing: 10) {
                if showsTemporaryCaptureBackButton {
                    onboardingChromeButton(systemName: "chevron.left", iconSize: 15) {
                        FaceScanScreenFlash.shared.deactivate()
                        onBack()
                    }
                    .accessibilityLabel(AppCopy.t("Retour", en: "Back"))
                }

                onboardingChromeButton(
                    systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash",
                    iconSize: 16,
                    tint: isFlashEnabled
                        ? Color(red: 0.95, green: 0.78, blue: 0.12)
                        : nil
                ) {
                    userFlashOverride = true
                    isFlashEnabled.toggle()
                }
                .accessibilityLabel(
                    isFlashEnabled
                        ? AppCopy.t("Désactiver le flash", en: "Turn flash off")
                        : AppCopy.t("Activer le flash", en: "Turn flash on")
                )
                .disabled(!isDeviceSupported || phase == .completed)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    onboardingChromeButton(systemName: "arrow.clockwise", iconSize: 16) {
                        restartScan()
                    }
                    .accessibilityLabel(AppCopy.t("Recommencer le scan", en: "Restart scan"))

                    if showsMediaImport, phase != .completed {
                        onboardingChromeButton(systemName: "photo.on.rectangle.angled", iconSize: 15) {
                            showGalleryPicker = true
                        }
                        .accessibilityLabel(AppCopy.t("Importer photo ou vidéo", en: "Import photo or video"))
                        .disabled(isImportingMedia)
                    }
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 7) {
                if isArrivalCountdownActive {
                    Text("\(arrivalCountdownValue)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(onboardingUsesLightChrome ? Color.black.opacity(0.92) : Color.white.opacity(0.94))
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel(
                            AppCopy.t(
                                "Le scan commence dans \(arrivalCountdownValue)",
                                en: "Scan starts in \(arrivalCountdownValue)"
                            )
                        )
                } else {
                    Text(onboardingScanTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(onboardingUsesLightChrome ? Color.black.opacity(0.92) : Color.white.opacity(0.94))
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)

                    Text(onboardingScanSubtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(onboardingUsesLightChrome ? Color.black.opacity(0.38) : Color.white.opacity(0.42))
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 72, alignment: .center)
            .padding(.top, 8)
            .padding(.horizontal, 28)
            .animation(.easeInOut(duration: 0.22), value: arrivalCountdownValue)
            .animation(.easeInOut(duration: 0.22), value: isArrivalCountdownActive)
            .animation(.easeInOut(duration: 0.22), value: onboardingScanCopyToken)

            Spacer()
                .frame(minHeight: 6, maxHeight: 12)

            cameraSection(viewportSize: viewportSize)
                .allowsHitTesting(phase != .completed)

            if showsMediaImport, phase != .completed {
                importMediaButton
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
            }

            Spacer(minLength: showsMediaImport ? 20 : 48)

            Text(onboardingScanFooterCopy)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(onboardingUsesLightChrome ? Color.black.opacity(0.38) : Color.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            Spacer()
                .frame(height: max(safeArea.bottom + 24, 40))
        }
        .regularWidthContainer(maxWidth: AdaptiveScreenLayout.faceScanColumnMaxWidth)
    }

    private var onboardingScanFooterCopy: String {
        if phase == .scanning || scanProgress > 0.005 {
            return AppCopy.t(
                "Tourne la tête en cercle pour capturer tous les angles.",
                en: "Turn your head in a circle to capture every angle."
            )
        }
        if isOnboardingFaceCalibrated {
            return AppCopy.t(
                "Parfait — reste immobile une seconde.",
                en: "Perfect — hold still for a second."
            )
        }
        return AppCopy.t(
            "Place ton visage dans le cadre, puis bouge lentement la tête en cercle pour capturer tous les angles.",
            en: "Position your face in the frame, then slowly move your head in a circle to capture every angle."
        )
    }

    /// État copy onboarding — cadrage → calibré → scan actif.
    private var onboardingScanCopyToken: String {
        if phase == .completed { return "completed" }
        if phase == .scanning || scanProgress > 0.005 { return "scanning" }
        if isOnboardingFaceCalibrated { return "ready" }
        return "positioning"
    }

    private var onboardingScanTitle: String {
        switch onboardingScanCopyToken {
        case "scanning":
            return AppCopy.t("Tourne ta tête", en: "Turn your head")
        case "ready":
            return AppCopy.t("C’est bon", en: "You're set")
        case "completed":
            return AppCopy.t("Scan terminé", en: "Scan complete")
        default:
            return AppCopy.t("Cadre ton visage", en: "Frame your face")
        }
    }

    private var onboardingScanSubtitle: String {
        switch onboardingScanCopyToken {
        case "scanning":
            return AppCopy.t(
                "Tourne lentement la tête tout autour",
                en: "Slowly turn your head all the way around"
            )
        case "ready":
            return AppCopy.t(
                "Ne bouge plus — le scan démarre",
                en: "Hold still — scan starting"
            )
        case "completed":
            return AppCopy.done
        default:
            if let hint = frameHint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
                return hint
            }
            let trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedInstruction.isEmpty {
                return trimmedInstruction
            }
            if !isFaceDetected {
                return AppCopy.t(
                    "Place ton visage dans le cadre",
                    en: "Place your face in the frame"
                )
            }
            return AppCopy.t(
                "Ajuste ta tête dans le cadre",
                en: "Adjust your head in the frame"
            )
        }
    }

    private func onboardingChromeButton(
        systemName: String,
        iconSize: CGFloat,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.impact(.light)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(
                    tint ?? (onboardingUsesLightChrome
                        ? Color.black.opacity(0.42)
                        : Color.white.opacity(0.55))
                )
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.processPlain)
        .background {
            Circle()
                .fill(onboardingUsesLightChrome ? Color.white : Color.white.opacity(0.08))
                .shadow(color: Color.black.opacity(onboardingUsesLightChrome ? 0.10 : 0.35), radius: 10, y: 3)
        }
        .overlay {
            Circle()
                .strokeBorder(
                    onboardingUsesLightChrome ? Color.black.opacity(0.06) : Color.white.opacity(0.10),
                    lineWidth: 0.5
                )
        }
    }

    private var onboardingUsesLightChrome: Bool {
        isFlashEnabled || colorScheme != .dark
    }

    /// TEMP — retour visible sur la capture plein écran (à côté du flash).
    private var showsTemporaryCaptureBackButton: Bool {
        usesOnboardingFaceOval && !isEmbedded && phase != .completed
    }

    private func startArrivalCountdownIfNeeded() {
        guard playsArrivalCountdown, !isEmbedded, !didFinishArrivalCountdown else { return }
        arrivalCountdownTask?.cancel()
        arrivalCountdownValue = 3
        HapticManager.shared.impact(.light)
        withAnimation(.easeOut(duration: 0.42).delay(0.10)) {
            isArrivalCameraRevealed = true
        }
        arrivalCountdownTask = Task { @MainActor in
            for value in [3, 2, 1] {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    arrivalCountdownValue = value
                }
                if value != 3 {
                    HapticManager.shared.impact(.light)
                }
                try? await Task.sleep(for: .milliseconds(720))
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                didFinishArrivalCountdown = true
            }
            HapticManager.shared.impact(.medium)
        }
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

                    cameraSection(viewportSize: CGSize(width: viewportDiameter, height: viewportDiameter))
                }

                if isDeviceSupported, phase != .completed, allowsScreenFlash {
                    embeddedFlashToggle
                        .padding(.top, 6)
                        .padding(.trailing, 6)
                }
            }
            .frame(maxWidth: .infinity)

            embeddedControlsBlock

            if onSkip != nil, phase != .completed {
                skipScanButton
                    .padding(.top, 2)
            }
        }
    }

    private func inlineHomeSectionLayout(viewportDiameter: CGFloat, phase: FaceScanCapturePresentation.InlineHomePhase) -> some View {
        let isPreview = phase == .preview
        let ringOverflow = FaceScanViewportMetrics.tickRingOverflow
        let cameraBlockSize = isPreview ? viewportDiameter : viewportDiameter + ringOverflow

        return VStack(spacing: isPreview ? 0 : 16) {
            if !isPreview, showsInlineHeader {
                inlineHomeScanHeader
            }

            ZStack(alignment: .center) {
                cameraSection(viewportSize: CGSize(width: viewportDiameter, height: viewportDiameter))

                if !isPreview {
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
                    .frame(width: viewportDiameter, height: viewportDiameter)
                }
            }
            .frame(width: cameraBlockSize, height: cameraBlockSize)
            .frame(maxWidth: .infinity, alignment: isPreview ? .leading : .center)

            if !isPreview {
                embeddedControlsBlock
                    .padding(.horizontal, Layout.cardPadding)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                if showsMediaImport, self.phase != .completed {
                    importMediaButton
                        .padding(.horizontal, Layout.cardPadding)
                        .padding(.top, 2)
                }

                bottomAction
                    .padding(.horizontal, Layout.cardPadding)
                    .padding(.top, 4)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: isPreview)
        .animation(.easeInOut(duration: 0.22), value: isFlashEnabled)
    }

    private enum Layout {
        static let cardPadding: CGFloat = 16
    }

    private var inlineHomeScanHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppCopy.t("Scan du jour", en: "Today’s scan"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(appTheme.primaryText)
                Text(phase == .completed ? AppCopy.done : AppCopy.t("Cadre ton visage", en: "Frame your face"))
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
            .buttonStyle(.processPlain)
            .accessibilityLabel(AppCopy.t("Fermer le scan", en: "Close scan"))
        }
    }

    private var scanBlockedByLighting: Bool {
        if usesOnboardingFaceOval { return false }
        return !isInlinePreview && !allowsScreenFlash && isLowLight && phase != .completed
    }

    private var embeddedControlsBlock: some View {
        VStack(spacing: 10) {
            embeddedInstructionBlock

            if let hint = frameHint, phase != .completed, !scanBlockedByLighting {
                FaceIDFrameHint(text: hint, isLightBackdrop: isFlashEnabled)
            }

            if allowsScreenFlash {
                embeddedFlashStatusLabel
            }

            if (phase == .scanning || scanProgress > 0.02), !scanBlockedByLighting {
                embeddedProgressBar
            }

            if allowsScreenFlash {
                embeddedRetryButton
            }
        }
        .padding(.horizontal, 4)
    }

    private var embeddedFlashToggle: some View {
        inlineChromeIconButton(
            systemImage: isFlashEnabled ? "bolt.fill" : "bolt.slash",
            tint: isFlashEnabled ? Color(red: 0.95, green: 0.78, blue: 0.12) : appTheme.secondaryText,
            accessibilityLabel: isFlashEnabled ? AppCopy.t("Désactiver le flash", en: "Turn flash off") : AppCopy.t("Activer le flash", en: "Turn flash on")
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
            accessibilityLabel: AppCopy.t("Fermer le scan", en: "Close scan")
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
        .buttonStyle(.processPlain)
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
            if allowsScreenFlash, isFlashEnabled {
                Label(
                    userFlashOverride ? AppCopy.t("Flash activé", en: "Flash on") : AppCopy.t("Flash auto", en: "Auto flash"),
                    systemImage: "bolt.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.55) : appTheme.onboardingAccent)
            } else if isLowLight, allowsScreenFlash {
                Text(
                    allowsScreenFlash
                        ? AppCopy.t("Environnement sombre", en: "Low light")
                        : AppCopy.t("Pas assez de lumière — place-toi face à une fenêtre ou une lampe.", en: "Not enough light — face a window or lamp.")
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(appTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
                Text(AppCopy.t("Recommencer", en: "Start over"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appTheme.onboardingAccent)
            }
            .buttonStyle(.processPlain)
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

    private func cameraSection(viewportSize: CGSize) -> some View {
        let core = ZStack {
            if isDeviceSupported {
                FaceScannerViewport(
                    size: viewportSize,
                    morphToCircle: scanBlockedByLighting ? 1 : viewportMorph,
                    style: viewportStyle,
                    camera: {
                        ZStack {
                            if usesOnboardingFaceOval {
                                FaceScanOnboardingOvalShape()
                                    .fill(Color(red: 0.09, green: 0.09, blue: 0.10))
                            }
                            FaceMeshScanView(
                                progress: $scanProgress,
                                ringProgress: $ringProgress,
                                activeTickSectors: $activeTickSectors,
                                currentTickSector: $currentTickSector,
                                overlayMode: $overlayMode,
                                tiltHoldProgress: $tiltHoldProgress,
                                tiltDirection: $tiltDirection,
                                tiltIsEngaged: $tiltIsEngaged,
                                instruction: $instruction,
                                frameHint: $frameHint,
                                isFaceDetected: $isFaceDetected,
                                isDeviceSupported: $isDeviceSupported,
                                isLowLight: $isLowLight,
                                isPreviewOnly: isInlinePreview || isArrivalCountdownActive,
                                isSessionRunning: isARSessionActive,
                                allowsScreenFlash: allowsScreenFlash,
                                skipsHeadTiltPhase: skipsHeadTiltPhase,
                                cameraZoom: cameraZoom,
                                onComplete: handleCapture
                            )
                            .id(isInlineHome ? "inline-home-face-mesh-\(inlineMeshResetNonce)" : scanSessionID.uuidString)
                            .blur(radius: scanBlockedByLighting ? 7 : 0)
                            .opacity(playsArrivalCountdown && !isArrivalCameraRevealed ? 0 : 1)
                        }
                    },
                    overlay: { EmptyView() }
                )
                .overlay {
                    if usesOnboardingFaceOval {
                        FaceScanOnboardingInnerEdgeGlow(intensity: colorScheme == .dark ? 0.78 : 0.72)
                            .opacity(showsOnboardingScanCalibrationChrome ? 1 : 0)
                            .scaleEffect(showsOnboardingScanCalibrationChrome ? 1 : 0.988)
                            .animation(
                                .spring(response: 0.44, dampingFraction: 0.84),
                                value: showsOnboardingScanCalibrationChrome
                            )
                            .allowsHitTesting(false)
                    } else if scanBlockedByLighting {
                        FaceMorphClipShape(morph: 1, style: viewportStyle)
                            .fill(Color.black.opacity(0.14))
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if usesOnboardingFaceOval {
                        FaceScanOnboardingOvalShape()
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08),
                                lineWidth: 0.6
                            )
                            .allowsHitTesting(false)
                    } else {
                        FaceMorphClipShape(morph: scanBlockedByLighting ? 1 : viewportMorph, style: viewportStyle)
                            .strokeBorder(
                                isFlashEnabled ? Color.black.opacity(0.08) : Color.white.opacity(0.18),
                                lineWidth: 1.5
                            )
                    }
                }
                .animation(.easeInOut(duration: 0.28), value: scanBlockedByLighting)
                .shadow(
                    color: usesOnboardingFaceOval
                        ? Color.black.opacity(colorScheme == .dark ? 0.45 : 0.12)
                        : .black.opacity(isFlashEnabled ? (isInlineHome ? 0 : 0.12) : 0.35),
                    radius: usesOnboardingFaceOval
                        ? (colorScheme == .dark ? 10 : 18)
                        : (isInlinePreview || (isFlashEnabled && isInlineHome) ? 0 : 14),
                    y: usesOnboardingFaceOval
                        ? (colorScheme == .dark ? 2 : 6)
                        : (isInlinePreview || (isFlashEnabled && isInlineHome) ? 0 : 4)
                )

                if showsFrameCorners {
                    FaceScanFrameCornerBrackets(size: viewportSize.width)
                        .transition(.opacity)
                }

                if showsScanRing, !scanBlockedByLighting {
                    scannerOverlay(viewportSize: viewportSize)
                        .transition(
                            usesOnboardingFaceOval
                                ? .opacity.combined(with: .scale(scale: 0.972))
                                : .opacity
                        )
                }
            } else {
                unsupportedSection
                    .frame(width: viewportSize.width, height: viewportSize.height)
            }
        }
        .frame(width: viewportSize.width, height: viewportSize.height)
        .frame(
            width: usesOnboardingFaceOval
                ? viewportSize.width + FaceScanViewportMetrics.onboardingTickOverflow
                : viewportSize.width,
            height: usesOnboardingFaceOval
                ? viewportSize.height + FaceScanViewportMetrics.onboardingTickOverflow
                : viewportSize.height
        )
        .frame(maxWidth: .infinity, alignment: isInlinePreview ? .leading : .center)
        .animation(phase == .completed || usesOnboardingFaceOval ? nil : .interpolatingSpring(duration: isInlineHome ? 0.62 : 0.55, bounce: isInlineHome ? 0.14 : 0.08), value: viewportMorph)
        .animation(phase == .completed ? nil : .easeInOut(duration: 0.25), value: phase)
        .animation(phase == .completed ? nil : .easeInOut(duration: 0.2), value: showsFrameCorners)
        .animation(
            phase == .completed
                ? nil
                : (usesOnboardingFaceOval
                    ? .spring(response: 0.44, dampingFraction: 0.84)
                    : .easeInOut(duration: 0.2)),
            value: showsScanRing
        )
        .animation(
            phase == .completed ? nil : .spring(response: 0.44, dampingFraction: 0.84),
            value: showsOnboardingScanCalibrationChrome
        )

        return Group {
            if isInlinePreview {
                core
            } else if let matchedCameraID, let matchedCameraNamespace {
                core.matchedGeometryEffect(id: matchedCameraID, in: matchedCameraNamespace)
            } else {
                core
            }
        }
    }

    @ViewBuilder
    private func scannerOverlay(viewportSize: CGSize) -> some View {
        ZStack {
            if usesOnboardingFaceOval {
                FaceIDOnboardingTickProgressRing(
                    activeSectors: activeTickSectors,
                    waveSector: currentTickSector,
                    ovalSize: viewportSize,
                    isComplete: phase == .completed,
                    isLightBackdrop: onboardingUsesLightChrome
                )
                .transition(.opacity)
            } else if phase == .completed {
                FaceIDSuccessRing(diameter: min(viewportSize.width, viewportSize.height))
                    .transition(.scale.combined(with: .opacity))
            } else if overlayMode == .tiltHold {
                FaceIDTiltHoldRing(
                    progress: tiltHoldProgress,
                    cameraDiameter: viewportSize.width,
                    isEngaged: tiltIsEngaged,
                    isLightBackdrop: isFlashEnabled
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

                FaceScanTiltArrowHint(
                    direction: tiltDirection,
                    cameraDiameter: viewportSize.width,
                    isEngaged: tiltIsEngaged,
                    isLightBackdrop: isFlashEnabled
                )
                .transition(.opacity)
            } else {
                FaceIDTickProgressRing(
                    activeSectors: activeTickSectors,
                    cameraDiameter: viewportSize.width,
                    isLightBackdrop: isFlashEnabled
                )
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.38), value: overlayMode)
        .animation(.smooth(duration: 0.34), value: tiltHoldProgress)
        .animation(.smooth(duration: 0.28), value: tiltIsEngaged)
    }

    // MARK: - Copy

    private var instructionBlock: some View {
        Text(instruction)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.88) : OnboardingTheme.primaryText)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .animation(.easeInOut(duration: 0.2), value: instruction)
    }

    @ViewBuilder
    private var flashStatusLabel: some View {
        if phase != .completed, isDeviceSupported {
            if isFlashEnabled {
                Label(
                    userFlashOverride ? AppCopy.t("Flash activé", en: "Flash on") : AppCopy.t("Flash auto — environnement sombre", en: "Auto flash — low light"),
                    systemImage: "bolt.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.55) : .yellow)
            } else if isLowLight {
                Label(AppCopy.t("Environnement sombre — active le flash", en: "Low light — turn on flash"), systemImage: "moon.fill")
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
                Text(AppCopy.t("Importer photo ou vidéo", en: "Import photo or video"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.82) : OnboardingTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .processGlassButton(in: Capsule())
        .disabled(isImportingMedia)
        .opacity(isImportingMedia ? 0.55 : 1)
    }

    @ViewBuilder
    private var retryScanButton: some View {
        if isDeviceSupported, scanProgress > 0.02, scanProgress < 1 {
            Button(action: restartScan) {
                Text(AppCopy.t("Recommencer le scan", en: "Restart scan"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.55) : OnboardingTheme.mutedText)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.processPlain)
        }
    }

    /// Overlay import — même hero circulaire + balayage que l’écran d’analyse.
    private var mediaImportAnalysisOverlay: some View {
        ZStack {
            FaceScanWhoopPalette.canvas.ignoresSafeArea()

            VStack(spacing: 28) {
                Text(AppCopy.t("ANALYSE DU SCAN", en: "SCAN ANALYSIS"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.label)
                    .tracking(0.6)

                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 240, height: 240)
                        .overlay {
                            Group {
                                if let importingPreviewImage {
                                    Image(uiImage: importingPreviewImage)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ProgressView()
                                        .tint(.white)
                                        .controlSize(.large)
                                }
                            }
                            .frame(width: 240, height: 240)
                            .clipShape(Circle())
                        }
                        .overlay {
                            FaceScanAnalysisSweepOverlay(diameter: 240)
                                .frame(width: 240, height: 240)
                                .clipShape(Circle())
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1.5)
                        }
                }

                Text(AppCopy.t("Analyse du média…", en: "Analyzing media…"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FaceScanWhoopPalette.secondary)
            }
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }

    /// Capture live (mesh 3D) ou import galerie (photo/vidéo + markers, sans mesh).
    private var hasReadyCapture: Bool {
        guard let payload = capturedPayload else { return false }
        if payload.mesh.isValid { return true }
        return payload.snapshot != nil && capturedMarkers != nil
    }

    @ViewBuilder
    private var bottomAction: some View {
        if phase == .completed, hasReadyCapture {
            FaceIDContinueButton {
                submitCapturedScan()
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else if canSkipScan, isEmbedded {
            // Plein écran : le skip est déjà sous « Recommencer le scan ».
            skipScanButton
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @MainActor
    private func submitCapturedScan() {
        guard !hasSubmittedCapture else { return }
        guard let payload = capturedPayload, hasReadyCapture else { return }

        hasSubmittedCapture = true
        captureSessionPaused = true

        let markers = capturedMarkers ?? FaceWellnessAnalyzer.analyze(from: payload)
        capturedMarkers = markers

        HapticManager.shared.impact(.medium)
        FaceScanScreenFlash.shared.deactivate()
        onContinue(payload, markers)
    }

    @ViewBuilder
    private var skipScanButton: some View {
        if let onSkip {
            Button(action: {
                HapticManager.shared.impact(.light)
                FaceScanScreenFlash.shared.deactivate()
                onSkip()
            }) {
                Text(skipButtonTitle)
                    .font(.system(
                        size: isEmbedded && compactSkipAction ? 13 : 16,
                        weight: isEmbedded && compactSkipAction ? .regular : .semibold
                    ))
                    .foregroundStyle(skipScanButtonForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: isEmbedded && compactSkipAction ? nil : 50)
                    .padding(.vertical, isEmbedded && compactSkipAction ? 6 : 0)
            }
            .buttonStyle(.processPlain)
            .modifier(SkipScanButtonChromeModifier(
                compact: isEmbedded && compactSkipAction,
                isFlashEnabled: isFlashEnabled
            ))
        }
    }

    private var skipScanButtonForeground: Color {
        if isEmbedded && compactSkipAction {
            return OnboardingTheme.mutedText.opacity(isFlashEnabled ? 0.62 : 0.52)
        }
        if isFlashEnabled {
            return Color.black.opacity(0.82)
        }
        return OnboardingTheme.primaryText
    }

    private var unsupportedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "faceid")
                .font(.system(size: 48))
                .foregroundStyle(OnboardingTheme.mutedText)
            Text(AppCopy.t("Caméra avant requise", en: "Front camera required"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
            Text(
                showsMediaImport
                    ? AppCopy.t("Utilise un appareil avec Face ID\n(iPhone ou iPad Pro), ou importe une photo / vidéo.", en: "Use a Face ID device\n(iPhone or iPad Pro), or import a photo / video.")
                    : AppCopy.t("Utilise un appareil avec Face ID\n(iPhone ou iPad Pro).", en: "Use a Face ID device\n(iPhone or iPad Pro).")
            )
                .font(.system(size: 15))
                .foregroundStyle(OnboardingTheme.footnoteText)
                .multilineTextAlignment(.center)
            if showsMediaImport {
                importMediaButton
                    .padding(.top, 4)
            }
            skipScanButton
                .padding(.top, 8)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions

    @MainActor
    private func handleCapture(_ payload: FaceScanCapturePayload) {
        guard !hasSubmittedCapture else { return }
        guard payload.mesh.isValid else { return }

        captureSessionPaused = true
        capturedPayload = payload
        capturedMarkers = FaceWellnessAnalyzer.analyze(from: payload)

        FaceScanScreenFlash.shared.deactivate(animated: false)
        isFlashEnabled = false
        phase = .completed

        if usesOnboardingFaceOval {
            submitCapturedScan()
        } else {
            HapticManager.shared.notification(.success)
        }
    }

    private func importImage(_ image: UIImage) {
        importingPreviewImage = image
        withAnimation(.easeInOut(duration: 0.22)) {
            isImportingMedia = true
        }
        Task { @MainActor in
            do {
                let result = try await FaceScanMediaImport.process(image: image)
                // Garde l’overlay analyse jusqu’à l’écran suivant (évite un flash caméra).
                submitImportedMedia(result.0, markers: result.1)
            } catch {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isImportingMedia = false
                }
                importingPreviewImage = nil
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func importVideo(from url: URL) {
        importingPreviewImage = nil
        withAnimation(.easeInOut(duration: 0.22)) {
            isImportingMedia = true
        }
        Task { @MainActor in
            defer {
                try? FileManager.default.removeItem(at: url)
            }
            do {
                let result = try await FaceScanMediaImport.process(videoSourceURL: url)
                importingPreviewImage = result.0.snapshot
                try? await Task.sleep(for: .milliseconds(420))
                submitImportedMedia(result.0, markers: result.1)
            } catch {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isImportingMedia = false
                }
                importingPreviewImage = nil
                importErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func submitImportedMedia(_ payload: FaceScanCapturePayload, markers: FaceWellnessMarkers) {
        guard !hasSubmittedCapture else { return }
        capturedPayload = payload
        capturedMarkers = markers
        captureSessionPaused = true
        FaceScanScreenFlash.shared.deactivate(animated: true)
        isFlashEnabled = false
        HapticManager.shared.notification(.success)
        phase = .completed
        // Import sans mesh 3D : enchaîne tout de suite l’analyse (évite l’écran bloqué).
        submitCapturedScan()
    }

    private func restartScan() {
        if isInlineHome {
            inlineMeshResetNonce += 1
        } else {
            scanSessionID = UUID()
        }
        resetCaptureState(instruction: AppCopy.t("Place ton visage dans le cadre.", en: "Place your face in the frame."))
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .positioning
        }
    }

    private func resetInlinePreviewState() {
        FaceScanScreenFlash.shared.deactivate()
        userFlashOverride = false
        isFlashEnabled = false
        resetCaptureState(instruction: "")
    }

    private func resetCaptureState(instruction: String) {
        hasSubmittedCapture = false
        captureSessionPaused = false
        isImportingMedia = false
        importingPreviewImage = nil
        scanProgress = 0
        ringProgress = 0
        activeTickSectors = []
        currentTickSector = -1
        overlayMode = .orbitTicks
        tiltHoldProgress = 0
        tiltDirection = .none
        tiltIsEngaged = false
        isFaceDetected = false
        frameHint = nil
        self.instruction = instruction
        capturedPayload = nil
        capturedMarkers = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .positioning
        }
    }
}

private struct SkipScanButtonChromeModifier: ViewModifier {
    let compact: Bool
    let isFlashEnabled: Bool

    func body(content: Content) -> some View {
        if compact {
            content
        } else {
            content
                .processGlassButton(in: Capsule())
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
                .contentShape(Circle())
        }
        .glassCircleStyle()
        .accessibilityLabel(isEnabled ? AppCopy.t("Désactiver le flash écran", en: "Turn screen flash off") : AppCopy.t("Activer le flash écran", en: "Turn screen flash on"))
    }

    private var iconColor: Color {
        isEnabled ? Color(red: 0.95, green: 0.78, blue: 0.12) : OnboardingTheme.bodyText
    }
}
