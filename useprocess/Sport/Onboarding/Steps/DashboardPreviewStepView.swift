//
//  DashboardPreviewStepView.swift
//  Process
//
//  Aperçu du dashboard — Accueil / Série / Routine / Scan.
//

import AVFoundation
import SwiftUI

struct DashboardPreviewStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var hasCompletedFirstScan: Bool = false
    var onFirstScanResult: ((FaceScanResult) -> Void)? = nil
    var onFirstScanContinue: (() -> Void)? = nil
    var onBeginFirstScan: (() -> Void)? = nil
    var onFirstScanSkipLater: (() -> Void)? = nil
    var initialScanPersistedState: OnboardingDashboardScanPersistedState? = nil
    var pendingScanResult: FaceScanResult? = nil
    var onScanPersistedStateChange: ((OnboardingDashboardScanPersistedState?) -> Void)? = nil

    @State private var carouselStep = 0
    @State private var didBootstrapPreview = false
    @State private var isScanPageInteractive = false
    @State private var scanExpandProgress: CGFloat = 0
    @State private var revealsPreviewContent = false
    @State private var showsTourChrome = false
    @State private var showsSideCards = false
    @State private var hasSettledCardScale = false
    @State private var entranceTask: Task<Void, Never>?
    @State private var firstScanLaunchTask: Task<Void, Never>?
    @State private var isAdvancingSlide = false
    @State private var embeddedScanResult: FaceScanResult?
    @State private var preservedScanSession: DashboardPreviewScanSessionSnapshot?

    private var slides: [DashboardPreviewSlide] {
        DashboardPreviewSlide.firstScanCatalog
    }

    private let accent = Color(red: 0.0, green: 0.478, blue: 1.0)

    init(
        hasCompletedFirstScan: Bool = false,
        onFirstScanResult: ((FaceScanResult) -> Void)? = nil,
        onFirstScanContinue: (() -> Void)? = nil,
        onBeginFirstScan: (() -> Void)? = nil,
        onFirstScanSkipLater: (() -> Void)? = nil,
        initialScanPersistedState: OnboardingDashboardScanPersistedState? = nil,
        pendingScanResult: FaceScanResult? = nil,
        onScanPersistedStateChange: ((OnboardingDashboardScanPersistedState?) -> Void)? = nil
    ) {
        self.hasCompletedFirstScan = hasCompletedFirstScan
        self.onFirstScanResult = onFirstScanResult
        self.onFirstScanContinue = onFirstScanContinue
        self.onBeginFirstScan = onBeginFirstScan
        self.onFirstScanSkipLater = onFirstScanSkipLater
        self.initialScanPersistedState = initialScanPersistedState
        self.pendingScanResult = pendingScanResult
        self.onScanPersistedStateChange = onScanPersistedStateChange
        PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
    }

    private var logicalSlideIndex: Int {
        carouselStep % slides.count
    }

    private var isLastSlide: Bool {
        logicalSlideIndex >= slides.count - 1
    }

    var body: some View {
        ZStack {
            tourOrHiddenBackground
            resultsOverlay
            if isScanPageInteractive, embeddedScanResult == nil {
                interactiveScanOverlay
                    .transition(.opacity)
                    .zIndex(80)
            }
        }
        .animation(OnboardingScanFlowMotion.animation, value: embeddedScanResult?.id)
        .animation(.easeInOut(duration: 0.2), value: isScanPageInteractive)
        .environment(\.onboardingDashboardScanSession, dashboardFirstScanSession)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            restorePersistedSessionIfNeeded()
            bootstrapPreviewIfNeeded()
            startEntranceIfNeeded()
        }
        .onDisappear {
            entranceTask?.cancel()
            firstScanLaunchTask?.cancel()
            PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(phase)
        }
        .processRestoreOpaqueUIKitHostingBackground(OnboardingTheme.hostingBackgroundUIColor)
    }

    /// Scan hors `scaleEffect` du carousel — sinon le bouton « plus tard » ne reçoit pas les taps.
    @ViewBuilder
    private var interactiveScanOverlay: some View {
        DashboardPreviewEmbeddedFaceScanSession(
            isTabActive: true,
            isCaptureEnabled: true,
            onCancel: {
                dashboardFirstScanSession?.onCancel()
            },
            onSkipLater: {
                dashboardFirstScanSession?.onSkipLater()
            },
            onResultReady: { result in
                dashboardFirstScanSession?.onResult(result)
            },
            onContinueAfterResults: {
                dashboardFirstScanSession?.onContinue()
            }
        )
        .environmentObject(UnifiedProfileService.shared)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(ProcessBackgroundPalette.base(for: colorScheme).ignoresSafeArea())
    }

    @ViewBuilder
    private var tourOrHiddenBackground: some View {
        dashboardTourLayer
            // Pendant le scan interactif, l’overlay plein écran prend le relais (évite double caméra + taps morts).
            .opacity(embeddedScanResult == nil && !isScanPageInteractive ? 1 : 0)
            .allowsHitTesting(embeddedScanResult == nil && !isScanPageInteractive)
    }

    @ViewBuilder
    private var resultsOverlay: some View {
        if let result = embeddedScanResult {
            OnboardingDedicatedFaceScanResultsView(result: result) {
                onFirstScanContinue?()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(OnboardingScanFlowMotion.forwardTransition)
            .zIndex(50)
            .allowsHitTesting(true)
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .inactive, .background:
            preserveScanSessionIfNeeded()
        case .active:
            if preservedScanSession != nil {
                restoreScanSessionIfNeeded()
            } else if let state = initialScanPersistedState,
                      !isScanSessionExpanded,
                      embeddedScanResult == nil {
                applyPersistedScanState(state)
            }
        default:
            break
        }
    }

    @ViewBuilder
    private var dashboardTourLayer: some View {
        GeometryReader { screen in
            let compactCardWidth = min(screen.size.width * 0.54, 242)
            let expandScale = 1 + (screen.size.width / max(compactCardWidth, 1) - 1) * scanExpandProgress

            ZStack {
                OnboardingTheme.screenBackground
                    .ignoresSafeArea()

                carousel
                    .frame(width: screen.size.width, height: screen.size.height)
                    .scaleEffect(hasSettledCardScale ? 1 : 0.975, anchor: .center)
                    .scaleEffect(expandScale, anchor: .center)
                    .offset(y: hasSettledCardScale ? 0 : 14)
                    .opacity(hasSettledCardScale ? 1 : 0)
                    .clipped()

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        titleBlock
                            .padding(.horizontal, 28)
                            .padding(.top, OnboardingConstants.safeAreaTop + 40)
                            .padding(.bottom, 8)

                        subtitleBlock
                            .padding(.horizontal, 28)
                            .padding(.bottom, 18)
                    }

                    Spacer(minLength: 0)

                    bottomChrome
                        .padding(.horizontal, 34)
                        .padding(.top, 12)
                        .padding(.bottom, 50)
                }
                .opacity(showsTourChrome ? (1 - scanExpandProgress) : 0)
                .offset(y: showsTourChrome ? 0 : 10)
                .allowsHitTesting(
                    showsTourChrome
                        && scanExpandProgress < 0.02
                        && !isAdvancingSlide
                )
            }
            .frame(width: screen.size.width, height: screen.size.height)
        }
    }

    private func restorePersistedSessionIfNeeded() {
        if let result = pendingScanResult {
            embeddedScanResult = result
            revealsPreviewContent = true
            hasSettledCardScale = true
            showsTourChrome = true
            return
        }

        guard let state = initialScanPersistedState else { return }
        applyPersistedScanState(state)
    }

    private func applyPersistedScanState(_ state: OnboardingDashboardScanPersistedState) {
        carouselStep = min(max(0, state.carouselStep), max(0, slides.count - 1))
        scanExpandProgress = CGFloat(state.scanExpandProgress)
        isScanPageInteractive = state.isScanPageInteractive
        showsSideCards = state.showsSideCards
        showsTourChrome = state.showsTourChrome
        revealsPreviewContent = true
        hasSettledCardScale = true
    }

    private func syncPersistedScanState() {
        guard isScanSessionExpanded else {
            onScanPersistedStateChange?(nil)
            return
        }

        onScanPersistedStateChange?(
            OnboardingDashboardScanPersistedState(
                carouselStep: carouselStep,
                scanExpandProgress: Double(scanExpandProgress),
                isScanPageInteractive: isScanPageInteractive,
                showsSideCards: showsSideCards,
                showsTourChrome: showsTourChrome
            )
        )
    }

    private func bootstrapPreviewIfNeeded() {
        guard !didBootstrapPreview else { return }
        didBootstrapPreview = true
        Task { @MainActor in
            Self.preparePreviewSession()
        }
    }

    @MainActor
    private static func preparePreviewSession() {
        PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
        let profile = UnifiedProfileService.shared.currentProfile
        if WelcomePlanStore.shared.plan == nil {
            WelcomePlanStore.shared.refreshEphemeralPreviewPlan(profile: profile)
        } else {
            WelcomePlanStore.shared.installEphemeralPreviewPlanIfNeeded(profile: profile)
        }
        ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
    }

    private var currentSlide: DashboardPreviewSlide {
        slides[logicalSlideIndex]
    }

    private var titleBlock: some View {
        let copy = currentSlide.tourCopy
        return DashboardPreviewStepContent(stepIndex: logicalSlideIndex) {
            (
                Text(copy.titlePrefix)
                + Text(copy.titleAccent)
                    .foregroundStyle(accent)
            )
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(OnboardingTheme.primaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(copy.titleAccessibilityLabel)
        }
    }

    private var subtitleBlock: some View {
        DashboardPreviewStepContent(stepIndex: logicalSlideIndex) {
            Text(currentSlide.tourCopy.subtitle)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(OnboardingTheme.mutedText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerCaption: some View {
        let copy = currentSlide.tourCopy
        return DashboardPreviewStepContent(stepIndex: logicalSlideIndex) {
            Group {
                if let percent = copy.footerPercent {
                    (
                        Text(copy.footerPrefix)
                        + Text(percent)
                            .foregroundStyle(accent)
                            .fontWeight(.semibold)
                        + Text(copy.footerSuffix)
                    )
                } else {
                    Text(copy.footer)
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(OnboardingTheme.primaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 0) {
            footerCaption
                .padding(.bottom, 16)

            DashboardPreviewTourProgressBar(
                activeIndex: logicalSlideIndex,
                segmentCount: slides.count,
                accent: accent
            )
            .frame(maxWidth: .infinity)
            .padding(.bottom, 26)
            .accessibilityLabel(
                OnboardingCopy.t(
                    "Étape \(logicalSlideIndex + 1) sur \(slides.count)",
                    en: "Step \(logicalSlideIndex + 1) of \(slides.count)"
                )
            )

            Button {
                handleContinue()
            } label: {
                Text(ctaTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(OnboardingTheme.filledButtonText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .onboardingPrimaryActionStyle()
            .accessibilityLabel(ctaTitle)
        }
    }

    private var carousel: some View {
        DashboardPreviewCarousel(
            slides: slides,
            step: carouselStep,
            revealsContent: revealsPreviewContent,
            showsSideCards: showsSideCards,
            expandProgress: scanExpandProgress,
            isScanInteractive: false
        )
    }

    private var dashboardFirstScanSession: OnboardingDashboardScanSession? {
        OnboardingDashboardScanSession(
            onResult: { result in
                firstScanLaunchTask?.cancel()
                isScanPageInteractive = false
                embeddedScanResult = result
                onFirstScanResult?(result)
            },
            onCancel: {
                dismissFirstScanSession()
            },
            onSkipLater: {
                dismissFirstScanSession()
                onFirstScanSkipLater?()
            },
            onContinue: {
                onFirstScanContinue?()
            }
        )
    }

    private func handleContinue() {
        guard !isAdvancingSlide else { return }
        HapticManager.shared.impact(.medium)
        if isLastSlide {
            if hasCompletedFirstScan {
                onFirstScanContinue?()
            } else {
                beginFirstScanLaunch()
            }
            return
        }

        isAdvancingSlide = true
        carouselStep = min(carouselStep + 1, slides.count - 1)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(360))
            isAdvancingSlide = false
        }
    }

    private func startEntranceIfNeeded() {
        guard !revealsPreviewContent, !showsTourChrome else { return }
        guard initialScanPersistedState == nil, pendingScanResult == nil else { return }
        entranceTask?.cancel()

        if reduceMotion {
            revealsPreviewContent = true
            hasSettledCardScale = true
            showsTourChrome = true
            showsSideCards = true
            return
        }

        entranceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            withAnimation(DashboardPreviewCarouselMotion.cardSettle) {
                hasSettledCardScale = true
                revealsPreviewContent = true
                showsSideCards = true
            }

            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(DashboardPreviewCarouselMotion.entrance) {
                showsTourChrome = true
            }
        }
    }

    private func beginFirstScanLaunch() {
        guard !isScanPageInteractive else { return }

        onBeginFirstScan?()
        firstScanLaunchTask?.cancel()

        // Plein écran direct — le scaleEffect du carousel cassait les taps sur « plus tard ».
        var hideSides = Transaction()
        hideSides.disablesAnimations = true
        withTransaction(hideSides) {
            showsSideCards = false
            scanExpandProgress = 1
            isScanPageInteractive = true
        }
        syncPersistedScanState()

        firstScanLaunchTask = Task { @MainActor in
            await requestFirstScanPermissionAndTrack()
        }
    }

    @MainActor
    private func requestFirstScanPermissionAndTrack() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted {
            ProcessAnalytics.trackCameraAuthorized(source: "onboarding_dashboard_first_scan")
        } else {
            ProcessAnalytics.trackCameraDenied(source: "onboarding_dashboard_first_scan")
        }

        if !ProcessPrivacyConsentStore.shared.canCaptureFaceScan {
            ProcessPrivacyConsentStore.shared.acceptFaceScanCapture()
        }

        ProcessAnalytics.trackMossAction(
            page: .profileSummary,
            action: "started_scan_from_dashboard"
        )
    }

    private func dismissFirstScanSession() {
        firstScanLaunchTask?.cancel()
        embeddedScanResult = nil
        isScanPageInteractive = false
        withAnimation(DashboardPreviewCarouselMotion.expandScan) {
            scanExpandProgress = 0
            showsSideCards = true
        }
        onScanPersistedStateChange?(nil)
    }

    private func resetFirstScanPresentation() {
        firstScanLaunchTask?.cancel()
        embeddedScanResult = nil
        isScanPageInteractive = false
        scanExpandProgress = 0
        showsSideCards = true
        preservedScanSession = nil
        onScanPersistedStateChange?(nil)
    }

    private var isScanSessionExpanded: Bool {
        isScanPageInteractive || scanExpandProgress > 0.01
    }

    private func preserveScanSessionIfNeeded() {
        guard isScanSessionExpanded else { return }
        preservedScanSession = DashboardPreviewScanSessionSnapshot(
            carouselStep: carouselStep,
            scanExpandProgress: scanExpandProgress,
            isScanPageInteractive: isScanPageInteractive,
            showsSideCards: showsSideCards,
            showsTourChrome: showsTourChrome
        )
        syncPersistedScanState()
    }

    private func restoreScanSessionIfNeeded() {
        guard let snapshot = preservedScanSession else { return }
        preservedScanSession = nil

        let animation = reduceMotion
            ? Animation.linear(duration: 0.01)
            : DashboardPreviewCarouselMotion.expandScan

        withAnimation(animation) {
            carouselStep = min(max(0, snapshot.carouselStep), max(0, slides.count - 1))
            scanExpandProgress = snapshot.scanExpandProgress
            isScanPageInteractive = snapshot.isScanPageInteractive
            showsSideCards = snapshot.showsSideCards
            showsTourChrome = snapshot.showsTourChrome
        }
        syncPersistedScanState()
    }

    private var ctaTitle: String {
        if isLastSlide {
            if hasCompletedFirstScan {
                return OnboardingCopy.continueCTA
            }
            return OnboardingCopy.t("Fais ton premier scan", en: "Take your first scan")
        }
        return OnboardingCopy.continueCTA
    }
}

private struct DashboardPreviewScanSessionSnapshot {
    let carouselStep: Int
    let scanExpandProgress: CGFloat
    let isScanPageInteractive: Bool
    let showsSideCards: Bool
    let showsTourChrome: Bool
}

private enum DashboardPreviewCarouselMotion {
    static let advance = Animation.spring(response: 0.38, dampingFraction: 0.92)
    static let copy = Animation.easeOut(duration: 0.16)
    static let expandScan = Animation.easeOut(duration: 0.32)
    static let cardSettle = Animation.smooth(duration: 0.44, extraBounce: 0)
    static let entrance = Animation.smooth(duration: 0.36, extraBounce: 0)
    static let contentReveal = Animation.spring(response: 0.36, dampingFraction: 0.94)
}

private struct DashboardPreviewStepContent<Content: View>: View {
    let stepIndex: Int
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .id(stepIndex)
            .transition(.opacity)
            .animation(DashboardPreviewCarouselMotion.copy, value: stepIndex)
    }
}

private struct DashboardPreviewTourProgressBar: View {
    @Environment(\.colorScheme) private var colorScheme

    let activeIndex: Int
    let segmentCount: Int
    let accent: Color

    private let totalWidth: CGFloat = 176
    private let barHeight: CGFloat = 4

    private var trackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
    }

    private var fillProgress: CGFloat {
        guard segmentCount > 0 else { return 0 }
        return CGFloat(activeIndex + 1) / CGFloat(segmentCount)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackColor)

                Capsule(style: .continuous)
                    .fill(accent)
                    .frame(width: geometry.size.width * fillProgress)
            }
        }
        .animation(DashboardPreviewCarouselMotion.advance, value: activeIndex)
        .frame(width: totalWidth, height: barHeight)
    }
}

