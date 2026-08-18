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
    @State private var furthestUnlockedIndex = 0
    @State private var didBootstrapPreview = false
    @State private var hidesTourChrome = false
    @State private var isFirstScanSessionPresented = false
    @State private var revealsPreviewContent = false
    @State private var showsTourChrome = false
    @State private var showsSideCards = false
    @State private var hasSettledCardScale = false
    @State private var entranceTask: Task<Void, Never>?

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
        ZStack {
            VStack(spacing: 0) {
                titleBlock
                    .padding(.horizontal, 28)
                    .padding(.top, OnboardingConstants.safeAreaTop + 40)
                    .padding(.bottom, 14)
                    .opacity(showsTourChrome && !hidesTourChrome ? 1 : 0)
                    .offset(y: showsTourChrome && !hidesTourChrome ? 0 : 10)
                    .allowsHitTesting(showsTourChrome && !hidesTourChrome)
                    .animation(.none, value: logicalSlideIndex)

                carousel
                    .frame(maxHeight: .infinity)
                    .scaleEffect(hasSettledCardScale ? 1 : 1.10, anchor: .center)
                    .opacity(hidesTourChrome ? 0 : 1)
                    .animation(nil, value: hidesTourChrome)

                subtitleBlock
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .opacity(showsTourChrome && !hidesTourChrome ? 1 : 0)
                    .offset(y: showsTourChrome && !hidesTourChrome ? 0 : 8)
                    .allowsHitTesting(showsTourChrome && !hidesTourChrome)
                    .animation(.none, value: logicalSlideIndex)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                OnboardingTheme.screenBackground
                    .ignoresSafeArea()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomChrome
                    .padding(.horizontal, 34)
                    .padding(.top, 12)
                    .padding(.bottom, 50)
                    .background {
                        OnboardingTheme.screenBackground
                            .ignoresSafeArea(edges: .bottom)
                    }
                    .opacity(showsTourChrome && !hidesTourChrome ? 1 : 0)
                    .offset(y: showsTourChrome && !hidesTourChrome ? 0 : 14)
                    .allowsHitTesting(showsTourChrome && !hidesTourChrome)
                    .animation(.none, value: logicalSlideIndex)
                    .zIndex(1_000)
            }

            if let onBack, !isFirstScanSessionPresented {
                // TEMP — retour mode dev, uniquement sur l’aperçu dashboard.
                VStack {
                    HStack {
                        OnboardingBackButton(action: onBack)
                            .accessibilityLabel(
                                OnboardingCopy.t("Retour (mode test)", en: "Back (dev)")
                            )
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, OnboardingConstants.headerHorizontalPadding)
                    .padding(.top, OnboardingConstants.headerBackButtonTopPadding)
                    Spacer(minLength: 0)
                }
                .zIndex(30)
            }

            if isFirstScanSessionPresented {
                OnboardingFaceScanSessionView(
                    usesAppScreenBackground: true,
                    playsArrivalCountdown: true,
                    onCancel: dismissFirstScanSession,
                    onResultReady: { result in
                        onFirstScanResult?(result)
                    },
                    onContinueAfterResults: {
                        isFirstScanSessionPresented = false
                        hidesTourChrome = false
                        onFirstScanContinue?()
                    }
                )
                .environmentObject(UnifiedProfileService.shared)
                .transition(.opacity)
                .ignoresSafeArea()
                .zIndex(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(DashboardPreviewCarouselMotion.presentScan, value: hidesTourChrome)
        .animation(DashboardPreviewCarouselMotion.presentScan, value: isFirstScanSessionPresented)
        .animation(DashboardPreviewCarouselMotion.entrance, value: showsTourChrome)
        .animation(DashboardPreviewCarouselMotion.cardSettle, value: hasSettledCardScale)
        .environment(\.onboardingScanPreviewPaused, isFirstScanSessionPresented)
        .onAppear {
            bootstrapPreviewIfNeeded()
            startEntranceIfNeeded()
        }
        .onDisappear {
            entranceTask?.cancel()
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
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
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
        VStack(spacing: 18) {
            footerCaption

            DashboardPreviewTourProgressBar(
                activeIndex: logicalSlideIndex,
                segmentCount: slides.count,
                accent: accent
            )
            .frame(maxWidth: .infinity)
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
            step: $carouselStep,
            maxUnlockedIndex: furthestUnlockedIndex,
            revealsContent: revealsPreviewContent,
            showsSideCards: showsSideCards,
            locksInteraction: hidesTourChrome || isFirstScanSessionPresented || !showsTourChrome
        )
    }

    private func handleContinue() {
        HapticManager.shared.impact(.medium)
        if isLastSlide {
            if presentation == .firstScanPending {
                beginFirstScanLaunch()
            } else {
                onComplete()
            }
        } else {
            let next = min(carouselStep + 1, slides.count - 1)
            furthestUnlockedIndex = max(furthestUnlockedIndex, next)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                carouselStep = next
            }
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
        guard presentation == .firstScanPending, !hidesTourChrome, !isFirstScanSessionPresented else { return }

        Task {
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

            await MainActor.run {
                withAnimation(DashboardPreviewCarouselMotion.presentScan) {
                    hidesTourChrome = true
                    isFirstScanSessionPresented = true
                }
            }
        }
    }

    private func dismissFirstScanSession() {
        withAnimation(DashboardPreviewCarouselMotion.presentScan) {
            isFirstScanSessionPresented = false
            hidesTourChrome = false
        }
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
    static let advance = Animation.spring(response: 0.46, dampingFraction: 0.94, blendDuration: 0)
    /// Courbe sans rebond — évite le « monte puis descend » du zoom carte.
    static let presentScan = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.28)
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
    }
}

private struct DashboardPreviewTourProgressBar: View {
    @Environment(\.colorScheme) private var colorScheme

    let activeIndex: Int
    let segmentCount: Int
    let accent: Color

    private let totalWidth: CGFloat = 132
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
                    .animation(.none, value: fillProgress)
            }
        }
        .animation(.none, value: activeIndex)
        .frame(width: totalWidth, height: barHeight)
    }
}

