//
//  DashboardPreviewStepView.swift
//  Process
//
//  Aperçu du dashboard — Accueil / Série / Routine / Scan.
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

struct DashboardPreviewStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var hasCompletedFirstScan: Bool = false
    var onFirstScanResult: ((FaceScanResult) -> Void)? = nil
    var onFirstScanContinue: (() -> Void)? = nil
    var onFirstScanSkipLater: (() -> Void)? = nil
    var initialScanPersistedState: OnboardingDashboardScanPersistedState? = nil
    var pendingScanResult: FaceScanResult? = nil
    var onScanPersistedStateChange: ((OnboardingDashboardScanPersistedState?) -> Void)? = nil

    @State private var activeSlot: Int? = 0
    @State private var scanCardFrame: CGRect = .zero

    private var carouselStep: Int {
        get { min(max(activeSlot ?? 0, 0), slides.count - 1) }
        nonmutating set { activeSlot = min(max(newValue, 0), slides.count - 1) }
    }
    @State private var didBootstrapPreview = false
    @State private var didRestoreSession = false
    @State private var isScanPageInteractive = false
    @State private var firstScanLaunchTask: Task<Void, Never>?
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
        onFirstScanSkipLater: (() -> Void)? = nil,
        initialScanPersistedState: OnboardingDashboardScanPersistedState? = nil,
        pendingScanResult: FaceScanResult? = nil,
        onScanPersistedStateChange: ((OnboardingDashboardScanPersistedState?) -> Void)? = nil
    ) {
        self.hasCompletedFirstScan = hasCompletedFirstScan
        self.onFirstScanResult = onFirstScanResult
        self.onFirstScanContinue = onFirstScanContinue
        self.onFirstScanSkipLater = onFirstScanSkipLater
        self.initialScanPersistedState = initialScanPersistedState
        self.pendingScanResult = pendingScanResult
        self.onScanPersistedStateChange = onScanPersistedStateChange
        PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
    }

    private var logicalSlideIndex: Int {
        carouselStep
    }

    private var isLastSlide: Bool {
        logicalSlideIndex >= slides.count - 1
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                OnboardingTheme.screenBackground.ignoresSafeArea().allowsHitTesting(false)
                tourOrHiddenBackground
                if embeddedScanResult == nil, isLastSlide || isScanPageInteractive {
                    liveScanPage(in: geometry.size)
                }
                resultsOverlay
            }
            .coordinateSpace(name: "dashboardTour")
            .onPreferenceChange(DashboardScanCardFrameKey.self) { scanCardFrame = $0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !didRestoreSession {
                didRestoreSession = true
                restorePersistedSessionIfNeeded()
            }
            bootstrapPreviewIfNeeded()
        }
        .onDisappear {
            if !isScanPageInteractive { firstScanLaunchTask?.cancel() }
            PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(phase)
        }
    }

    /// One camera view is retained while its card expands to the full screen.
    @ViewBuilder
    private var interactiveScanOverlay: some View {
        DashboardPreviewEmbeddedFaceScanSession(
            isTabActive: (isLastSlide || isScanPageInteractive) && scenePhase == .active,
            isCaptureEnabled: isScanPageInteractive,
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
        // Les tâches de captures de vignettes sont annulées pendant le vrai scan.
        if embeddedScanResult == nil {
            dashboardTourLayer
                .opacity(isScanPageInteractive ? 0 : 1)
                .allowsHitTesting(!isScanPageInteractive)
                .accessibilityHidden(isScanPageInteractive)
        }
    }

    private func liveScanPage(in size: CGSize) -> some View {
        let expanded = isScanPageInteractive
        let card = scanCardFrame.isEmpty
            ? CGRect(x: size.width * 0.3, y: size.height * 0.28, width: size.width * 0.4, height: size.height * 0.4)
            : scanCardFrame
        let scale = expanded ? 1 : card.width / max(size.width, 1)
        return interactiveScanOverlay
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: expanded ? 0 : 28 / max(scale, 0.01)))
            .scaleEffect(scale)
            .position(x: expanded ? size.width / 2 : card.midX,
                      y: expanded ? size.height / 2 : card.midY)
            .allowsHitTesting(expanded)
            .accessibilityHidden(!expanded)
            .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.9), value: expanded)
            .zIndex(40)
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

    // Same layout as V2: copy, carousel and CTA occupy separate layout regions.
    // The button never depends on entrance animations or snapshot readiness.
    private var dashboardTourLayer: some View {
        VStack(spacing: 0) {
            stackedCopy { copy in
                VStack(spacing: 4) {
                    (Text(copy.titlePrefix) + Text(copy.titleAccent).foregroundStyle(accent))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .accessibilityLabel(copy.titleAccessibilityLabel)
                    Text(copy.subtitle)
                        .font(.system(size: 16))
                        .foregroundStyle(OnboardingTheme.mutedText)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, OnboardingConstants.titleTopPaddingFromScreenTop)
            .padding(.bottom, 8)

            DashboardPreviewCarousel(slides: slides, activeSlot: $activeSlot, onScanSelected: beginFirstScanLaunch)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomChrome
                .padding(.horizontal, 34)
                .padding(.top, 8)
                .padding(.bottom, 50)
                .zIndex(1)
        }
        .background(OnboardingTheme.screenBackground.ignoresSafeArea())
    }

    private func stackedCopy<Content: View>(
        @ViewBuilder _ content: @escaping (DashboardPreviewTourCopy) -> Content
    ) -> some View {
        ZStack {
            ForEach(slides.indices, id: \.self) { index in
                content(slides[index].tourCopy)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(index == logicalSlideIndex ? 1 : 0)
                    .accessibilityHidden(index != logicalSlideIndex)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: logicalSlideIndex)
    }

    private func restorePersistedSessionIfNeeded() {
        if let result = pendingScanResult {
            embeddedScanResult = result
            return
        }

        guard let state = initialScanPersistedState else { return }
        applyPersistedScanState(state)
    }

    private func applyPersistedScanState(_ state: OnboardingDashboardScanPersistedState) {
        carouselStep = min(max(0, state.carouselStep), max(0, slides.count - 1))
        if state.isScanPageInteractive {
            isScanPageInteractive = true
            // Tué pendant l'alerte caméra : le consentement n'avait pas encore été enregistré.
            if !ProcessPrivacyConsentStore.shared.canCaptureFaceScan {
                ProcessPrivacyConsentStore.shared.acceptFaceScanCapture()
            }
        } else {
            // État « étendu mais sans capture » (ancien bug de persistance sur l'écran résultats) :
            // carte agrandie sans aucun contrôle. On retombe sur le carrousel normal.
            isScanPageInteractive = false
            onScanPersistedStateChange?(nil)
        }
    }

    private func syncPersistedScanState() {
        // Seule une capture en cours se reprend ; sur l'écran résultats, le résultat est restauré à part.
        guard isScanPageInteractive, embeddedScanResult == nil else {
            onScanPersistedStateChange?(nil)
            return
        }

        onScanPersistedStateChange?(
            OnboardingDashboardScanPersistedState(
                carouselStep: carouselStep,
                scanExpandProgress: 1,
                isScanPageInteractive: isScanPageInteractive,
                showsSideCards: false,
                showsTourChrome: false
            )
        )
    }

    private func bootstrapPreviewIfNeeded() {
        guard !didBootstrapPreview else { return }
        didBootstrapPreview = true
        Self.preparePreviewSession()
    }

    @MainActor
    static func preparePreviewSession() {
        PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
        let profile = UnifiedProfileService.shared.currentProfile
        if WelcomePlanStore.shared.plan == nil {
            WelcomePlanStore.shared.refreshEphemeralPreviewPlan(profile: profile)
        } else {
            WelcomePlanStore.shared.installEphemeralPreviewPlanIfNeeded(profile: profile)
        }
        ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
    }

    private var footerCaption: some View {
        stackedCopy { copy in
            Group {
                if let percent = copy.footerPercent {
                    Text(copy.footerPrefix)
                    + Text(percent).foregroundStyle(accent).fontWeight(.semibold)
                    + Text(copy.footerSuffix)
                } else {
                    Text(copy.footer)
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(OnboardingTheme.primaryText)
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
            .accessibilityIdentifier("dashboardTour.continue")
        }
    }

    private var dashboardFirstScanSession: OnboardingDashboardScanSession? {
        OnboardingDashboardScanSession(
            onResult: { result in
                firstScanLaunchTask?.cancel()
                preservedScanSession = nil
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
        HapticManager.shared.impact(.medium)
        if isLastSlide {
            if hasCompletedFirstScan {
                onFirstScanContinue?()
            } else {
                beginFirstScanLaunch()
            }
            return
        }

        withAnimation(reduceMotion ? nil : DashboardPreviewCarouselMotion.advance) {
            carouselStep += 1
        }
    }

    private func beginFirstScanLaunch() {
        guard !isScanPageInteractive else { return }

        firstScanLaunchTask?.cancel()

        isScanPageInteractive = true
        syncPersistedScanState()

        firstScanLaunchTask = Task { @MainActor in
            await requestFirstScanPermissionAndTrack()
        }
    }

    @MainActor
    private func requestFirstScanPermissionAndTrack() async {
        if !ProcessPrivacyConsentStore.shared.canCaptureFaceScan {
            ProcessPrivacyConsentStore.shared.acceptFaceScanCapture()
        }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted {
            ProcessAnalytics.trackCameraAuthorized(source: "onboarding_dashboard_first_scan")
        } else {
            ProcessAnalytics.trackCameraDenied(source: "onboarding_dashboard_first_scan")
        }

        ProcessAnalytics.trackMossAction(
            page: .profileSummary,
            action: "started_scan_from_dashboard"
        )
    }

    private func dismissFirstScanSession() {
        firstScanLaunchTask?.cancel()
        preservedScanSession = nil
        embeddedScanResult = nil
        isScanPageInteractive = false
        onScanPersistedStateChange?(nil)
    }

    private var isScanSessionExpanded: Bool {
        isScanPageInteractive
    }

    private func preserveScanSessionIfNeeded() {
        guard isScanSessionExpanded, embeddedScanResult == nil else { return }
        preservedScanSession = DashboardPreviewScanSessionSnapshot(carouselStep: carouselStep)
        syncPersistedScanState()
    }

    private func restoreScanSessionIfNeeded() {
        guard let snapshot = preservedScanSession else { return }
        preservedScanSession = nil

        carouselStep = snapshot.carouselStep
        isScanPageInteractive = true
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
}

private enum DashboardPreviewCarouselMotion {
    static let advance = Animation.spring(response: 0.42, dampingFraction: 0.9)
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

/// V2 cover-flow: one scroll position shared by swipes, cards and Continue.
/// Only bitmaps are transformed; app screens are mounted once for their capture.
private struct DashboardPreviewCarousel: View {
    let slides: [DashboardPreviewSlide]
    @Binding var activeSlot: Int?
    var onScanSelected: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var cache = DashboardPreviewSnapshotStore.shared

    var body: some View {
        GeometryReader { geo in
            let aspect = UIScreen.main.bounds.height / max(UIScreen.main.bounds.width, 1)
            let width = min(min(geo.size.width * 0.46, 196), max(geo.size.height * 0.86, 1) / aspect)
            let stride = width + 14
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(slides.indices, id: \.self) { slot in
                        let slide = slides[slot]
                        previewCard(slide)
                            .frame(width: width, height: width * aspect)
                            .background {
                                if slide.pageKind == .faceScanCapture {
                                    GeometryReader { card in
                                        Color.clear.preference(key: DashboardScanCardFrameKey.self,
                                                               value: card.frame(in: .named("dashboardTour")))
                                    }
                                }
                            }
                            .frame(height: geo.size.height)
                            .visualEffect { content, proxy in
                                let progress = proxy.frame(in: .scrollView(axis: .horizontal)).minX / stride
                                let side = min(abs(progress), 1)
                                let capped = max(-1, min(1, progress))
                                return content
                                    .scaleEffect(1 - side * 0.2)
                                    .brightness(-side * 0.18)
                                    .rotation3DEffect(.degrees(-capped * 22), axis: (x: 0, y: 1, z: 0),
                                                      anchor: capped < 0 ? .leading : .trailing, perspective: 1)
                                    .offset(x: -progress * width * 0.33)
                            }
                            .zIndex(slot == activeSlot ? 1 : 0)
                            .onTapGesture {
                                if slide.pageKind == .faceScanCapture, activeSlot == slot {
                                    onScanSelected()
                                    return
                                }
                                withAnimation(reduceMotion ? nil : DashboardPreviewCarouselMotion.advance) {
                                    activeSlot = slot
                                }
                            }
                            .accessibilityLabel(slide.tourCopy.titleAccessibilityLabel)
                            .accessibilityIdentifier("dashboardTour.card.\(slot)")
                    }
                }
                .scrollTargetLayout()
            }
            .safeAreaPadding(.horizontal, max(0, (geo.size.width - width) / 2))
            .scrollPosition(id: $activeSlot, anchor: .center)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollClipDisabled()
        }
        .clipped()
        .task(id: "\(colorScheme)-\(locale.identifier)") {
            await cache.prepare(colorScheme: colorScheme, locale: locale)
        }
    }

    private func previewCard(_ slide: DashboardPreviewSlide) -> some View {
        let previewScheme = slide.pageKind.previewColorScheme(in: colorScheme)
        return ZStack {
            ProcessBackgroundPalette.base(for: previewScheme)
            if let image = cache.snapshots[slide.pageKind] {
                Image(uiImage: image).resizable().interpolation(.high)
            } else if slide.pageKind == .faceScanCapture {
                Color.clear
            } else {
                // A complete preview is available from the first frame, even on a direct resume.
                GeometryReader { card in
                    let size = UIScreen.main.bounds.size
                    DashboardPreviewAppPage(pageKind: slide.pageKind, isPageActive: false)
                        .environmentObject(UnifiedProfileService.shared)
                        .environmentObject(HealthManager.shared)
                        .environmentObject(AuthenticationManager.shared)
                        .environment(\.processTabIsActive, false)
                        .environment(\.colorScheme, previewScheme)
                        .environment(\.appTheme, AppTheme(appearance: .system, colorScheme: previewScheme))
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(card.size.width / max(size.width, 1), anchor: .topLeading)
                        .transaction { $0.disablesAnimations = true }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.15), radius: 14, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 28))
    }

}

private struct DashboardScanCardFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

@MainActor
final class DashboardPreviewSnapshotStore: ObservableObject {
    static let shared = DashboardPreviewSnapshotStore()
    @Published fileprivate var snapshots: [DashboardPreviewPageKind: UIImage] = [:]
    private var preparedKey: String?
    private var preparing = false

    func prepare(colorScheme: ColorScheme, locale: Locale) async {
        let size = UIScreen.main.bounds.size
        let profile = UnifiedProfileService.shared.currentProfile
        let key = "home-dark-v1-\(colorScheme)-\(locale.identifier)-\(size)-\(profile?.userId ?? "")-\(profile?.firstName ?? "")"
        guard preparedKey != key, !preparing else { return }
        snapshots = [:]
        preparing = true
        defer { preparing = false }
        DashboardPreviewStepView.preparePreviewSession()
        var result: [DashboardPreviewPageKind: UIImage] = [:]
        for slide in DashboardPreviewSlide.firstScanCatalog where slide.pageKind != .faceScanCapture {
            guard !Task.isCancelled else { return }
            if let image = await capture(slide.pageKind, colorScheme: colorScheme, locale: locale) {
                result[slide.pageKind] = image
            }
        }
        guard !Task.isCancelled else { return }
        snapshots = result
        if result.count == 3 { preparedKey = key }
    }

    private func capture(_ kind: DashboardPreviewPageKind, colorScheme: ColorScheme, locale: Locale) async -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).flatMap(\.windows)
            .first(where: \.isKeyWindow) else { return nil }
        let previewScheme = kind.previewColorScheme(in: colorScheme)
        let page = DashboardPreviewAppPage(pageKind: kind, isPageActive: false)
            .environmentObject(UnifiedProfileService.shared)
            .environmentObject(HealthManager.shared)
            .environmentObject(AuthenticationManager.shared)
            .environment(\.processTabIsActive, false)
            .environment(\.colorScheme, previewScheme)
            .environment(\.appTheme, AppTheme(appearance: .system, colorScheme: previewScheme))
            .environment(\.locale, locale)
            .transaction { $0.disablesAnimations = true }
        let host = UIHostingController(rootView: page)
        host.overrideUserInterfaceStyle = previewScheme == .dark ? .dark : .light
        host.view.backgroundColor = UIColor(ProcessBackgroundPalette.base(for: previewScheme))
        host.view.frame = window.bounds
        host.view.isUserInteractionEnabled = false
        window.insertSubview(host.view, at: 0)
        defer { host.view.removeFromSuperview() }
        await Task.yield()
        guard !Task.isCancelled else { return nil }
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale * min(1, 220 / max(window.bounds.width, 1))
        format.opaque = true
        var rendered = false
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds, format: format).image { _ in
            rendered = host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        return rendered ? image : nil
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
                ProcessScreenBackground()
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
            if pageKind == .faceScanCapture {
                // Libérer la caméra tout de suite pour la capture plein écran.
                runtimeActive = false
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
        case .scan, .profile, .coach, .food:
            ProcessScreenBackground()
        }
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
        // Le tracking « skipped_later » est fait une seule fois, dans `skipDashboardFaceScanForLater`.
        { onSkipLater() }
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
        .background(sessionBackground)
        .animation(OnboardingScanFlowMotion.animation, value: captureInput?.payload.scanId)
        .onAppear {
            // `.onChange(of: isCaptureEnabled)` ne se déclenche jamais quand la vue
            // apparaît déjà avec isCaptureEnabled == true (cas du plein écran lancé
            // depuis le dashboard) : SwiftUI ne compare qu'aux changements après
            // le premier rendu. Sans ce filet, l'event PostHog de l'écran de
            // capture n'était jamais envoyé pour ce chemin — funnel_index 17
            // disparaissait silencieusement des stats.
            trackCapturePageIfEnabled()
        }
        .onChange(of: isCaptureEnabled) { _, enabled in
            if enabled {
                trackCapturePageIfEnabled()
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

    private func trackCapturePageIfEnabled() {
        guard isCaptureEnabled, captureInput == nil, completedResult == nil else { return }
        ProcessAnalytics.trackMossPageViewed(ProcessAnalytics.MossPage.faceScanCapture)
    }
}

private enum DashboardPreviewPageKind: Hashable {
    case appTab(ProcessMainSection)
    case faceScanCapture

    func previewColorScheme(in surroundingScheme: ColorScheme) -> ColorScheme {
        self == .appTab(.plan) ? .dark : surroundingScheme
    }

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
        case .scan, .profile, .coach, .food:
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