private enum DashboardPreviewCarouselLayout {
    static func cardHeight(
        for pageKind: DashboardPreviewPageKind,
        cardWidth: CGFloat,
        screenSize: CGSize
    ) -> CGFloat {
        let screenAspect = screenSize.height / max(screenSize.width, 1)
        switch pageKind {
        case .faceScanCapture:
            return cardWidth * screenAspect
        case .appTab:
            return min(screenSize.height * 0.90, cardWidth * 2.05)
        }
    }

    static func tallestCardHeight(
        slides: [DashboardPreviewSlide],
        cardWidth: CGFloat,
        screenSize: CGSize
    ) -> CGFloat {
        slides
            .map { cardHeight(for: $0.pageKind, cardWidth: cardWidth, screenSize: screenSize) }
            .max() ?? (cardWidth * (screenSize.height / max(screenSize.width, 1)))
    }

    static func slide(at index: Int, in slides: [DashboardPreviewSlide]) -> DashboardPreviewSlide {
        slides[index]
    }
}

private struct DashboardPreviewCarousel: View {
    let slides: [DashboardPreviewSlide]
    let step: Int
    var revealsContent: Bool = true
    var showsSideCards: Bool = true
    var expandProgress: CGFloat = 0
    var isScanInteractive: Bool = false

