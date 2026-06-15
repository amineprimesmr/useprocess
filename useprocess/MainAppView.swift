import SwiftUI

/// Shell principal — swipe horizontal + menu sticky overlay.
struct MainAppView: View {
    @State private var selectedSection: ProcessMainSection = .coach
    @State private var scrollHeaders: [ProcessMainSection: ProcessMainScrollHeaderPreference] = [
        .coach: .init(section: .coach, headerProgress: 0, headerVisibility: 1),
        .health: .init(section: .health, headerProgress: 0, headerVisibility: 1),
        .scan: .init(section: .scan, headerProgress: 0, headerVisibility: 1)
    ]
    @State private var coachSidebarExpanded = false
    @State private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var session = AppSession.shared
    @Environment(\.appTheme) private var theme

    private var activeScrollHeader: ProcessMainScrollHeaderPreference {
        if selectedSection == .coach {
            return .init(section: .coach, headerProgress: 0, headerVisibility: 1)
        }
        return scrollHeaders[selectedSection]
            ?? .init(section: selectedSection, headerProgress: 0, headerVisibility: 1)
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

                BodyScanRootView(
                    selectedSection: $selectedSection,
                    onOpenProfile: openProfile
                )
                .background(theme.background.ignoresSafeArea())
                .tag(ProcessMainSection.scan)

                ProcessProfileView()
                    .background(theme.background.ignoresSafeArea())
                    .ignoresSafeArea(.container, edges: .top)
                    .tag(ProcessMainSection.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(ProcessGlass.spring, value: selectedSection)
            .ignoresSafeArea(.container, edges: .bottom)

            if selectedSection != .profile, !coachSidebarExpanded {
                ProcessMainStickyChromeOverlay(
                    selection: $selectedSection,
                    headerProgress: activeScrollHeader.headerProgress,
                    headerVisibility: activeScrollHeader.headerVisibility
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(theme.background.ignoresSafeArea())
        .onPreferenceChange(ProcessMainScrollHeaderPreferenceKey.self) { preference in
            guard let preference else { return }
            scrollHeaders[preference.section] = preference
        }
        .onPreferenceChange(CoachSidebarExpandedKey.self) { expanded in
            withAnimation(.easeOut(duration: 0.2)) {
                coachSidebarExpanded = expanded
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
