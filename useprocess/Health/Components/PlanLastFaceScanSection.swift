import AVFoundation
import SwiftUI

/// Résumé scan visage — page Plan (liquid glass, aligné cartes repas).
struct PlanLastFaceScanSection: View {
    let latest: FaceScanResult?
    let isScanDue: Bool
    @Binding var isScanFlowActive: Bool
    var isPlanActive: Bool = true
    var healthMetrics: PlanHomeHealthMetrics = PlanHomeHealthMetrics()
    var zoomNamespace: Namespace.ID? = nil
    var onScan: (() -> Void)? = nil
    var onScanComplete: ((FaceScanResult) -> Void)? = nil

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var displayPreferences = PlanHomeFaceScanDisplayPreferences.shared

    @State private var analysisSession: InlineFaceScanAnalysisSession?
    @State private var latestAnalysisScan: FaceScanResult?

    private struct InlineFaceScanAnalysisSession: Identifiable {
        let id = UUID()
        let payload: FaceScanCapturePayload
        let markers: FaceWellnessMarkers
    }

    private let cardRadius: CGFloat = 30

    private enum Layout {
        static let cardPadding: CGFloat = 16
        static let topMinHeight: CGFloat = 118
        static let postScanTopMinHeight: CGFloat = 92
        static let scanAvailableHeight: CGFloat = 118
        static let footerVerticalPadding: CGFloat = 14
        static let postScanFooterVerticalPadding: CGFloat = 10
        static let blockSpacing: CGFloat = 8
        static let videoTrailingRadius: CGFloat = 18
        static let inlineControlsHeight: CGFloat = 136
        static let scanRingOverflow: CGFloat = FaceScanViewportMetrics.tickRingOverflow
        static let postScanFooterContentHeight: CGFloat = 58
    }

    private var isPostScanComplete: Bool {
        latest != nil && !isScanDue
    }

    private func inlineViewportDiameter(for cardWidth: CGFloat) -> CGFloat {
        let contentWidth = cardWidth - (Layout.cardPadding * 2)
        let maxDiameter = contentWidth - Layout.scanRingOverflow - 4
        return min(max(maxDiameter, 220), 320)
    }

    private func expandedScanSectionHeight(viewportDiameter: CGFloat) -> CGFloat {
        let cameraBlock = viewportDiameter + Layout.scanRingOverflow
        return cameraBlock + Layout.inlineControlsHeight + (Layout.cardPadding * 2)
    }

    private var isFirstScanPending: Bool {
        latest == nil
    }

    private var needsLiveCameraPreview: Bool {
        isFirstScanPending || isScanDue
    }

    private var isScanAvailable: Bool {
        needsLiveCameraPreview
    }

    private var isInteractive: Bool {
        if isScanAvailable {
            return false
        }
        return latest != nil
    }

    private var showsMediaColumn: Bool {
        if needsLiveCameraPreview {
            return true
        }
        return latest != nil && displayPreferences.showsVideo
    }

    private var livePreviewActive: Bool {
        isPlanActive && needsLiveCameraPreview && !isScanFlowActive && !showsUnifiedScanCard
    }

    private var isMediaPlaybackActive: Bool {
        isPlanActive && latest != nil && displayPreferences.showsVideo && !needsLiveCameraPreview
    }

    private var showsUnifiedScanCard: Bool {
        isScanAvailable || isScanFlowActive
    }

    var body: some View {
        Group {
            if showsUnifiedScanCard {
                unifiedScanDueCard
            } else if isInteractive {
                Button(action: handlePrimaryTap) {
                    postScanCardContent
                }
                .buttonStyle(.plain)
            } else {
                postScanCardContent
            }
        }
        .background {
            cardShape
                .fill(.clear)
                .processGlassEffect(
                    in: cardShape,
                    interactive: isInteractive && !isScanFlowActive
                )
        }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .processZoomSource(id: .faceScanHistory, namespace: zoomNamespace)
        .animation(.spring(response: 0.56, dampingFraction: 0.84), value: isScanFlowActive)
        .onAppear {
            displayPreferences.reload()
        }
        .fullScreenCover(item: $analysisSession) { session in
            FaceScanAnalysisFlowView(
                payload: session.payload,
                markers: session.markers,
                profile: profileService.currentProfile,
                onDismiss: {
                    analysisSession = nil
                },
                onComplete: { result in
                    FaceScanHistoryStore.shared.reloadForUser(userId: profileService.currentProfile?.userId)
                    onScanComplete?(result)
                }
            )
        }
        .fullScreenCover(item: $latestAnalysisScan) { scan in
            latestAnalysisCover(for: scan)
        }
    }