    @State private var activeIndex: Int?
    @State private var previewPagesReady = false

    var body: some View {
        GeometryReader { geo in
            let screenSize = geo.size
            let compactCardWidth = min(screenSize.width * 0.54, 242)
            let scrollCardHeight = DashboardPreviewCarouselLayout.tallestCardHeight(
                slides: slides,
                cardWidth: compactCardWidth,
                screenSize: screenSize
            )
            let focusedIndex = activeIndex ?? step
            let hideNeighbors = expandProgress > 0.02

            ProcessCoverFlow(
                config: ProcessCoverFlowConfig(
                    cardWidth: compactCardWidth,
                    cardHeight: scrollCardHeight,
                    rotation: hideNeighbors ? 0 : 30,
                    offsetFactor: 2.05,
                    sideOpacity: showsSideCards && !hideNeighbors ? 0.52 : 0,
                    sideScaleMinimum: 0.68,
                    cardSpacing: 22,
                    sideSpread: 12,
                    maxSideVisibleProgress: showsSideCards && !hideNeighbors ? 1.08 : 0.02
                ),
                activeIndex: $activeIndex,
                itemCount: slides.count
            ) { index, isFocused in
                let slide = DashboardPreviewCarouselLayout.slide(at: index, in: slides)
                let cardHeight = DashboardPreviewCarouselLayout.cardHeight(
                    for: slide.pageKind,
                    cardWidth: compactCardWidth,
                    screenSize: screenSize
                )
                let itemCardSize = CGSize(width: compactCardWidth, height: cardHeight)
                let shouldLoadLivePreview: Bool = {
                    if slide.pageKind == .faceScanCapture {
                        return isFocused
                    }
                    return isFocused || (!hideNeighbors && abs(index - focusedIndex) <= 1)
                }()

                DashboardPreviewCard(
                    pageKind: slide.pageKind,
                    cardSize: itemCardSize,
                    screenSize: screenSize,
                    previewPagesReady: previewPagesReady,
                    shouldLoadLivePreview: shouldLoadLivePreview,
                    isSidePreview: !isFocused,
                    isPageActive: isFocused,
                    revealsContent: revealsContent,
                    expandProgress: isFocused ? expandProgress : 0,
                    isInteractive: isScanInteractive && isFocused && slide.pageKind == .faceScanCapture
                )
            }
        }
        .allowsHitTesting(isScanInteractive)
        .environmentObject(UnifiedProfileService.shared)
        .environmentObject(HealthManager.shared)
        .environmentObject(AuthenticationManager.shared)
        .onAppear {
            activeIndex = min(step, slides.count - 1)
            ensurePreviewPlanReady()
            previewPagesReady = true
        }
        .onChange(of: step) { _, newStep in
            let clamped = min(max(newStep, 0), slides.count - 1)
            withAnimation(DashboardPreviewCarouselMotion.advance) {
                activeIndex = clamped
            }
        }
        .onChange(of: activeIndex) { _, newValue in
            guard expandProgress > 0.02 || isScanInteractive else { return }
            let locked = min(step, slides.count - 1)
            if newValue != locked {
                activeIndex = locked
            }
        }
    }

