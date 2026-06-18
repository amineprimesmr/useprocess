import SwiftUI

/// Shell principal — swipe horizontal + menu sticky overlay.
struct MainAppView: View {
    @State private var selectedSection: ProcessMainSection = .coach
    @State private var scrollHeaders: [ProcessMainSection: ProcessMainScrollHeaderPreference] = [
        .coach: .init(section: .coach, headerProgress: 0, headerVisibility: 1),
        .health: .init(section: .health, headerProgress: 0, headerVisibility: 1),
        .profile: .init(section: .profile, headerProgress: 0, headerVisibility: 1)
    ]
    @State private var profileSubrouteActive = false
    @State private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var session = AppSession.shared
    @Environment(\.appTheme) private var theme

    private var activeScrollHeader: ProcessMainScrollHeaderPreference {
        scrollHeaders[selectedSection]
            ?? .init(section: selectedSection, headerProgress: 0, headerVisibility: 1)
    }

    private var isWelcomePlanGating: Bool {
        !session.hasCompletedWelcomePlanChat
    }

    private var lockedSections: Set<ProcessMainSection> {
        isWelcomePlanGating ? [.health, .profile] : []
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedSection) {
                CoachChatView(
                    selectedSection: $selectedSection,
                    onOpenProfile: openProfile
                )
                .background(theme.background.ignoresSafeArea())
                .tag(ProcessMainSection.coach)

                HealthDashboardView(
                    selectedSection: $selectedSection,
                    onOpenProfile: openProfile
                )
                .background(theme.background.ignoresSafeArea())
                .tag(ProcessMainSection.health)
                .welcomePlanSectionGate(isLocked: isWelcomePlanGating) {
                    openWelcomePlanConfiguration()
                }

                ProcessProfileView(selectedSection: $selectedSection)
                    .background(theme.background.ignoresSafeArea())
                    .tag(ProcessMainSection.profile)
                    .welcomePlanSectionGate(isLocked: isWelcomePlanGating) {
                        openWelcomePlanConfiguration()
                    }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .processMainTabPaging(swipeDisabled: isWelcomePlanGating)
            .ignoresSafeArea(.container, edges: .bottom)

            CoachMainStickyChromeLayer(
                selection: $selectedSection,
                lockedSections: lockedSections,
                profileSubrouteActive: profileSubrouteActive,
                headerProgress: activeScrollHeader.headerProgress,
                headerVisibility: activeScrollHeader.headerVisibility
            )
        }
        .background(theme.background.ignoresSafeArea())
        .onAppear {
            if isWelcomePlanGating {
                selectedSection = .coach
            }
        }
        .onChange(of: session.hasCompletedWelcomePlanChat) { _, completed in
            if !completed {
                selectedSection = .coach
            }
        }
        .onPreferenceChange(ProcessMainScrollHeaderPreferenceKey.self) { preference in
            guard let preference else { return }
            scrollHeaders[preference.section] = preference
        }
        .onPreferenceChange(ProfileSubrouteActiveKey.self) { active in
            withAnimation(.easeOut(duration: 0.2)) {
                profileSubrouteActive = active
            }
        }
        .onAppear {
            _ = UserSessionCoordinator.shared
        }
        .onChange(of: planBridge.shouldOpenCoach) { _, should in
            guard should else { return }
            withAnimation(ProcessGlass.spring) {
                selectedSection = .coach
            }
            planBridge.shouldOpenCoach = false
        }
    }

    private func openProfile() {
        withAnimation(ProcessGlass.spring) {
            selectedSection = .profile
        }
    }

    private func openWelcomePlanConfiguration() {
        withAnimation(ProcessGlass.spring) {
            selectedSection = .coach
        }
    }
}
