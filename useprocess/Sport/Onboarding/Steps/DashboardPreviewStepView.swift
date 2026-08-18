//
//  DashboardPreviewStepView.swift
//  Process
//
//  Aperçu du dashboard — vraies pages Accueil / Routine / Série / Profil.
//

import AVFoundation
import SwiftUI

struct DashboardPreviewStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var presentation: OnboardingDashboardPreviewPresentation = .postTransformation
    let onComplete: () -> Void
    var onBack: (() -> Void)? = nil
    var onFirstScanResult: ((FaceScanResult) -> Void)? = nil
    var onFirstScanContinue: (() -> Void)? = nil

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

    private let slides = DashboardPreviewSlide.catalog
    private let accent = Color(red: 0.0, green: 0.478, blue: 1.0)

    init(
        presentation: OnboardingDashboardPreviewPresentation = .postTransformation,
        onComplete: @escaping () -> Void,
        onBack: (() -> Void)? = nil,
        onFirstScanResult: ((FaceScanResult) -> Void)? = nil,
        onFirstScanContinue: (() -> Void)? = nil
    ) {
        self.presentation = presentation
        self.onComplete = onComplete
        self.onBack = onBack
        self.onFirstScanResult = onFirstScanResult
        self.onFirstScanContinue = onFirstScanContinue
        PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
    }

    private var logicalSlideIndex: Int {
        carouselStep % slides.count
    }

    private var isLastSlide: Bool {
        logicalSlideIndex >= slides.count - 1
    }

    var body: some View {
        GeometryReader { screen in
            let compactCardWidth = min(screen.size.width * 0.54, 242)
            let expandScale = 1 + (screen.size.width / max(compactCardWidth, 1) - 1) * scanExpandProgress

            ZStack {
                OnboardingTheme.screenBackground
                    .ignoresSafeArea()

                carousel
                    .frame(width: screen.size.width, height: screen.size.height)
                    .scaleEffect(hasSettledCardScale ? 1 : 1.10, anchor: .center)
                    .scaleEffect(expandScale, anchor: .center)

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
                .allowsHitTesting(
                    showsTourChrome
                        && scanExpandProgress < 0.02
                        && !isAdvancingSlide
                )
            }
            .overlay(alignment: .topLeading) {
                if let onBack, !isScanPageInteractive, scanExpandProgress < 0.02 {
                    OnboardingBackButton(action: onBack)
                        .accessibilityLabel(
                            OnboardingCopy.t("Retour (mode test)", en: "Back (dev)")
                        )
                        .padding(.horizontal, OnboardingConstants.headerHorizontalPadding)
                        .padding(.top, OnboardingConstants.headerBackButtonTopPadding)
                } else if isScanPageInteractive {
                    OnboardingBackButton(action: dismissFirstScanSession)
                        .accessibilityLabel(OnboardingCopy.t("Retour", en: "Back"))
                        .padding(.horizontal, OnboardingConstants.headerHorizontalPadding)
                        .padding(.top, OnboardingConstants.headerBackButtonTopPadding)
                }
            }
            .frame(width: screen.size.width, height: screen.size.height)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(DashboardPreviewCarouselMotion.entrance, value: showsTourChrome)
        .animation(DashboardPreviewCarouselMotion.cardSettle, value: hasSettledCardScale)
        .environment(\.onboardingDashboardScanSession, dashboardFirstScanSession)
        .onAppear {
            bootstrapPreviewIfNeeded()
            startEntranceIfNeeded()
        }
        .onDisappear {
            entranceTask?.cancel()
            firstScanLaunchTask?.cancel()
            PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
        }
        .processRestoreOpaqueUIKitHostingBackground(OnboardingTheme.hostingBackgroundUIColor)
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
            isScanInteractive: isScanPageInteractive
        )
    }

    private var dashboardFirstScanSession: OnboardingDashboardScanSession? {
        guard presentation == .firstScanPending else { return nil }
        return OnboardingDashboardScanSession(
            onResult: { result in
                onFirstScanResult?(result)
            },
            onCancel: {},
            onContinue: {
                resetFirstScanPresentation()
                onFirstScanContinue?()
            }
        )
    }

    private func handleContinue() {
        guard !isAdvancingSlide else { return }
        HapticManager.shared.impact(.medium)
        if isLastSlide {
            if presentation == .firstScanPending {
                beginFirstScanLaunch()
            } else {
                onComplete()
            }
            return
        }

        isAdvancingSlide = true
        carouselStep = min(carouselStep + 1, slides.count - 1)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(520))
            isAdvancingSlide = false
        }
    }

    private func startEntranceIfNeeded() {
        guard !revealsPreviewContent, !showsTourChrome else { return }
        entranceTask?.cancel()

        if reduceMotion {
            revealsPreviewContent = true
            hasSettledCardScale = true
            showsTourChrome = true
            showsSideCards = true
            return
        }

        entranceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            withAnimation(DashboardPreviewCarouselMotion.cardSettle) {
                hasSettledCardScale = true
            }

            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else { return }
            withAnimation(DashboardPreviewCarouselMotion.contentReveal) {
                revealsPreviewContent = true
            }

            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            withAnimation(DashboardPreviewCarouselMotion.entrance) {
                showsTourChrome = true
            }

            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(DashboardPreviewCarouselMotion.entrance) {
                showsSideCards = true
            }
        }
    }

    private func beginFirstScanLaunch() {
        guard presentation == .firstScanPending,
              scanExpandProgress < 0.01,
              !isScanPageInteractive else { return }

        firstScanLaunchTask?.cancel()

        if reduceMotion {
            var hideSides = Transaction()
            hideSides.disablesAnimations = true
            withTransaction(hideSides) {
                showsSideCards = false
            }
            scanExpandProgress = 1
            isScanPageInteractive = true
            firstScanLaunchTask = Task { @MainActor in
                await requestFirstScanPermissionAndTrack()
            }
            return
        }

        var hideSides = Transaction()
        hideSides.disablesAnimations = true
        withTransaction(hideSides) {
            showsSideCards = false
        }
        withAnimation(DashboardPreviewCarouselMotion.expandScan) {
            scanExpandProgress = 1
        }

        firstScanLaunchTask = Task { @MainActor in
            async let permission: Void = requestFirstScanPermissionAndTrack()
            try? await Task.sleep(for: .milliseconds(400))
            _ = await permission
            guard !Task.isCancelled else { return }
            isScanPageInteractive = true
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
        isScanPageInteractive = false
        withAnimation(DashboardPreviewCarouselMotion.expandScan) {
            scanExpandProgress = 0
            showsSideCards = true
        }
    }

    private func resetFirstScanPresentation() {
        firstScanLaunchTask?.cancel()
        isScanPageInteractive = false
        scanExpandProgress = 0
        showsSideCards = true
    }

    private var ctaTitle: String {
        if isLastSlide {
            switch presentation {
            case .firstScanPending:
                return OnboardingCopy.t("Fais ton premier scan", en: "Take your first scan")
            case .postTransformation:
                return OnboardingCopy.t("Je veux ça", en: "I want this")
            }
        }
        return OnboardingCopy.continueCTA
    }
}

