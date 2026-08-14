//
//  DashboardPreviewStepView.swift
//  Process
//
//  Aperçu 3D du dashboard — vraies pages Accueil / Série / Profil.
//

import SwiftUI

struct DashboardPreviewStepView: View {
    @Environment(\.colorScheme) private var colorScheme

    let onComplete: () -> Void

    @State private var selectedSlideID: String? = DashboardPreviewSlide.catalog.first?.id

    private let slides = DashboardPreviewSlide.catalog
    private let accent = Color(red: 0.42, green: 0.70, blue: 1.0)

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
        WelcomePlanStore.shared.installEphemeralPreviewPlanIfNeeded(
            profile: UnifiedProfileService.shared.currentProfile
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBlock
                .padding(.horizontal, 28)
                .padding(.top, OnboardingConstants.backOnlyContentTopInset)
                .padding(.bottom, 18)

            carousel
                .frame(maxHeight: .infinity)

            pageDots
                .padding(.top, 16)
                .padding(.bottom, 14)

            subtitleBlock
                .padding(.horizontal, 28)
                .padding(.bottom, 18)

            ctaButton
                .padding(.horizontal, 34)
                .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            if selectedSlideID == nil {
                selectedSlideID = slides.first?.id
            }
            PlanHomeTutorialStore.shared.suppressPresentationForPreview(true)
            WelcomePlanStore.shared.installEphemeralPreviewPlanIfNeeded(
                profile: UnifiedProfileService.shared.currentProfile
            )
        }
        .onDisappear {
            WelcomePlanStore.shared.clearEphemeralPreviewPlan()
            PlanHomeTutorialStore.shared.suppressPresentationForPreview(false)
        }
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

    private var subtitleBlock: some View {
        (
            Text(OnboardingCopy.t("Le dashboard ", en: "Dashboard is "))
                + Text(OnboardingCopy.t("t'attend", en: "waiting"))
                    .foregroundStyle(accent)
        )
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(OnboardingTheme.primaryText)
        .multilineTextAlignment(.center)
    }

    private var carousel: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width * 0.62, 278)
            let cardHeight = min(geo.size.height, cardWidth * 1.72)
            let sideInset = max(0, (geo.size.width - cardWidth) / 2)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(slides) { slide in
                        DashboardPreviewCard(
                            section: slide.section,
                            isActive: selectedSlideID == slide.id
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(1 - min(abs(phase.value), 1) * 0.14)
                                .rotationEffect(.degrees(phase.value * -8))
                                .offset(x: phase.value * -14)
                                .blur(radius: min(abs(phase.value), 1) * 1.8)
                                .opacity(1 - min(abs(phase.value), 1) * 0.12)
                        }
                        .id(slide.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, sideInset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $selectedSlideID)
            .scrollClipDisabled()
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(slides) { slide in
                let isSelected = selectedSlideID == slide.id
                Circle()
                    .fill(isSelected ? OnboardingTheme.primaryText : Color.clear)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                OnboardingTheme.primaryText.opacity(isSelected ? 0 : 0.32),
                                lineWidth: 1.2
                            )
                    }
                    .frame(width: 7, height: 7)
                    .onTapGesture {
                        HapticManager.shared.impact(.light)
                        withAnimation(.easeInOut(duration: 0.32)) {
                            selectedSlideID = slide.id
                        }
                    }
                    .accessibilityLabel(slide.accessibilityLabel)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(OnboardingCopy.t("Pages de l'app", en: "App pages"))
    }

    private var ctaButton: some View {
        Button {
            HapticManager.shared.impact(.medium)
            onComplete()
        } label: {
            Text(OnboardingCopy.t("Je le veux", en: "I want this"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OnboardingTheme.filledButtonText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .buttonStyle(.processPlain)
        .background(
            OnboardingTheme.filledButtonBackground(for: colorScheme),
            in: Capsule()
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18),
            radius: 12,
            y: 4
        )
        .accessibilityLabel(OnboardingCopy.t("Je le veux", en: "I want this"))
    }
}

private struct DashboardPreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let section: ProcessMainSection
    var isActive: Bool = true

    private let designSize = CGSize(width: 393, height: 852)
    private let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)

    var body: some View {
        GeometryReader { geo in
            let scale = max(
                geo.size.width / designSize.width,
                geo.size.height / designSize.height
            )

            DashboardPreviewAppPage(section: section, isActive: isActive)
                .frame(width: designSize.width, height: designSize.height)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55),
                lineWidth: 1
            )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.16),
            radius: colorScheme == .dark ? 22 : 18,
            y: 10
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DashboardPreviewAppPage: View {
    let section: ProcessMainSection
    var isActive: Bool = true

    @State private var selectedSection: ProcessMainSection

    init(section: ProcessMainSection, isActive: Bool) {
        self.section = section
        self.isActive = isActive
        _selectedSection = State(initialValue: section)
    }

    var body: some View {
        ProcessIGTabShell(selectedSection: $selectedSection, onMealScan: {}) {
            ZStack {
                ProcessScreenBackground()
                tabRoot
            }
        }
        .environmentObject(UnifiedProfileService.shared)
        .environmentObject(HealthManager.shared)
        .environmentObject(AuthenticationManager.shared)
    }

    @ViewBuilder
    private var tabRoot: some View {
        switch section {
        case .plan:
            PlanDashboardView(
                selectedSection: $selectedSection,
                isTabActive: isActive
            )
        case .statistics:
            ProcessProfileView(
                selectedSection: $selectedSection,
                isTabActive: isActive
            )
        case .profile:
            ProcessProfileSettingsTabView(
                selectedSection: $selectedSection,
                isTabActive: isActive
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
    var accessibilityLabel: String {
        switch section {
        case .plan:
            return AppCopy.home
        case .statistics:
            return AppCopy.t("Série", en: "Streak")
        case .profile:
            return AppCopy.profile
        case .coach:
            return id
        }
    }

    static let catalog: [DashboardPreviewSlide] = [
        .init(id: "home", section: .plan),
        .init(id: "streak", section: .statistics),
        .init(id: "profile", section: .profile)
    ]
}