    private func ensurePreviewPlanReady() {
        guard WelcomePlanStore.shared.plan == nil else { return }
        let profile = UnifiedProfileService.shared.currentProfile
        WelcomePlanStore.shared.refreshEphemeralPreviewPlan(profile: profile)
        ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
    }
}

private struct DashboardPreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let pageKind: DashboardPreviewPageKind
    let cardSize: CGSize
    var screenSize: CGSize
    var previewPagesReady: Bool
    var shouldLoadLivePreview: Bool = true
    var isSidePreview: Bool = false
    var isPageActive: Bool = false
    var revealsContent: Bool = true
    var expandProgress: CGFloat = 0
    var isInteractive: Bool = false

    @State private var mountsLivePage = false
    @State private var liveMountTask: Task<Void, Never>?

    private var cornerRadius: CGFloat { 32 * (1 - expandProgress) }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            DashboardPreviewEmptyScreen()

            if previewPagesReady {
                Group {
                    if mountsLivePage {
                        DashboardPreviewScaledLivePage(
                            pageKind: pageKind,
                            size: cardSize,
                            screenSize: screenSize,
                            isPageActive: isPageActive,
                            isInteractive: isInteractive
                        )
                    } else {
                        DashboardPreviewFrozenSlide(pageKind: pageKind)
                    }
                }
                .opacity(revealsContent ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background {
            shape.fill(
                colorScheme == .dark
                    ? ProcessBackgroundPalette.darkBase
                    : ProcessBackgroundPalette.lightBase
            )
        }
        .clipShape(shape)
        .overlay {
            if isSidePreview {
                shape.fill(
                    Color.black.opacity(colorScheme == .dark ? 0.18 : 0.10)
                )
            }
        }
        .overlay {
            shape.strokeBorder(
                Color.white.opacity(
                    (colorScheme == .dark ? 0.10 : 0.55) * (1 - expandProgress)
                ),
                lineWidth: 1
            )
        }
        .shadow(
            color: Color.black.opacity(
                (previewPagesReady && !isSidePreview
                    ? (colorScheme == .dark ? 0.55 : 0.16)
                    : (colorScheme == .dark ? 0.30 : 0.08)) * (1 - expandProgress)
            ),
            radius: (previewPagesReady && !isSidePreview ? (colorScheme == .dark ? 22 : 18) : 10)
                * (1 - 0.55 * expandProgress),
            y: (previewPagesReady && !isSidePreview ? 10 : 4) * (1 - expandProgress)
        )
        .frame(width: cardSize.width, height: cardSize.height, alignment: .top)
        .animation(DashboardPreviewCarouselMotion.contentReveal, value: revealsContent)
        .allowsHitTesting(isInteractive)
        .accessibilityHidden(!isInteractive)
        .onAppear {
            syncLiveMountState()
        }
        .onChange(of: shouldLoadLivePreview) { _, _ in
            syncLiveMountState()
        }
        .onChange(of: isPageActive) { _, _ in
            syncLiveMountState()
        }
        .onChange(of: revealsContent) { _, _ in
            syncLiveMountState()
        }
        .onDisappear {
            liveMountTask?.cancel()
            mountsLivePage = false
        }
    }

    private func syncLiveMountState() {
        liveMountTask?.cancel()
        guard shouldLoadLivePreview || expandProgress > 0.01 else {
            mountsLivePage = false
            return
        }

        let mountDelay: Duration = .zero
        liveMountTask = Task { @MainActor in
            if mountDelay > .zero {
                try? await Task.sleep(for: mountDelay)
            }
            guard !Task.isCancelled, shouldLoadLivePreview else { return }
            mountsLivePage = true
        }
    }
}