    @MainActor
    private func openLatestScanAnalysis() {
        guard latest != nil else { return }
        HapticManager.shared.impact(.light)
        latestAnalysisScan = latest
    }

    private func handlePrimaryTap() {
        openLatestScanAnalysis()
    }

    @ViewBuilder
    private func latestAnalysisCover(for scan: FaceScanResult) -> some View {
        let store = FaceScanHistoryStore.shared
        let content = FaceScanResultContent(
            result: scan,
            previous: store.previousResult,
            history: store.history
        )

        if let zoomNamespace {
            content.processZoomTransition(id: .faceScanHistory, namespace: zoomNamespace)
        } else {
            content
        }
    }

    @ViewBuilder
    private var unifiedScanDueCard: some View {
        GeometryReader { geo in
            let compactVideoWidth = min(118, geo.size.width * videoWidthRatio)
            let expanded = isScanFlowActive
            let viewportDiameter = expanded
                ? inlineViewportDiameter(for: geo.size.width)
                : compactVideoWidth
            let sectionHeight = expanded
                ? expandedScanSectionHeight(viewportDiameter: viewportDiameter)
                : Layout.scanAvailableHeight

            ZStack(alignment: .topLeading) {
                inlineScanCaptureLayer(
                    expanded: expanded,
                    compactVideoWidth: compactVideoWidth,
                    viewportDiameter: viewportDiameter,
                    sectionHeight: sectionHeight
                )

                if !expanded {
                    HStack(spacing: 0) {
                        Spacer(minLength: compactVideoWidth)
                        compactScanDueTrailingColumnContent
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: unifiedScanCardHeight)
        .clipped()
    }

    private var unifiedScanCardHeight: CGFloat {
        if isScanFlowActive {
            let cardWidth = UIScreen.main.bounds.width - (PlanHomeSectionDesign.homeScrollPadding * 2)
            let viewport = inlineViewportDiameter(for: cardWidth)
            return expandedScanSectionHeight(viewportDiameter: viewport)
        }
        return Layout.scanAvailableHeight
    }

    private func inlineScanCaptureLayer(
        expanded: Bool,
        compactVideoWidth: CGFloat,
        viewportDiameter: CGFloat,
        sectionHeight: CGFloat
    ) -> some View {
        FaceScanCaptureScreen(
            presentation: .inlineHome(
                viewportDiameter: expanded ? viewportDiameter : compactVideoWidth,
                phase: expanded ? .active : .preview
            ),
            showsInlineHeader: false,
            onBack: closeInlineScan,
            allowsScreenFlash: expanded,
            isCameraSessionActive: isPlanActive,
            onContinue: { payload, markers in
                withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                    isScanFlowActive = false
                }
                analysisSession = InlineFaceScanAnalysisSession(payload: payload, markers: markers)
            }
        )
        .id("plan-inline-face-scan")
        .frame(
            width: expanded ? nil : compactVideoWidth,
            height: expanded ? nil : Layout.scanAvailableHeight,
            alignment: .topLeading
        )
        .frame(
            maxWidth: expanded ? .infinity : compactVideoWidth,
            maxHeight: expanded ? sectionHeight : Layout.scanAvailableHeight,
            alignment: .topLeading
        )
        .clipShape(UnifiedScanCameraClipShape(expanded: expanded, cardRadius: cardRadius))
        .padding(.horizontal, expanded ? Layout.cardPadding : 0)
        .padding(.top, expanded ? Layout.cardPadding : 0)
        .padding(.bottom, expanded ? Layout.cardPadding : 0)
    }

    private var compactScanDueTrailingColumnContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scanAvailableTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            scanAvailableButton
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @MainActor
    private func closeInlineScan() {
        FaceScanScreenFlash.shared.deactivate()
        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
            isScanFlowActive = false
        }
    }

    private func beginInlineScan() {
        if !ProcessPrivacyConsentStore.shared.canCaptureFaceScan {
            ProcessPrivacyConsentStore.shared.acceptFaceScanCapture()
        }
        HapticManager.shared.impact(.medium)
        withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
            isScanFlowActive = true
        }
        onScan?()
    }

    private let videoWidthRatio: CGFloat = 0.38

