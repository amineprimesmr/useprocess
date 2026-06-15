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
    @Bindable private var session = AppSession.shared
    @Environment(\.appTheme) private var theme

    private var activeScrollHeader: ProcessMainScrollHeaderPreference {
        scrollHeaders[selectedSection]
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
                    .safeAreaPadding(.bottom, 72)
                    .tag(ProcessMainSection.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.container, edges: .bottom)

            if selectedSection != .profile, !coachSidebarExpanded {
                ProcessMainStickyChromeOverlay(
                    selection: $selectedSection,
                    headerProgress: activeScrollHeader.headerProgress,
                    headerVisibility: activeScrollHeader.headerVisibility
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if selectedSection == .profile {
                VStack {
                    Spacer()
                    ProcessFloatingSectionBar(selection: $selectedSection)
                }
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
    }

    private func openProfile() {
        selectedSection = .profile
    }
}