private struct DashboardPreviewEmptyScreen: View {
    var body: some View {
        ProcessScreenBackground()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

/// Aperçu statique pour les cartes latérales — évite 4 vraies pages + caméras en parallèle.
private struct DashboardPreviewFrozenSlide: View {
    @Environment(\.colorScheme) private var colorScheme

    let pageKind: DashboardPreviewPageKind

    var body: some View {
        ZStack(alignment: .top) {
            ProcessScreenBackground()

            if pageKind == .faceScanCapture {
                faceScanCapturePlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private var faceScanCapturePlaceholder: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 28)

            FaceScanOnboardingOvalShape()
                .fill(Color(red: 0.09, green: 0.09, blue: 0.10))
                .overlay {
                    FaceScanOnboardingOvalShape()
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.14), lineWidth: 0.75)
                }
                .frame(width: 92, height: 120)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08))
                .frame(width: 118, height: 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
    }
}

private struct DashboardPreviewScaledLivePage: View {
    let pageKind: DashboardPreviewPageKind
    let size: CGSize
    var screenSize: CGSize
    var isPageActive: Bool
    var isInteractive: Bool = false

    var body: some View {
        let scale = size.width / max(screenSize.width, 1)

        DashboardPreviewAppPage(pageKind: pageKind, isPageActive: isPageActive, isInteractive: isInteractive)
            .environment(\.onboardingScanPreviewPaused, !isPageActive)
            .frame(width: screenSize.width, height: screenSize.height, alignment: .top)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
    }
}

