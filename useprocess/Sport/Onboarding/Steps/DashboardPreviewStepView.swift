//
//  DashboardPreviewStepView.swift
//  Process
//
//  Aperçu du dashboard — vraies pages Accueil / Routine / Série / Profil.
//

import SwiftUI

struct DashboardPreviewStepView: View {
    @Environment(\.colorScheme) private var colorScheme

    let onComplete: () -> Void

    @State private var carouselStep = 0
    @State private var autoSlideTask: Task<Void, Never>?
    @State private var didBootstrapPreview = false
    @Bindable private var planStore = WelcomePlanStore.shared

    private let slides = DashboardPreviewSlide.catalog
    private let accent = Color(red: 0.42, green: 0.70, blue: 1.0)

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
    }

    private var logicalSlideID: String {
        slides[carouselStep % slides.count].id
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBlock
                .padding(.horizontal, 28)
                .padding(.top, OnboardingConstants.safeAreaTop + 40)
                .padding(.bottom, 14)

            carousel
                .frame(maxHeight: .infinity)
                .allowsHitTesting(false)

            subtitleBlock
                .padding(.horizontal, 28)
                .padding(.top, 10)
                .padding(.bottom, 12)

            pageDots
                .padding(.bottom, 12)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OnboardingTheme.screenBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ctaButton
                .padding(.horizontal, 34)
                .padding(.top, 8)
                .padding(.bottom, 50)
                .background(OnboardingTheme.screenBackground.opacity(0.001))
                .zIndex(1_000)
        }
        .onAppear {
            bootstrapPreviewIfNeeded()
            startAutoSlide()
        }
        .onDisappear {
            autoSlideTask?.cancel()
            autoSlideTask = nil
            PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
        }
        .processRestoreOpaqueUIKitHostingBackground(
            ProcessBackgroundPalette.uiColor(for: colorScheme)
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

    private var titleBlock: some View {
        (
            Text(OnboardingCopy.t("Ton dashboard est prêt et ", en: "Your dashboard is ready and "))
                + Text(OnboardingCopy.t("t'attend", en: "waiting for you"))
                    .foregroundStyle(accent)
        )
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(OnboardingTheme.primaryText)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var currentSlide: DashboardPreviewSlide {
        slides[carouselStep % slides.count]
    }

    private var subtitleBlock: some View {
        let parts = currentSlide.subtitleParts
        return (
            Text(parts.prefix)
                + Text(parts.accent)
                    .foregroundStyle(accent)
        )
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(OnboardingTheme.primaryText)
        .multilineTextAlignment(.center)
        .animation(.easeInOut(duration: 0.24), value: currentSlide.id)
        .accessibilityLabel(parts.accessibilityLabel)
    }

    private var carousel: some View {
        DashboardPreviewInfiniteCarousel(
            slides: slides,
            step: carouselStep
        )
    }

    private func startAutoSlide() {
        autoSlideTask?.cancel()
        autoSlideTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.2))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    advanceToNextSlide()
                }
            }
        }
    }

    private func advanceToNextSlide() {
        withAnimation(DashboardPreviewCarouselMotion.advance) {
            carouselStep += 1
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(slides) { slide in
                let isSelected = logicalSlideID == slide.id
                ProcessCarouselPageMark(
                    isSelected: isSelected,
                    activeColor: OnboardingTheme.primaryText,
                    inactiveColor: OnboardingTheme.primaryText.opacity(0.22)
                )
                .accessibilityLabel(slide.accessibilityLabel)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(OnboardingCopy.t("Pages de l'app", en: "App pages"))
        .allowsHitTesting(false)
    }

    private var ctaButton: some View {
        Button {
            confirmWant()
        } label: {
            Text(OnboardingCopy.t("Je veux ça", en: "I want this"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OnboardingTheme.filledButtonText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .onboardingPrimaryActionStyle()
        .accessibilityLabel(OnboardingCopy.t("Je veux ça", en: "I want this"))
    }

    private func confirmWant() {
        autoSlideTask?.cancel()
        HapticManager.shared.impact(.medium)
        onComplete()
    }
}

private enum DashboardPreviewCarouselMotion {
    static let advance = Animation.spring(response: 0.52, dampingFraction: 0.88, blendDuration: 0.12)
    static let contentReveal = Animation.easeInOut(duration: 0.28)
}

private enum DashboardPreviewLoopLayout {
    static let slides = DashboardPreviewSlide.catalog
    static var blockSize: Int { slides.count + 1 }
    static var totalItems: Int { blockSize }
    static var initialIndex: Int { 0 }
    static var tailIndex: Int { slides.count }

    static func slide(at index: Int) -> DashboardPreviewSlide {
        let position = positiveMod(index, blockSize)
        if position == slides.count {
            return slides[0]
        }
        return slides[position]
    }

    static func isTail(at index: Int) -> Bool {
        index == tailIndex
    }

    static func recenteredIndex(for index: Int) -> Int {
        isTail(at: index) ? initialIndex : index
    }

    static func neighborDistance(from active: Int, to index: Int) -> Int {
        abs(index - active)
    }

    private static func positiveMod(_ value: Int, _ modulus: Int) -> Int {
        guard modulus > 0 else { return 0 }
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }
}

private struct DashboardPreviewInfiniteCarousel: View {
    let slides: [DashboardPreviewSlide]
    let step: Int

    @State private var activeLoopIndex: Int?
    @State private var handledStep = 0
    @State private var loadedSections: Set<ProcessMainSection> = []
    @State private var preloadTask: Task<Void, Never>?
    @Bindable private var planStore = WelcomePlanStore.shared

    var body: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width * 0.62, 272)
            let cardHeight = min(geo.size.height * 0.84, cardWidth * 1.72)
            let cardSize = CGSize(width: cardWidth, height: cardHeight)
            let active = activeLoopIndex ?? DashboardPreviewLoopLayout.initialIndex

            ProcessCoverFlow(
                config: ProcessCoverFlowConfig(
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    rotation: 46,
                    offsetFactor: 1.45,
                    sideOpacity: 0.48,
                    sideScaleMinimum: 0.76,
                    maxSideVisibleProgress: 1.05
                ),
                activeIndex: $activeLoopIndex,
                itemCount: DashboardPreviewLoopLayout.totalItems,
                onScrollIdle: recenterIfNeeded
            ) { index, isFocused in
                let section = DashboardPreviewLoopLayout.slide(at: index).section
                let rendersLive = shouldRenderLive(
                    section: section,
                    activeIndex: active,
                    itemIndex: index
                )

                DashboardPreviewCard(
                    section: section,
                    cardSize: cardSize,
                    rendersLive: rendersLive,
                    isSidePreview: !isFocused
                )
            }
        }
        .environmentObject(UnifiedProfileService.shared)
        .environmentObject(HealthManager.shared)
        .environmentObject(AuthenticationManager.shared)
        .allowsHitTesting(false)
        .onAppear {
            if activeLoopIndex == nil {
                activeLoopIndex = DashboardPreviewLoopLayout.initialIndex
            }
            handledStep = step
            ensurePreviewPlanReady()
            scheduleSectionPreload(around: activeLoopIndex ?? DashboardPreviewLoopLayout.initialIndex)
        }
        .onDisappear {
            preloadTask?.cancel()
            preloadTask = nil
        }
        .onChange(of: planStore.plan?.id) { _, newID in
            guard newID != nil else { return }
            markAllPreviewSectionsLoaded()
        }
        .onChange(of: activeLoopIndex) { _, newIndex in
            guard let newIndex else { return }
            scheduleSectionPreload(around: newIndex)
        }
        .onChange(of: step) { _, newStep in
            guard newStep > handledStep else { return }
            let delta = newStep - handledStep
            handledStep = newStep
            let start = activeLoopIndex ?? DashboardPreviewLoopLayout.initialIndex
            let target = min(start + delta, DashboardPreviewLoopLayout.totalItems - 1)
            scheduleSectionPreload(around: target)
            advanceLoop(by: delta)
        }
    }

    private func shouldRenderLive(
        section: ProcessMainSection,
        activeIndex: Int,
        itemIndex: Int
    ) -> Bool {
        guard planStore.plan != nil else { return false }
        guard loadedSections.contains(section) else { return false }
        return DashboardPreviewLoopLayout.neighborDistance(from: activeIndex, to: itemIndex) <= 1
    }

    private func ensurePreviewPlanReady() {
        guard planStore.plan == nil else {
            markAllPreviewSectionsLoaded()
            return
        }
        let profile = UnifiedProfileService.shared.currentProfile
        WelcomePlanStore.shared.refreshEphemeralPreviewPlan(profile: profile)
        ProcessDebloatTrajectoryStore.shared.sync(from: WelcomePlanStore.shared.plan)
        markAllPreviewSectionsLoaded()
    }

    private func markAllPreviewSectionsLoaded() {
        for slide in DashboardPreviewSlide.catalog {
            loadedSections.insert(slide.section)
        }
    }

    private func scheduleSectionPreload(around index: Int) {
        preloadTask?.cancel()
        insertNeighborSections(around: index)

        preloadTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            markAllPreviewSectionsLoaded()
        }
    }

    private func insertNeighborSections(around index: Int) {
        for offset in -1...1 {
            let target = index + offset
            guard target >= 0, target < DashboardPreviewLoopLayout.totalItems else { continue }
            loadedSections.insert(DashboardPreviewLoopLayout.slide(at: target).section)
        }
    }

    private func advanceLoop(by count: Int) {
        guard count > 0 else { return }
        let start = activeLoopIndex ?? DashboardPreviewLoopLayout.initialIndex
        let target = min(start + count, DashboardPreviewLoopLayout.totalItems - 1)

        withAnimation(DashboardPreviewCarouselMotion.advance) {
            activeLoopIndex = target
        }
    }

    private func recenterIfNeeded(_ index: Int?) {
        guard let index else { return }
        let centered = DashboardPreviewLoopLayout.recenteredIndex(for: index)
        guard centered != index else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeLoopIndex = centered
        }
    }
}

