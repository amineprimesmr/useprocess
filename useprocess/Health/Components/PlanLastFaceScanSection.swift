import AVFoundation
import SwiftUI

/// Résumé scan visage — page Plan (liquid glass, aligné cartes repas).
struct PlanLastFaceScanSection: View {
    let latest: FaceScanResult?
    let isScanDue: Bool
    var isScanFlowActive: Bool = false
    var zoomNamespace: Namespace.ID? = nil
    var onScan: (() -> Void)? = nil
    var onOpenHistory: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var displayPreferences = PlanHomeFaceScanDisplayPreferences.shared

    private let videoWidthRatio: CGFloat = 0.38
    private let cardRadius: CGFloat = 30

    private enum Layout {
        static let cardPadding: CGFloat = 16
        static let topMinHeight: CGFloat = 118
        static let scanAvailableHeight: CGFloat = 118
        static let footerVerticalPadding: CGFloat = 14
        static let blockSpacing: CGFloat = 8
        static let videoTrailingRadius: CGFloat = 18
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
        return onOpenHistory != nil || onScan != nil
    }

    private var showsMediaColumn: Bool {
        if needsLiveCameraPreview {
            return true
        }
        return latest != nil && displayPreferences.showsVideo
    }

    private var livePreviewActive: Bool {
        needsLiveCameraPreview && !isScanFlowActive
    }

    var body: some View {
        Group {
            if isScanAvailable {
                scanAvailableContent
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
                .processGlassEffect(in: cardShape, interactive: isInteractive)
        }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .processZoomSource(id: .faceScanHistory, namespace: zoomNamespace)
        .onAppear {
            displayPreferences.reload()
        }
    }

    private func handlePrimaryTap() {
        openHistory()
    }

    private func openHistory() {
        HapticManager.shared.impact(.light)
        onOpenHistory?()
    }

    @ViewBuilder
    private var scanAvailableContent: some View {
        GeometryReader { geo in
            let videoWidth = min(max(118, geo.size.width * videoWidthRatio), geo.size.width * 0.44)

            HStack(alignment: .center, spacing: 0) {
                videoSidePanel
                    .frame(width: videoWidth, height: Layout.scanAvailableHeight, alignment: .topLeading)

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
            .frame(maxWidth: .infinity, minHeight: Layout.scanAvailableHeight, alignment: .leading)
        }
        .frame(height: Layout.scanAvailableHeight)
        .contentShape(cardShape)
    }

    private var scanAvailableTitle: String {
        if isFirstScanPending {
            return "Premier scan disponible"
        }
        return "Scan du jour disponible"
    }

    @ViewBuilder
    private var scanAvailableButton: some View {
        if let onScan {
            Button {
                HapticManager.shared.impact(.medium)
                onScan()
            } label: {
                Label("Faire mon scan", systemImage: "camera.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .processGlassButton(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityLabel("Faire mon scan")
        }
    }

    @ViewBuilder
    private var postScanCardContent: some View {
        VStack(spacing: 0) {
            topSection
            nextScanFooterBand
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: showsMediaColumn)
        .contentShape(cardShape)
        .contextMenu {
            faceScanDisplayMenu
        }
    }

    private var topSection: some View {
        GeometryReader { geo in
            let videoWidth = min(max(118, geo.size.width * videoWidthRatio), geo.size.width * 0.44)

            HStack(alignment: .top, spacing: 0) {
                if showsMediaColumn {
                    videoSidePanel
                        .frame(width: videoWidth, height: Layout.topMinHeight, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: Layout.blockSpacing) {
                    if !showsMediaColumn {
                        HStack(spacing: 10) {
                            compactLeadingIcon
                            scanCardHeader
                        }
                    } else {
                        scanCardHeader
                    }

                    Text(preScanActionMessage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
                .padding(Layout.cardPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: Layout.topMinHeight, alignment: .leading)
        }
        .frame(height: Layout.topMinHeight)
    }

    private var scanCardHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("Dernier scan")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Spacer(minLength: 8)

            if let latest {
                ReadinessScoreMiniBadge(score: latest.resolvedFaceDayScore)
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
            stepsToday: healthManager.todaySnapshot.effort.steps,
            stepTarget: targets.dailySteps,
            waterLitersToday: healthManager.todaySnapshot.nutrition.waterLiters,
            waterTargetLiters: targets.hydrationLitersPerDay
        )
    }

    private var nextScanFooterBand: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            PlanFaceScanNextScanFooter(
                latest: latest,
                isScanDue: isScanDue,
                now: context.date,
                theme: theme
            )
        }
        .padding(.horizontal, Layout.cardPadding)
        .padding(.vertical, Layout.footerVerticalPadding)
    }

    private var videoPanelShape: UnevenRoundedRectangle {
        let bottomLeadingRadius = isScanAvailable ? cardRadius : 0
        return UnevenRoundedRectangle(
            topLeadingRadius: cardRadius,
            bottomLeadingRadius: bottomLeadingRadius,
            bottomTrailingRadius: Layout.videoTrailingRadius,
            topTrailingRadius: Layout.videoTrailingRadius,
            style: .continuous
        )
    }

    private var videoSidePanel: some View {
        ZStack(alignment: .leading) {
            if needsLiveCameraPreview {
                PlanFaceScanLiveCameraPanel(isActive: livePreviewActive)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let latest {
                PlanFaceScanMediaPanel(result: latest)
                    .equatable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [
                        .clear,
                        videoScrimColor.opacity(0.30),
                        videoScrimColor.opacity(0.90)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 52)
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(videoPanelShape)
    }

    private var videoScrimColor: Color {
        theme.isDark ? .black : .white
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

private struct PlanFaceScanNextScanFooter: View {
    let latest: FaceScanResult?
    let isScanDue: Bool
    let now: Date
    let theme: AppTheme

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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(trailingColor)
                    .frame(width: 22, height: 22)
                    .background(trailingColor.opacity(0.14), in: Circle())

                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Spacer(minLength: 8)

                Text(trailingLabel)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(trailingColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(trailingColor.opacity(0.12), in: Capsule())
            }

            PlanFaceScanProgressBar(
                progress: progress,
                isComplete: latest != nil && isScanDue,
                isPending: latest == nil,
                accent: theme.onboardingAccent,
                track: Color.primary.opacity(theme.isDark ? 0.22 : 0.10)
            )
        }
    }

    private var trailingColor: Color {
        if latest == nil { return .orange }
        if isScanDue { return theme.onboardingAccent }
        return theme.secondaryText
    }
}

private struct PlanFaceScanProgressBar: View {
    let progress: Double
    let isComplete: Bool
    let isPending: Bool
    let accent: Color
    let track: Color

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
                    .animation(.spring(response: 0.55, dampingFraction: 0.82), value: fillProgress)

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
        .frame(height: 11)
    }
}

private struct PlanFaceScanMediaPanel: View, Equatable {
    let result: FaceScanResult

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.result.id == rhs.result.id
            && lhs.result.videoFilename == rhs.result.videoFilename
            && lhs.result.snapshotFilename == rhs.result.snapshotFilename
    }

    var body: some View {
        FaceScanRecordingMediaView(
            result: result,
            displayMode: .sidePanel
        )
        .accessibilityLabel("Vidéo du dernier scan")
    }
}

// MARK: - Aperçu caméra frontale (premier scan)

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