    private var scanAvailableTitle: String {
        if isFirstScanPending {
            return "Premier scan disponible"
        }
        return "Scan du jour disponible"
    }

    @ViewBuilder
    private var scanAvailableButton: some View {
        Button(action: beginInlineScan) {
            Label("Faire mon scan", systemImage: "camera.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .processGlassButton(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("Faire mon scan")
    }

    @ViewBuilder
    private var postScanCardContent: some View {
        GeometryReader { geo in
            let videoWidth = showsMediaColumn
                ? min(max(118, geo.size.width * videoWidthRatio), geo.size.width * 0.44)
                : 0

            HStack(alignment: .top, spacing: 0) {
                if showsMediaColumn {
                    videoSidePanel(spansFullCardHeight: true)
                        .frame(width: videoWidth)
                        .frame(maxHeight: .infinity, alignment: .top)
                }

                VStack(alignment: .leading, spacing: 0) {
                    postScanTextColumn
                    nextScanFooterBand
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: postScanCardMinHeight)
        .contentShape(cardShape)
        .contextMenu {
            faceScanDisplayMenu
        }
    }

    private var postScanCardMinHeight: CGFloat {
        let top = isPostScanComplete ? Layout.postScanTopMinHeight : Layout.topMinHeight
        let footerPad = isPostScanComplete ? Layout.postScanFooterVerticalPadding : Layout.footerVerticalPadding
        let footerBody = isPostScanComplete ? Layout.postScanFooterContentHeight : 52
        return top + footerPad * 2 + footerBody
    }

    private var postScanTextColumn: some View {
        VStack(alignment: .leading, spacing: isPostScanComplete ? 0 : Layout.blockSpacing) {
            if !showsMediaColumn {
                HStack(spacing: 10) {
                    compactLeadingIcon
                    scanCardHeader
                }
            } else {
                scanCardHeader
            }

            if !isPostScanComplete {
                Text(preScanActionMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
        }
        .padding(isPostScanComplete ? 12 : Layout.cardPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: isPostScanComplete ? Layout.postScanTopMinHeight : Layout.topMinHeight,
            alignment: .leading
        )
    }

    private var scanCardHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("Dernier scan")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Spacer(minLength: 8)

            if let latest {
                ReadinessScoreMiniBadge(score: latest.displayWellnessScore)
                    .offset(y: -8)
                    .padding(.trailing, -6)
            }
        }
    }

    private var preScanActionMessage: String {
        if isFirstScanPending {
            return "Fais ton premier scan — 30 secondes."
        }
        if isScanDue {
            return "Ton scan du jour est disponible."
        }
        let targets = WelcomePlanStore.shared.plan?.personalizedTargets ?? .default
        return PlanFaceScanPreScanAction.message(
            for: latest,
            stepsToday: healthMetrics.stepsToday,
            stepTarget: targets.dailySteps,
            waterLitersToday: healthMetrics.waterLitersToday,
            waterTargetLiters: targets.hydrationLitersPerDay
        )
    }

    private var nextScanFooterBand: some View {
        PlanHomePeriodicTicker(isActive: isPlanActive) { now in
            PlanFaceScanNextScanFooter(
                latest: latest,
                isScanDue: isScanDue,
                now: now,
                theme: theme,
                isCompact: isPostScanComplete
            )
        }
        .padding(.horizontal, isPostScanComplete ? 12 : Layout.cardPadding)
        .padding(.vertical, isPostScanComplete ? Layout.postScanFooterVerticalPadding : Layout.footerVerticalPadding)
    }

    private func videoPanelShape(spansFullCardHeight: Bool) -> UnevenRoundedRectangle {
        let bottomLeadingRadius = (isScanAvailable || spansFullCardHeight) ? cardRadius : 0
        return UnevenRoundedRectangle(
            topLeadingRadius: cardRadius,
            bottomLeadingRadius: bottomLeadingRadius,
            bottomTrailingRadius: Layout.videoTrailingRadius,
            topTrailingRadius: Layout.videoTrailingRadius,
            style: .continuous
        )
    }

    private func videoSidePanel(spansFullCardHeight: Bool) -> some View {
        ZStack(alignment: .leading) {
            if needsLiveCameraPreview {
                PlanFaceScanLiveCameraPanel(isActive: livePreviewActive)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let latest {
                PlanFaceScanMediaPanel(
                    result: latest,
                    isPlaybackActive: isMediaPlaybackActive
                )
                    .equatable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(videoPanelShape(spansFullCardHeight: spansFullCardHeight))
    }

    private var compactLeadingIcon: some View {
        ZStack {
            Circle()
                .fill(compactIconFill.opacity(0.14))
                .frame(width: 36, height: 36)

            Image(systemName: latest == nil ? "camera.fill" : "face.smiling")
                .font(.body.weight(.semibold))
                .foregroundStyle(compactIconFill)
        }
        .accessibilityHidden(true)
    }

    private var compactIconFill: Color {
        return theme.onboardingAccent
    }

    @ViewBuilder
    private var faceScanDisplayMenu: some View {
        if latest != nil {
            if displayPreferences.showsVideo {
                Button {
                    HapticManager.shared.selection()
                    displayPreferences.setShowsVideo(false)
                } label: {
                    Label("Masquer la vidéo", systemImage: "eye.slash")
                }
            } else {
                Button {
                    HapticManager.shared.selection()
                    displayPreferences.setShowsVideo(true)
                } label: {
                    Label("Afficher la vidéo", systemImage: "video")
                }
            }

            Button {
                beginInlineScan()
            } label: {
                Label("Refaire le scan", systemImage: "camera.fill")
            }
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
    }
}

// MARK: - Messages courts (hydratation / marche — pas de routine)

enum PlanFaceScanPreScanAction {
    static func message(
        for result: FaceScanResult?,
        stepsToday: Int,
        stepTarget: Int,
        waterLitersToday: Double,
        waterTargetLiters: Int
    ) -> String {
        guard result != nil else {
            return "Fais ton premier scan — 30 secondes."
        }

        let waterTarget = max(1, waterTargetLiters)
        let waterGap = max(0, Double(waterTarget) - waterLitersToday)
        let stepsGap = max(0, stepTarget - stepsToday)
        let hydrationTracked = waterLitersToday > 0.05
        let hydrationLow = hydrationTracked && waterLitersToday < Double(waterTarget) * 0.6
        let stepsLow = stepTarget > 0 && stepsToday < Int(Double(stepTarget) * 0.65)

        if hydrationLow {
            if waterGap >= 1 {
                return String(format: "Encore %.1f L d'eau aujourd'hui.", waterGap)
            }
            return "Hydrate plus — il reste de l'eau à boire."
        }

        if stepsLow {
            if stepsGap >= 2500 {
                return "Peu de pas aujourd'hui — bouge un peu plus."
            }
            return "Encore \(formattedSteps(stepsGap)) pas aujourd'hui."
        }

        if !hydrationTracked {
            return "N'oublie pas ton eau — cible \(waterTarget) L."
        }

        if let result, result.markers.puffinessScore >= 62 {
            return "Gonflement visible — l'eau aide à dégonfler."
        }

        return "Bien hydraté et assez actif aujourd'hui."
    }

    private static func formattedSteps(_ value: Int) -> String {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "fr_FR")
        nf.numberStyle = .decimal
        nf.groupingSeparator = " "
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Bande basse prochain scan

enum PlanFaceScanChrome {
    static let luminousBlue = Color(red: 0.26, green: 0.48, blue: 0.84)
}

private struct PlanFaceScanNextScanFooter: View {
    let latest: FaceScanResult?
    let isScanDue: Bool
    let now: Date
    let theme: AppTheme
    var isCompact: Bool = false

    private var rowSpacing: CGFloat { isCompact ? 7 : 10 }
    private var progressBarHeight: CGFloat { isCompact ? 9 : 11 }

    private var progress: Double {
        guard let latest else { return 0 }
        return FaceScanCadence.intervalProgress(since: latest.createdAt, now: now)
    }

    private var headline: String {
        if latest == nil { return "Premier scan" }
        if isScanDue { return "Scan disponible" }
        return "Prochain scan"
    }

    private var trailingLabel: String {
        if latest == nil { return "À faire" }
        if isScanDue { return "Maintenant" }
        return FaceScanCadence.countdownLabel(since: latest?.createdAt, now: now)
    }

    private var statusIcon: String {
        if latest == nil { return "camera.fill" }
        if isScanDue { return "bell.badge.fill" }
        return "clock.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
                    .frame(width: isCompact ? 20 : 22, height: isCompact ? 20 : 22)
                    .background(statusColor.opacity(0.14), in: Circle())

                Text(headline)
                    .font(isCompact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Spacer(minLength: 8)
            }

            Text(trailingLabel)
                .font(isCompact ? .caption.weight(.bold) : .footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(countdownColor)
                .padding(.leading, isCompact ? 28 : 30)

            PlanFaceScanProgressBar(
                progress: progress,
                isComplete: latest != nil && isScanDue,
                isPending: latest == nil,
                accent: PlanFaceScanChrome.luminousBlue,
                track: Color.primary.opacity(theme.isDark ? 0.22 : 0.10),
                barHeight: progressBarHeight
            )
        }
    }

    private var statusColor: Color {
        if latest == nil { return PlanFaceScanChrome.luminousBlue }
        if isScanDue { return theme.onboardingAccent }
        return PlanFaceScanChrome.luminousBlue.opacity(0.88)
    }

    private var countdownColor: Color {
        if isScanDue { return theme.onboardingAccent }
        return PlanFaceScanChrome.luminousBlue
    }
}

private struct PlanFaceScanProgressBar: View {
    let progress: Double
    let isComplete: Bool
    let isPending: Bool
    let accent: Color
    let track: Color
    var barHeight: CGFloat = 11

    private var fillProgress: Double {
        if isPending { return 0 }
        if isComplete { return 1 }
        return min(1, max(0, progress))
    }

    private var fillGradient: LinearGradient {
        if isComplete {
            return LinearGradient(
                colors: [accent, accent.opacity(0.75)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [accent.opacity(0.95), accent.opacity(0.55)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = max(10, width * fillProgress)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(track)

                Capsule(style: .continuous)
                    .fill(fillGradient)
                    .frame(width: fillWidth)

                if isComplete {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.trailing, 6)
                    }
                }
            }
        }
        .frame(height: barHeight)
    }
}

private struct PlanFaceScanMediaPanel: View, Equatable {
    let result: FaceScanResult
    var isPlaybackActive: Bool = true

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.result.id == rhs.result.id
            && lhs.result.videoFilename == rhs.result.videoFilename
            && lhs.result.snapshotFilename == rhs.result.snapshotFilename
            && lhs.isPlaybackActive == rhs.isPlaybackActive
    }

    var body: some View {
        FaceScanRecordingMediaView(
            result: result,
            displayMode: .sidePanel,
            isPlaybackActive: isPlaybackActive
        )
        .accessibilityLabel("Vidéo du dernier scan")
    }
}

// MARK: - Clip caméra scan unifié (compact → plein)

private struct UnifiedScanCameraClipShape: Shape {
    var expanded: Bool
    var cardRadius: CGFloat

    private static let videoTrailingRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        if expanded {
            return Path(rect)
        }
        return UnevenRoundedRectangle(
            topLeadingRadius: cardRadius,
            bottomLeadingRadius: cardRadius,
            bottomTrailingRadius: Self.videoTrailingRadius,
            topTrailingRadius: Self.videoTrailingRadius,
            style: .continuous
        ).path(in: rect)
    }
}

// MARK: - Aperçu caméra frontale (fallback post-scan)

private struct PlanFaceScanLiveCameraPanel: View {
    var isActive: Bool

    @Environment(\.appTheme) private var theme
    @StateObject private var camera = BodyScanCameraService()

    var body: some View {
        Group {
            switch camera.authorizationStatus {
            case .authorized:
                BodyScanCameraPreview(
                    session: camera.session,
                    mirrorFrontCamera: true,
                    isSessionRunning: camera.isRunning
                )
                .background(Color.black)
            case .denied, .restricted:
                liveCameraPlaceholder(systemImage: "camera.fill", message: "Caméra refusée")
            default:
                liveCameraPlaceholder(systemImage: "camera.fill", message: nil)
            }
        }
        .task(id: isActive) {
            guard isActive else {
                camera.stop()
                return
            }
            await startCameraIfNeeded()
        }
        .onDisappear {
            camera.stop()
        }
        .accessibilityLabel("Aperçu caméra frontale")
    }

    private func liveCameraPlaceholder(systemImage: String, message: String?) -> some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.10)

            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.orange.opacity(0.9))

                if let message {
                    Text(message)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    @MainActor
    private func startCameraIfNeeded() async {
        camera.refreshAuthorizationStatus()
        if camera.authorizationStatus == .notDetermined {
            guard await camera.requestAccess() else { return }
        }
        guard camera.authorizationStatus == .authorized else { return }
        camera.start(preferredPosition: .front, deliversFrames: false)
    }
}