private enum DashboardPreviewCarouselLayout {
    static let slides = DashboardPreviewSlide.catalog
    static var slideCount: Int { slides.count }
    static var initialIndex: Int { 0 }

    /// Carte Scan plus haute (ovale vertical + CTA) — les autres slides utilisent la hauteur standard.
    static func cardHeight(for section: ProcessMainSection, cardWidth: CGFloat, maxHeight: CGFloat) -> CGFloat {
        let aspect: CGFloat = section == .scan ? 2.28 : 2.05
        return min(maxHeight * (section == .scan ? 0.92 : 0.90), cardWidth * aspect)
    }

    static func tallestCardHeight(cardWidth: CGFloat, maxHeight: CGFloat) -> CGFloat {
        slides
            .map { cardHeight(for: $0.section, cardWidth: cardWidth, maxHeight: maxHeight) }
            .max() ?? min(maxHeight * 0.90, cardWidth * 2.05)
    }

    static func slide(at index: Int) -> DashboardPreviewSlide {
        slides[index]
    }
}

private struct DashboardPreviewCarousel: View {
    let slides: [DashboardPreviewSlide]
    @Binding var step: Int
    var maxUnlockedIndex: Int = 0
    var revealsContent: Bool = true
    var showsSideCards: Bool = true
    var locksInteraction: Bool = false

    @State private var activeIndex: Int?
    @State private var handledStep = 0
    @State private var previewPagesReady = false