private struct DashboardPreviewAppPage: View {
    let pageKind: DashboardPreviewPageKind
    var isPageActive: Bool
    var isInteractive: Bool = false

    @State private var runtimeActive = false
    @State private var deactivateTask: Task<Void, Never>?

    init(pageKind: DashboardPreviewPageKind, isPageActive: Bool, isInteractive: Bool = false) {
        self.pageKind = pageKind
        self.isPageActive = isPageActive
        self.isInteractive = isInteractive
        _runtimeActive = State(initialValue: isPageActive)
    }

    private var effectiveTabActive: Bool {
        runtimeActive
    }

    private var lockedSection: Binding<ProcessMainSection> {
        Binding(
            get: { pageKind.tabSection ?? .plan },
            set: { _ in }
        )
    }

    var body: some View {
        Group {
            switch pageKind {
            case .faceScanCapture:
                DashboardPreviewFaceScanCapturePage(
                    isTabActive: effectiveTabActive,
                    isInteractive: isInteractive
                )
            case .appTab:
                ProcessIGTabShell(
                    selectedSection: lockedSection,
                    onMealScan: nil,
                    hidesTabChrome: true
                ) {
                    tabRoot(for: pageKind.tabSection ?? .plan)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(Color.clear)
                }
            }
        }
        .processAppPageBackground()
        .ignoresSafeArea()
        .allowsHitTesting(isInteractive)
        .onChange(of: isPageActive) { _, active in
            deactivateTask?.cancel()
            if active {
                runtimeActive = true
                return
            }
            deactivateTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                guard !Task.isCancelled, !isPageActive else { return }
                runtimeActive = false
            }
        }
    }

    @ViewBuilder
    private func tabRoot(for section: ProcessMainSection) -> some View {
        switch section {
        case .plan:
            PlanDashboardView(
                selectedSection: lockedSection,
                isTabActive: effectiveTabActive,
                isOnboardingPreview: true
            )
        case .routine:
            ProcessRoutineHomeView(
                selectedSection: lockedSection,
                isTabActive: effectiveTabActive,
                isOnboardingPreview: true
            )
        case .statistics:
            ProcessProfileView(
                selectedSection: lockedSection,
                isTabActive: effectiveTabActive,
                isOnboardingPreview: true
            )
        case .scan, .profile, .coach:
            ProcessScreenBackground()
        }
    }
}

