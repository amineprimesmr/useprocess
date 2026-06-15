import SwiftUI

/// Shell principal — structure Totem (scrollable header + blur + profil plein écran).
struct MainAppView: View {
    @State private var selectedSection: ProcessMainSection = .coach
    @Bindable private var session = AppSession.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if selectedSection == .profile {
                    ProcessProfileView()
                        .safeAreaPadding(.bottom, 72)
                } else {
                    sectionContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            if selectedSection == .profile {
                ProcessFloatingSectionBar(selection: $selectedSection)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .onAppear {
            _ = UserSessionCoordinator.shared
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .coach:
            CoachChatView(
                selectedSection: $selectedSection,
                onOpenProfile: { selectedSection = .profile }
            )
        case .health:
            HealthDashboardView(
                selectedSection: $selectedSection,
                onOpenProfile: { selectedSection = .profile }
            )
        case .scan:
            BodyScanRootView(
                selectedSection: $selectedSection,
                onOpenProfile: { selectedSection = .profile }
            )
        case .profile:
            EmptyView()
        }
    }
}