private enum DashboardPreviewCarouselMotion {
    static let advance = Animation.spring(response: 0.55, dampingFraction: 0.9)
    static let copy = Animation.easeInOut(duration: 0.22)
    static let expandScan = Animation.easeOut(duration: 0.4)
    static let cardSettle = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.52)
    static let entrance = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.38)
    static let contentReveal = Animation.timingCurve(0.18, 1.0, 0.32, 1.0, duration: 0.48)
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
    static let slides = DashboardPreviewSlide.catalog
    static var slideCount: Int { slides.count }

    /// Miniature à l’aspect de l’écran pour que le zoom Scan remplisse pile le viewport.
    static func cardHeight(for section: ProcessMainSection, cardWidth: CGFloat, screenSize: CGSize) -> CGFloat {
        let screenAspect = screenSize.height / max(screenSize.width, 1)
        if section == .scan {
            return cardWidth * screenAspect
        }
        return min(screenSize.height * 0.90, cardWidth * 2.05)
    }

    static func tallestCardHeight(cardWidth: CGFloat, screenSize: CGSize) -> CGFloat {
        slides
            .map { cardHeight(for: $0.section, cardWidth: cardWidth, screenSize: screenSize) }
            .max() ?? (cardWidth * (screenSize.height / max(screenSize.width, 1)))
    }

    static func slide(at index: Int) -> DashboardPreviewSlide {
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
                let slide = DashboardPreviewCarouselLayout.slide(at: index)
                let section = slide.section
                let cardHeight = DashboardPreviewCarouselLayout.cardHeight(
                    for: section,
                    cardWidth: compactCardWidth,
                    screenSize: screenSize
                )
                let itemCardSize = CGSize(width: compactCardWidth, height: cardHeight)
                let shouldLoadLivePreview = isFocused
                    ? true
                    : (!hideNeighbors && abs(index - focusedIndex) <= 1)

                DashboardPreviewCard(
                    section: section,
                    cardSize: itemCardSize,
                    screenSize: screenSize,
                    previewPagesReady: previewPagesReady,
                    shouldLoadLivePreview: shouldLoadLivePreview,
                    isSidePreview: !isFocused,
                    isPageActive: isFocused,
                    revealsContent: revealsContent,
                    expandProgress: isFocused ? expandProgress : 0,
                    isInteractive: isScanInteractive && isFocused && section == .scan
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

    let section: ProcessMainSection
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
                            section: section,
                            size: cardSize,
                            screenSize: screenSize,
                            isPageActive: isPageActive,
                            isInteractive: isInteractive
                        )
                    } else {
                        DashboardPreviewFrozenSlide(section: section)
                    }
                }
                .opacity(revealsContent ? 1 : 0)
                .scaleEffect(revealsContent ? 1 : 1.08, anchor: .top)
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

        let mountDelay: Duration = (section == .scan && isPageActive) ? .milliseconds(160) : .zero
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

    let section: ProcessMainSection

    var body: some View {
        ZStack(alignment: .top) {
            ProcessScreenBackground()

            if section == .scan {
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

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06))
                        .frame(width: 88, height: 8)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

private struct DashboardPreviewScaledLivePage: View {
    let section: ProcessMainSection
    let size: CGSize
    var screenSize: CGSize
    var isPageActive: Bool
    var isInteractive: Bool = false

    var body: some View {
        let scale = size.width / max(screenSize.width, 1)

        DashboardPreviewAppPage(section: section, isPageActive: isPageActive, isInteractive: isInteractive)
            .frame(width: screenSize.width, height: screenSize.height, alignment: .top)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
    }
}

private struct DashboardPreviewAppPage: View {
    let section: ProcessMainSection
    var isPageActive: Bool
    var isInteractive: Bool = false

    @State private var runtimeActive = false
    @State private var deactivateTask: Task<Void, Never>?

    init(section: ProcessMainSection, isPageActive: Bool, isInteractive: Bool = false) {
        self.section = section
        self.isPageActive = isPageActive
        self.isInteractive = isInteractive
        _runtimeActive = State(initialValue: isPageActive)
    }

    private var effectiveTabActive: Bool {
        runtimeActive
    }

    private var lockedSection: Binding<ProcessMainSection> {
        Binding(
            get: { section },
            set: { _ in }
        )
    }

    var body: some View {
        ProcessIGTabShell(
            selectedSection: lockedSection,
            onMealScan: nil,
            hidesTabChrome: true
        ) {
            tabRoot
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.clear)
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
    private var tabRoot: some View {
        switch section {
        case .plan:
            PlanDashboardView(
                selectedSection: lockedSection,
                isTabActive: effectiveTabActive,
                isOnboardingPreview: true
            )
        case .scan:
            ProcessFaceScanHomeView(
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
        case .profile:
            ProcessProfileSettingsTabView(
                selectedSection: lockedSection,
                isTabActive: effectiveTabActive,
                isOnboardingPreview: true
            )
        case .coach:
            Color.clear
        }
    }
}

private struct DashboardPreviewSlide: Identifiable, Hashable {
    let id: String
    let section: ProcessMainSection

    @MainActor
    static func accessibilityLabel(for section: ProcessMainSection) -> String {
        switch section {
        case .plan:
            return AppCopy.home
        case .scan:
            return AppCopy.t("Scan", en: "Scan")
        case .routine:
            return AppCopy.t("Routine", en: "Routine")
        case .statistics:
            return AppCopy.t("Série", en: "Streak")
        case .profile:
            return AppCopy.profile
        case .coach:
            return AppCopy.t("Coach", en: "Coach")
        }
    }

    @MainActor
    var accessibilityLabel: String {
        Self.accessibilityLabel(for: section)
    }

    @MainActor
    var subtitleParts: DashboardPreviewSlideSubtitle {
        Self.subtitleParts(for: section)
    }

    @MainActor
    static func subtitleParts(for section: ProcessMainSection) -> DashboardPreviewSlideSubtitle {
        switch section {
        case .plan:
            return DashboardPreviewSlideSubtitle(
                prefix: OnboardingCopy.t(
                    "Repas, eau, checklist — ",
                    en: "Meals, water, checklist — "
                ),
                accent: OnboardingCopy.t(
                    "tout au même endroit",
                    en: "all in one place"
                ),
                accessibilityLabel: OnboardingCopy.t(
                    "Repas, eau, checklist — tout au même endroit",
                    en: "Meals, water, checklist — all in one place"
                )
            )
        case .scan:
            return DashboardPreviewSlideSubtitle(
                prefix: OnboardingCopy.t(
                    "Un scan rapide ",
                    en: "A quick scan "
                ),
                accent: OnboardingCopy.t(
                    "voit ce que le miroir ne montre pas",
                    en: "catches what the mirror can't"
                ),
                accessibilityLabel: OnboardingCopy.t(
                    "Un scan rapide voit ce que le miroir ne montre pas",
                    en: "A quick scan catches what the mirror can't"
                )
            )
        case .statistics:
            return DashboardPreviewSlideSubtitle(
                prefix: OnboardingCopy.t(
                    "Valide tes jours et ",
                    en: "Check in daily and "
                ),
                accent: OnboardingCopy.t(
                    "gravis ta série",
                    en: "build your streak"
                ),
                accessibilityLabel: OnboardingCopy.t(
                    "Valide tes jours et gravis ta série",
                    en: "Check in daily and build your streak"
                )
            )
        case .routine:
            return DashboardPreviewSlideSubtitle(
                prefix: OnboardingCopy.t(
                    "Circuit visage + sport, ",
                    en: "Face circuit + training, "
                ),
                accent: OnboardingCopy.t(
                    "étape par étape",
                    en: "step by step"
                ),
                accessibilityLabel: OnboardingCopy.t(
                    "Circuit visage + sport, étape par étape",
                    en: "Face circuit + training, step by step"
                )
            )
        case .profile:
            return DashboardPreviewSlideSubtitle(
                prefix: OnboardingCopy.t(
                    "Scans, score debloat et ",
                    en: "Scans, debloat score and "
                ),
                accent: OnboardingCopy.t(
                    "tes réglages",
                    en: "your settings"
                ),
                accessibilityLabel: OnboardingCopy.t(
                    "Scans, score debloat et tes réglages",
                    en: "Scans, debloat score and your settings"
                )
            )
        case .coach:
            return DashboardPreviewSlideSubtitle(
                prefix: OnboardingCopy.t(
                    "Des conseils ",
                    en: "Advice "
                ),
                accent: OnboardingCopy.t(
                    "sur mesure",
                    en: "tailored to you"
                ),
                accessibilityLabel: OnboardingCopy.t(
                    "Des conseils sur mesure",
                    en: "Advice tailored to you"
                )
            )
        }
    }

    @MainActor
    var tourCopy: DashboardPreviewTourCopy {
        Self.tourCopy(for: section)
    }

    @MainActor
    static func tourCopy(for section: ProcessMainSection) -> DashboardPreviewTourCopy {
        switch section {
        case .plan:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Construisons ", en: "Now let's build "),
                titleAccent: OnboardingCopy.t("ton plan", en: "your plan"),
                titleAccessibilityLabel: OnboardingCopy.t(
                    "Construisons ton plan",
                    en: "Now let's build your plan"
                ),
                subtitle: OnboardingCopy.t(
                    "Ton dashboard, là où tout vit.",
                    en: "Your dashboard, where everything lives."
                ),
                footer: "",
                footerPrefix: OnboardingCopy.t("On est à ", en: "We're "),
                footerPercent: OnboardingCopy.t("25 %", en: "25%"),
                footerSuffix: OnboardingCopy.t(" de ton dashboard", en: " into building your dashboard")
            )
        case .statistics:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Suis chaque ", en: "Track every "),
                titleAccent: OnboardingCopy.t("évolution", en: "change"),
                titleAccessibilityLabel: OnboardingCopy.t(
                    "Suis chaque évolution",
                    en: "Track every change"
                ),
                subtitle: OnboardingCopy.t(
                    "Calendrier et tendances, au même endroit.",
                    en: "Calendar and trends, toggled in one place."
                ),
                footer: OnboardingCopy.t(
                    "Suis ta progression dans le temps",
                    en: "Track your progress over time"
                )
            )
        case .scan:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Scanne ", en: "Scan "),
                titleAccent: OnboardingCopy.t("chaque jour", en: "daily"),
                titleAccessibilityLabel: OnboardingCopy.t(
                    "Scanne chaque jour",
                    en: "Scan daily"
                ),
                subtitle: OnboardingCopy.t(
                    "Un scan rapide voit ce que le miroir ne montre pas.",
                    en: "A quick scan catches what the mirror can't."
                ),
                footer: OnboardingCopy.t(
                    "Scanne ton visage chaque jour pour voir ta progression",
                    en: "Scan your face daily to see real improvement"
                )
            )
        case .profile:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Ton ", en: "Your "),
                titleAccent: OnboardingCopy.t("profil", en: "profile"),
                titleAccessibilityLabel: OnboardingCopy.t(
                    "Ton profil",
                    en: "Your profile"
                ),
                subtitle: OnboardingCopy.t(
                    "Réglages, compte et préférences au même endroit.",
                    en: "Settings, account, and preferences in one place."
                ),
                footer: OnboardingCopy.t(
                    "Personnalise Process à ta façon",
                    en: "Customize Process your way"
                )
            )
        case .routine:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Pensé pour ", en: "Built for "),
                titleAccent: OnboardingCopy.t("ton visage", en: "your face"),
                titleAccessibilityLabel: OnboardingCopy.t(
                    "Pensé pour ton visage",
                    en: "Built for your face"
                ),
                subtitle: OnboardingCopy.t(
                    "Des routines sur mesure, calibrées sur ton scan.",
                    en: "Custom routines tailored to your exact scan."
                ),
                footer: OnboardingCopy.t(
                    "Ta routine quotidienne, faite pour toi",
                    en: "Your daily routine, built around you"
                )
            )
        case .coach:
            return DashboardPreviewTourCopy(
                titlePrefix: OnboardingCopy.t("Coach ", en: "Coach "),
                titleAccent: OnboardingCopy.t("IA", en: "AI"),
                titleAccessibilityLabel: OnboardingCopy.t("Coach IA", en: "AI Coach"),
                subtitle: OnboardingCopy.t(
                    "Des conseils sur mesure.",
                    en: "Advice tailored to you."
                ),
                footer: OnboardingCopy.t(
                    "Pose tes questions à tout moment",
                    en: "Ask your questions anytime"
                )
            )
        }
    }

    static let catalog: [DashboardPreviewSlide] = [
        .init(id: "home", section: .plan),
        .init(id: "progress", section: .statistics),
        .init(id: "routine", section: .routine),
        .init(id: "scan", section: .scan)
    ]
}

private struct DashboardPreviewTourCopy {
    let titlePrefix: String
    let titleAccent: String
    let titleAccessibilityLabel: String
    let subtitle: String
    var footer: String = ""
    var footerPrefix: String = ""
    var footerPercent: String? = nil
    var footerSuffix: String = ""
}

private struct DashboardPreviewSlideSubtitle {
    let prefix: String
    let accent: String
    let accessibilityLabel: String
}