    var body: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width * 0.54, 242)
            let scrollCardHeight = DashboardPreviewCarouselLayout.tallestCardHeight(
                cardWidth: cardWidth,
                maxHeight: geo.size.height
            )
            let focusedIndex = activeIndex ?? step

            ProcessCoverFlow(
                config: ProcessCoverFlowConfig(
                    cardWidth: cardWidth,
                    cardHeight: scrollCardHeight,
                    rotation: 30,
                    offsetFactor: 2.05,
                    sideOpacity: showsSideCards ? 0.52 : 0,
                    sideScaleMinimum: 0.68,
                    cardSpacing: 22,
                    sideSpread: 12,
                    maxSideVisibleProgress: showsSideCards ? 1.08 : 0.12,
                    limitsScrollToOneCard: true,
                    maxUnlockedIndex: maxUnlockedIndex
                ),
                activeIndex: $activeIndex,
                itemCount: slides.count,
                onFocusedIndexChange: syncStepFromCarouselIndex,
                onScrollIdle: handleScrollIdle
            ) { index, isFocused in
                let slide = DashboardPreviewCarouselLayout.slide(at: index)
                let section = slide.section
                let cardHeight = DashboardPreviewCarouselLayout.cardHeight(
                    for: section,
                    cardWidth: cardWidth,
                    maxHeight: geo.size.height
                )
                let itemCardSize = CGSize(width: cardWidth, height: cardHeight)
                let shouldLoadLivePreview = abs(index - focusedIndex) <= 1

                VStack(spacing: 0) {
                    DashboardPreviewCard(
                        section: section,
                        cardSize: itemCardSize,
                        previewPagesReady: previewPagesReady,
                        shouldLoadLivePreview: shouldLoadLivePreview,
                        isSidePreview: !isFocused,
                        isPageActive: isFocused,
                        revealsContent: revealsContent
                    )
                    Spacer(minLength: 0)
                }
                .frame(height: scrollCardHeight, alignment: .top)
            }
        }
        .allowsHitTesting(!locksInteraction)
        .animation(DashboardPreviewCarouselMotion.entrance, value: showsSideCards)
        .environmentObject(UnifiedProfileService.shared)
        .environmentObject(HealthManager.shared)
        .environmentObject(AuthenticationManager.shared)
        .onAppear {
            if activeIndex == nil {
                activeIndex = min(step, slides.count - 1)
            }
            handledStep = step
            ensurePreviewPlanReady()
            previewPagesReady = true
        }
        .onChange(of: step) { _, newStep in
            let clampedStep = min(max(newStep, 0), slides.count - 1)
            if clampedStep > handledStep {
                let delta = clampedStep - handledStep
                handledStep = clampedStep
                let start = activeIndex ?? DashboardPreviewCarouselLayout.initialIndex
                let target = min(start + delta, slides.count - 1)
                advanceCarousel(to: target)
            } else if clampedStep < handledStep {
                let delta = handledStep - clampedStep
                handledStep = clampedStep
                retreatCarousel(by: delta)
            }
        }
    }

    private func handleScrollIdle(_ index: Int?) {
        guard let index else { return }
        syncStepFromCarouselIndex(index)
    }

    private func syncStepFromCarouselIndex(_ index: Int) {
        guard index >= 0, index < slides.count else { return }
        guard index != step else { return }

        handledStep = index
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            step = index
        }
    }

    private func ensurePreviewPlanReady() {
        guard WelcomePlanStore.shared.plan == nil else { return }
        let profile = UnifiedProfileService.shared.currentProfile
        WelcomePlanStore.shared.refreshEphemeralPreviewPlan(profile: profile)
        ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
    }

    private func advanceCarousel(to target: Int) {
        guard target >= 0, target < slides.count else { return }
        withAnimation(DashboardPreviewCarouselMotion.advance) {
            activeIndex = target
        }
    }

    private func retreatCarousel(by count: Int) {
        guard count > 0 else { return }
        let start = activeIndex ?? DashboardPreviewCarouselLayout.initialIndex
        let target = max(start - count, 0)

        withAnimation(DashboardPreviewCarouselMotion.advance) {
            activeIndex = target
        }
    }
}

