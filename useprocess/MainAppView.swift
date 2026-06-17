import SwiftUI

/// Shell principal — swipe horizontal + menu sticky overlay.
struct MainAppView: View {
    @State private var selectedSection: ProcessMainSection = .coach
    @State private var scrollHeaders: [ProcessMainSection: ProcessMainScrollHeaderPreference] = [
        .coach: .init(section: .coach, headerProgress: 0, headerVisibility: 1),
        .health: .init(section: .health, headerProgress: 0, headerVisibility: 1),
        .scan: .init(section: .scan, headerProgress: 0, headerVisibility: 1),
        .profile: .init(section: .profile, headerProgress: 0, headerVisibility: 1)
    ]
    @State private var coachSidebarExpanded = false
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
        isWelcomePlanGating ? [.health, .scan, .profile] : []
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
                .welcomePlanSectionGate(isLocked: isWelcomePlanGating)

                BodyScanRootView(
                    selectedSection: $selectedSection,
                    onOpenProfile: openProfile
                )
                .background(theme.background.ignoresSafeArea())
                .tag(ProcessMainSection.scan)
                .welcomePlanSectionGate(isLocked: isWelcomePlanGating)

                ProcessProfileView(selectedSection: $selectedSection)
                    .background(theme.background.ignoresSafeArea())
                    .tag(ProcessMainSection.profile)
                    .welcomePlanSectionGate(isLocked: isWelcomePlanGating)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.container, edges: .bottom)

            if !coachSidebarExpanded, !(selectedSection == .profile && profileSubrouteActive) {
                ProcessMainStickyChromeOverlay(
                    selection: $selectedSection,
                    lockedSections: lockedSections,
                    headerProgress: activeScrollHeader.headerProgress,
                    headerVisibility: activeScrollHeader.headerVisibility
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
        .onPreferenceChange(CoachSidebarExpandedKey.self) { expanded in
            withAnimation(.easeOut(duration: 0.2)) {
                coachSidebarExpanded = expanded
            }
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
}