private struct DashboardPreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let section: ProcessMainSection
    let cardSize: CGSize
    var rendersLive: Bool
    var isSidePreview: Bool = false

    private let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)

    var body: some View {
        Group {
            if rendersLive {
                DashboardPreviewScaledLivePage(section: section, size: cardSize)
            } else {
                DashboardPreviewPlaceholder(section: section)
            }
        }
        .animation(DashboardPreviewCarouselMotion.contentReveal, value: rendersLive)
        .clipShape(shape)
        .overlay {
            if isSidePreview {
                shape.fill(
                    Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14)
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
                rendersLive && !isSidePreview
                    ? (colorScheme == .dark ? 0.55 : 0.16)
                    : (colorScheme == .dark ? 0.30 : 0.08)
            ),
            radius: rendersLive && !isSidePreview ? (colorScheme == .dark ? 22 : 18) : 10,
            y: rendersLive && !isSidePreview ? 10 : 4
        )
        .frame(width: cardSize.width, height: cardSize.height)
        .allowsHitTesting(false)
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

private struct DashboardPreviewScaledLivePage: View {
    let section: ProcessMainSection
    let size: CGSize

    private static let designSize = CGSize(width: 393, height: 852)

    var body: some View {
        let scale = max(
            size.width / Self.designSize.width,
            size.height / Self.designSize.height
        )

        DashboardPreviewAppPage(section: section)
            .frame(width: Self.designSize.width, height: Self.designSize.height)
            .scaleEffect(scale)
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

private struct DashboardPreviewAppPage: View {
    let section: ProcessMainSection

    @State private var selectedSection: ProcessMainSection

    init(section: ProcessMainSection) {
        self.section = section
        _selectedSection = State(initialValue: section)
    }

    var body: some View {
        ProcessIGTabShell(
            selectedSection: $selectedSection,
            onMealScan: nil,
            hidesTabChrome: true
        ) {
            tabRoot
                .background(Color.clear)
        }
        .processAppPageBackground()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var tabRoot: some View {
        switch section {
        case .plan:
            PlanDashboardView(
                selectedSection: $selectedSection,
                isTabActive: false,
                isOnboardingPreview: true
            )
        case .routine:
            ProcessRoutineHomeView(
                selectedSection: $selectedSection,
                isTabActive: false,
                isOnboardingPreview: true
            )
        case .statistics:
            ProcessProfileView(
                selectedSection: $selectedSection,
                isTabActive: false,
                isOnboardingPreview: true
            )
        case .profile:
            ProcessProfileSettingsTabView(
                selectedSection: $selectedSection,
                isTabActive: false,
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

    static let catalog: [DashboardPreviewSlide] = [
        .init(id: "home", section: .plan),
        .init(id: "streak", section: .statistics),
        .init(id: "routine", section: .routine),
        .init(id: "profile", section: .profile)
    ]
}

private struct DashboardPreviewSlideSubtitle {
    let prefix: String
    let accent: String
    let accessibilityLabel: String
}