private struct DashboardPreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let section: ProcessMainSection
    let cardSize: CGSize
    var previewPagesReady: Bool
    var shouldLoadLivePreview: Bool = true
    var isSidePreview: Bool = false
    var isPageActive: Bool = false
    var revealsContent: Bool = true

    @State private var mountsLivePage = false
    @State private var liveMountTask: Task<Void, Never>?

    private var cornerRadius: CGFloat { 32 }

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
                            isPageActive: isPageActive
                        )
                    } else {
                        DashboardPreviewFrozenSlide(section: section)
                    }
                }
                .opacity(revealsContent ? 1 : 0)
                .scaleEffect(revealsContent ? 1 : 1.08, anchor: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55),
                lineWidth: 1
            )
        }
        .shadow(
            color: Color.black.opacity(
                previewPagesReady && !isSidePreview
                    ? (colorScheme == .dark ? 0.55 : 0.16)
                    : (colorScheme == .dark ? 0.30 : 0.08)
            ),
            radius: previewPagesReady && !isSidePreview ? (colorScheme == .dark ? 22 : 18) : 10,
            y: previewPagesReady && !isSidePreview ? 10 : 4
        )
        .frame(width: cardSize.width, height: cardSize.height, alignment: .top)
        .animation(DashboardPreviewCarouselMotion.contentReveal, value: revealsContent)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
        guard shouldLoadLivePreview else {
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

private struct DashboardPreviewPlaceholder: View {
    let section: ProcessMainSection

    var body: some View {
        ZStack {
            ProcessScreenBackground()
            ProgressView()
                .controlSize(.regular)
                .tint(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(DashboardPreviewSlide.accessibilityLabel(for: section))
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
    var isPageActive: Bool

    /// Viewport iPhone — le preview onboarding masque la tab bar (`hidesTabChrome`).
    private static let designSize = CGSize(width: 393, height: 852)
    private static let previewBottomInset: CGFloat = 72

    var body: some View {
        let scale = size.width / Self.designSize.width
        let contentHeight = Self.designSize.height - Self.previewBottomInset

        DashboardPreviewAppPage(section: section, isPageActive: isPageActive)
            .frame(width: Self.designSize.width, height: contentHeight, alignment: .top)
            .frame(width: Self.designSize.width, height: Self.designSize.height, alignment: .top)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
    }
}

private struct DashboardPreviewAppPage: View {
    let section: ProcessMainSection
    var isPageActive: Bool

    @State private var selectedSection: ProcessMainSection
    @State private var runtimeActive = false
    @State private var deactivateTask: Task<Void, Never>?

    init(section: ProcessMainSection, isPageActive: Bool) {
        self.section = section
        self.isPageActive = isPageActive
        _selectedSection = State(initialValue: section)
        _runtimeActive = State(initialValue: isPageActive)
    }

    private var effectiveTabActive: Bool {
        runtimeActive
    }

    var body: some View {
        ProcessIGTabShell(
            selectedSection: $selectedSection,
            onMealScan: nil,
            hidesTabChrome: true
        ) {
            tabRoot
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.clear)
        }
        .processAppPageBackground()
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
                selectedSection: $selectedSection,
                isTabActive: effectiveTabActive,
                isOnboardingPreview: true
            )
        case .scan:
            ProcessFaceScanHomeView(
                selectedSection: $selectedSection,
                isTabActive: effectiveTabActive,
                isOnboardingPreview: true
            )
        case .routine:
            ProcessRoutineHomeView(
                selectedSection: $selectedSection,
                isTabActive: effectiveTabActive,
                isOnboardingPreview: true
            )
        case .statistics:
            ProcessProfileView(
                selectedSection: $selectedSection,
                isTabActive: effectiveTabActive,
                isOnboardingPreview: true
            )
        case .profile:
            ProcessProfileSettingsTabView(
                selectedSection: $selectedSection,
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
