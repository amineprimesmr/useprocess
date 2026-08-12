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
    @ObservedObject private var creatorMode = ProcessCreatorModeStore.shared
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
        static let cardPadding: CGFloat = 12
        static let mediaSidePadding: CGFloat = 12
        static let mediaSideSpacing: CGFloat = 5
        static let blockSpacing: CGFloat = 8
        static let videoTrailingRadius: CGFloat = 18
        static let inlineControlsHeight: CGFloat = 196
        static let scanRingOverflow: CGFloat = FaceScanViewportMetrics.tickRingOverflow
        static let scanAvailableHeight: CGFloat = 112
        static let postScanCardHeight: CGFloat = 164
        static let postScanFooterHeight: CGFloat = 54
    }

    /// Cadence réelle uniquement — après Continuer, on affiche le commentaire visage + photo + Prochain scan.
    private var effectiveScanDue: Bool {
        isScanDue
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
        isFirstScanPending || effectiveScanDue
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
                        .contentShape(cardShape)
                }
                .buttonStyle(.processPlain)
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
            showsMediaImport: creatorMode.allowsPhotoImport,
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
        VStack(alignment: .leading, spacing: 10) {
            Text(scanAvailableTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(3)
                .minimumScaleFactor(0.92)
                .fixedSize(horizontal: false, vertical: true)

            scanAvailableButton
        }
        .padding(Layout.mediaSidePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private let videoWidthRatio: CGFloat = 0.36

    private var scanAvailableTitle: String {
        if isFirstScanPending {
            return AppCopy.t("Premier scan disponible", en: "First scan available")
        }
        return AppCopy.t("Scan du jour disponible", en: "Today's scan available")
    }

    @ViewBuilder
    private var scanAvailableButton: some View {
        Button(action: beginInlineScan) {
            Label(AppCopy.t("Faire mon scan", en: "Start my scan"), systemImage: "camera.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .processGlassButton(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel(AppCopy.t("Faire mon scan", en: "Start my scan"))
    }

    @ViewBuilder
    private var postScanCardContent: some View {
        HStack(alignment: .top, spacing: 0) {
            if showsMediaColumn {
                videoSidePanel(spansFullCardHeight: true)
                    .frame(width: postScanVideoWidth)
            }

            VStack(alignment: .leading, spacing: 0) {
                postScanInfoColumn
                nextScanFooterBand
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: Layout.postScanCardHeight)
        .contentShape(cardShape)
        .contextMenu {
            faceScanDisplayMenu
        }
    }

    private var postScanVideoWidth: CGFloat {
        let cardWidth = UIScreen.main.bounds.width - (PlanHomeSectionDesign.homeScrollPadding * 2)
        return min(max(112, cardWidth * videoWidthRatio), cardWidth * 0.42)
    }

    @ViewBuilder
    private var postScanInfoColumn: some View {
        Group {
            if showsMediaColumn {
                postScanMediaSideInfo
            } else {
                postScanCompactInfo
            }
        }
        .padding(.horizontal, Layout.mediaSidePadding)
        .padding(.top, Layout.mediaSidePadding)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var postScanMediaSideInfo: some View {
        if let latest {
            let appreciation = FaceWellnessScore.appreciation(for: latest)
            VStack(alignment: .leading, spacing: 6) {
                Text(appreciation.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)

                lastScanScoreLabel(score: latest.displayWellnessScore)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var postScanCompactInfo: some View {
        if let latest {
            let appreciation = FaceWellnessScore.appreciation(for: latest)
            HStack(alignment: .top, spacing: 10) {
                compactLeadingIcon

                VStack(alignment: .leading, spacing: 6) {
                    Text(appreciation.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .fixedSize(horizontal: false, vertical: true)

                    lastScanScoreLabel(score: latest.displayWellnessScore)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func lastScanScoreLabel(score: Int) -> some View {
        Text(score > 0 ? "\(score)%" : "—")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(theme.secondaryText)
            .monospacedDigit()
            .accessibilityLabel(
                score > 0
                    ? AppCopy.t("Score du scan \(score) pour cent", en: "Scan score \(score) percent")
                    : AppCopy.t("Score du scan indisponible", en: "Scan score unavailable")
            )
    }

    private var nextScanFooterBand: some View {
        PlanHomePeriodicTicker(isActive: isPlanActive) { now in
            PlanFaceScanNextScanFooter(
                latest: latest,
                isScanDue: isScanDue,
                now: now,
                theme: theme,
                isCompact: true
            )
        }
        .padding(.horizontal, Layout.mediaSidePadding)
        .padding(.bottom, Layout.mediaSidePadding)
        .frame(height: Layout.postScanFooterHeight, alignment: .bottomLeading)
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
                    Label(AppCopy.t("Masquer la vidéo", en: "Hide video"), systemImage: "eye.slash")
                }
            } else {
                Button {
                    HapticManager.shared.selection()
                    displayPreferences.setShowsVideo(true)
                } label: {
                    Label(AppCopy.t("Afficher la vidéo", en: "Show video"), systemImage: "video")
                }
            }

            Button {
                beginInlineScan()
            } label: {
                Label(AppCopy.t("Refaire le scan", en: "Rescan"), systemImage: "camera.fill")
            }
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
    }
}

// MARK: - Bande basse prochain scan

private struct PlanFaceScanNextScanFooter: View {
    let latest: FaceScanResult?
    let isScanDue: Bool
    let now: Date
    let theme: AppTheme
    var isCompact: Bool = false

    private var progress: Double {
        guard let latest else { return 0 }
        return FaceScanCadence.intervalProgress(since: latest.createdAt, now: now)
    }

    private var headline: String {
        if latest == nil { return AppCopy.t("Premier scan", en: "First scan") }
        if isScanDue { return AppCopy.t("Scan disponible", en: "Scan available") }
        return AppCopy.t("Prochain scan", en: "Next scan")
    }

    private var trailingLabel: String {
        if latest == nil { return AppCopy.t("À faire", en: "To do") }
        if isScanDue { return AppCopy.t("Maintenant", en: "Now") }
        return FaceScanCadence.countdownLabel(since: latest?.createdAt, now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(headline)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(trailingLabel)
                    .font(.system(size: isCompact ? 18 : 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(countdownColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            PlanFaceScanProgressBar(
                progress: progress,
                isComplete: latest != nil && isScanDue,
                isPending: latest == nil,
                theme: theme,
                barHeight: isCompact ? 10 : 11
            )
        }
    }

    private var countdownColor: Color {
        if isScanDue { return theme.onboardingAccent }
        return theme.primaryText
    }
}

private struct PlanFaceScanProgressBar: View {
    let progress: Double
    let isComplete: Bool
    let isPending: Bool
    let theme: AppTheme
    var barHeight: CGFloat = 10

    private var fillProgress: Double {
        if isPending { return 0 }
        if isComplete { return 1 }
        return min(1, max(0, progress))
    }

    private var fillColor: Color {
        if isComplete { return theme.onboardingAccent }
        return theme.primaryText.opacity(theme.isDark ? 0.88 : 0.82)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = max(fillProgress > 0 ? 6 : 0, width * fillProgress)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(theme.isDark ? 0.18 : 0.08))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(theme.isDark ? 0.12 : 0.06), lineWidth: 0.5)
                    }

                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(width: fillWidth)
                    .shadow(color: fillColor.opacity(isComplete ? 0.35 : 0.12), radius: isComplete ? 4 : 2, y: 1)

                if isComplete {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.trailing, 5)
                    }
                }
            }
        }
        .frame(height: barHeight)
        .animation(.easeInOut(duration: 0.35), value: fillProgress)
    }
}

private struct PlanFaceScanMediaPanel: View, Equatable {
    let result: FaceScanResult
    var isPlaybackActive: Bool = true

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.result.id == rhs.result.id
            && lhs.result.videoFilename == rhs.result.videoFilename
            && lhs.result.snapshotFilename == rhs.result.snapshotFilename
            && lhs.result.studioFraming == rhs.result.studioFraming
            && lhs.result.displayWellnessScore == rhs.result.displayWellnessScore
            && lhs.isPlaybackActive == rhs.isPlaybackActive
    }

    var body: some View {
        FaceScanRecordingMediaView(
            result: result,
            displayMode: .sidePanel,
            isPlaybackActive: isPlaybackActive
        )
        .accessibilityLabel(AppCopy.t("Vidéo du dernier scan", en: "Latest scan video"))
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
                liveCameraPlaceholder(systemImage: "camera.fill", message: AppCopy.t("Caméra refusée", en: "Camera denied"))
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
        .accessibilityLabel(AppCopy.t("Aperçu caméra frontale", en: "Front camera preview"))
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