/// Aperçu caméra de la 4ᵉ carte — même instance que la capture après zoom.
private struct DashboardPreviewFaceScanCapturePage: View {
    var isTabActive: Bool
    var isInteractive: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDashboardScanSession) private var scanSession
    @EnvironmentObject private var profileService: UnifiedProfileService

    var body: some View {
        Group {
            if let session = scanSession {
                DashboardPreviewEmbeddedFaceScanSession(
                    isTabActive: isTabActive,
                    isCaptureEnabled: isInteractive,
                    onCancel: session.onCancel,
                    onSkipLater: session.onSkipLater,
                    onResultReady: session.onResult,
                    onContinueAfterResults: session.onContinue
                )
                .environmentObject(profileService)
            } else {
                ProcessScreenBackground()
            }
        }
        .processClearUIKitHostingBackground()
        .background(ProcessBackgroundPalette.base(for: colorScheme))
    }
}

/// Capture → analyse → résultats, zoom plein écran depuis le dashboard.
private struct DashboardPreviewEmbeddedFaceScanSession: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var profileService: UnifiedProfileService

    var isTabActive: Bool
    var isCaptureEnabled: Bool
    var onCancel: () -> Void
    var onSkipLater: () -> Void
    var onResultReady: (FaceScanResult) -> Void
    var onContinueAfterResults: () -> Void

    @State private var captureInput: CapturePayload?
    @State private var completedResult: FaceScanResult?

    private struct CapturePayload {
        let payload: FaceScanCapturePayload
        let markers: FaceWellnessMarkers
    }

    private var sessionBackground: Color {
        ProcessBackgroundPalette.base(for: colorScheme)
    }

    private var skipHandler: (() -> Void)? {
        // Toujours exposer le skip dès que la session existe — même pendant l’anim d’expand.
        {
            ProcessAnalytics.trackMossAction(
                page: ProcessAnalytics.MossPage.faceScanCapture,
                action: "skipped_later"
            )
            onSkipLater()
        }
    }

    var body: some View {
        ZStack {
            sessionBackground.ignoresSafeArea()

            if let input = captureInput, completedResult == nil {
                FaceScanAnalysisFlowView(
                    payload: input.payload,
                    markers: input.markers,
                    profile: profileService.currentProfile,
                    showsResultScreen: false,
                    tracksOnboardingMossFunnel: true,
                    onDismiss: {},
                    onComplete: { result in
                        withAnimation(OnboardingScanFlowMotion.animation) {
                            completedResult = result
                        }
                        onResultReady(result)
                    }
                )
                .transition(OnboardingScanFlowMotion.forwardTransition)
                .zIndex(1)
            } else if completedResult != nil {
                sessionBackground.ignoresSafeArea()
            } else {
                FaceScanCaptureScreen(
                    presentation: .fullScreen,
                    showsBackButton: isCaptureEnabled,
                    onBack: {
                        ProcessAnalytics.trackMossAction(
                            page: ProcessAnalytics.MossPage.faceScanCapture,
                            action: "cancelled"
                        )
                        onCancel()
                    },
                    onSkip: skipHandler,
                    isCameraSessionActive: isTabActive,
                    skipsHeadTiltPhase: true,
                    usesOnboardingFaceOval: true,
                    usesAppScreenBackground: true,
                    playsArrivalCountdown: false,
                    isScanCaptureEnabled: isCaptureEnabled,
                    showsInFrameCameraPermissionGate: isCaptureEnabled,
                    onContinue: { payload, markers in
                        ProcessAnalytics.trackMossAction(
                            page: ProcessAnalytics.MossPage.faceScanCapture,
                            action: "captured"
                        )
                        withAnimation(OnboardingScanFlowMotion.animation) {
                            captureInput = CapturePayload(payload: payload, markers: markers)
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .processClearUIKitHostingBackground()
        .background(sessionBackground)
        .animation(OnboardingScanFlowMotion.animation, value: captureInput?.payload.scanId)
        .onChange(of: isCaptureEnabled) { _, enabled in
            if enabled, captureInput == nil, completedResult == nil {
                ProcessAnalytics.trackMossPageViewed(ProcessAnalytics.MossPage.faceScanCapture)
            }
        }
        .onChange(of: captureInput != nil) { _, hasCapture in
            if hasCapture, completedResult == nil {
                ProcessAnalytics.trackMossPageViewed(ProcessAnalytics.MossPage.faceScanAnalyzing)
            }
        }
        .onChange(of: completedResult != nil) { _, hasResult in
            if hasResult {
                ProcessAnalytics.trackMossPageViewed(ProcessAnalytics.MossPage.faceScanResults)
            }
        }
    }
}

private enum DashboardPreviewPageKind: Hashable {
    case appTab(ProcessMainSection)
    case faceScanCapture

    var tabSection: ProcessMainSection? {
        if case .appTab(let section) = self { return section }
        return nil
    }
}

private struct DashboardPreviewSlide: Identifiable, Hashable {
    let id: String
    let pageKind: DashboardPreviewPageKind

    @MainActor
    var tourCopy: DashboardPreviewTourCopy {
        Self.tourCopy(for: pageKind)
    }

    @MainActor
    static let firstScanCatalog: [DashboardPreviewSlide] = [
        .init(id: "discover-plan", pageKind: .appTab(.plan)),
        .init(id: "discover-streak", pageKind: .appTab(.statistics)),
        .init(id: "discover-routine", pageKind: .appTab(.routine)),
        .init(id: "discover-scan", pageKind: .faceScanCapture)
    ]

    @MainActor
    static func tourCopy(for pageKind: DashboardPreviewPageKind) -> DashboardPreviewTourCopy {
        switch pageKind {
        case .appTab(let section):
            return tourCopy(forSection: section)
        case .faceScanCapture:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Scanne ", en: "Scan "),
                titleAccent: OnboardingCopy.t("ton visage", en: "your face"),
                titleAccessibilityLabel: OnboardingCopy.t("Scanne ton visage", en: "Scan your face"),
                subtitle: OnboardingCopy.t(
                    "Un scan rapide voit ce que le miroir ne montre pas.",
                    en: "A quick scan catches what the mirror can't."
                ),
                footer: OnboardingCopy.t(
                    "Lance ton premier scan pour calibrer Process",
                    en: "Take your first scan to calibrate Process"
                )
            )
        }
    }

    private static func tourCopy(forSection section: ProcessMainSection) -> DashboardPreviewTourCopy {
        switch section {
        case .plan:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Découvre ", en: "Discover "),
                titleAccent: OnboardingCopy.t("ton espace", en: "your space"),
                titleAccessibilityLabel: OnboardingCopy.t("Découvre ton espace", en: "Discover your space"),
                subtitle: OnboardingCopy.t(
                    "Ton futur dashboard, là où tout vivra.",
                    en: "Your future dashboard, where everything will live."
                ),
                footerPrefix: OnboardingCopy.t("On est à ", en: "We're "),
                footerPercent: OnboardingCopy.t("25 %", en: "25%"),
                footerSuffix: OnboardingCopy.t(" de ton dashboard", en: " into your dashboard")
            )
        case .statistics:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Repère ta ", en: "Spot your "),
                titleAccent: OnboardingCopy.t("progression", en: "progress"),
                titleAccessibilityLabel: OnboardingCopy.t("Repère ta progression", en: "Spot your progress"),
                subtitle: OnboardingCopy.t(
                    "Série, scans et évolution — en un coup d’œil.",
                    en: "Streak, scans, and progress — at a glance."
                ),
                footer: OnboardingCopy.t(
                    "Suis ta progression dans le temps",
                    en: "Track your progress over time"
                )
            )
        case .routine:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Une routine ", en: "A routine "),
                titleAccent: OnboardingCopy.t("sur mesure", en: "built for you"),
                titleAccessibilityLabel: OnboardingCopy.t("Une routine sur mesure", en: "A routine built for you"),
                subtitle: OnboardingCopy.t(
                    "Adaptée à ton visage, étape par étape.",
                    en: "Tailored to your face, step by step."
                ),
                footer: OnboardingCopy.t(
                    "Ta routine quotidienne, faite pour toi",
                    en: "Your daily routine, built around you"
                )
            )
        case .scan, .profile, .coach:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Découvre ", en: "Discover "),
                titleAccent: OnboardingCopy.t("Process", en: "Process"),
                titleAccessibilityLabel: OnboardingCopy.t("Découvre Process", en: "Discover Process"),
                subtitle: OnboardingCopy.t(
                    "Ton futur dashboard, là où tout vivra.",
                    en: "Your future dashboard, where everything will live."
                ),
                footer: OnboardingCopy.continueCTA
            )
        }
    }
}

private struct DashboardPreviewTourCopy {
    let titlePrefix: String
    let titleAccent: String
    let titleAccessibilityLabel: String
    let subtitle: String
    var footer: String = ""
    var footerPrefix: String = ""
    var footerPercent: String?
    var footerSuffix: String = ""
}
