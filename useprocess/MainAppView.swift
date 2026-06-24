import SwiftUI
import UIKit

/// Shell principal — tab bar native iOS.
struct MainAppView: View {
    @State private var selectedSection: ProcessMainSection = .coach
    @State private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var session = AppSession.shared
    @Environment(\.appTheme) private var theme

    private var isWelcomePlanGating: Bool {
        !session.hasCompletedWelcomePlanChat
    }

    var body: some View {
        TabView(selection: $selectedSection) {
            CoachChatView(
                selectedSection: $selectedSection,
                onOpenProfile: openProfile
            )
            .background(theme.background.ignoresSafeArea())
            .tag(ProcessMainSection.coach)
            .tabItem {
                Label(ProcessMainSection.coach.label, systemImage: ProcessMainSection.coach.icon)
            }

            PlanDashboardView(selectedSection: $selectedSection)
                .background(theme.background.ignoresSafeArea())
                .tag(ProcessMainSection.plan)
                .tabItem {
                    Label(ProcessMainSection.plan.label, systemImage: ProcessMainSection.plan.icon)
                }
                .welcomePlanSectionGate(isLocked: isWelcomePlanGating) {
                    openWelcomePlanConfiguration()
                }

            ProcessProfileView(selectedSection: $selectedSection)
                .background(theme.background.ignoresSafeArea())
                .tag(ProcessMainSection.profile)
                .tabItem {
                    Label(ProcessMainSection.profile.label, systemImage: ProcessMainSection.profile.icon)
                }
                .welcomePlanSectionGate(isLocked: isWelcomePlanGating) {
                    openWelcomePlanConfiguration()
                }
        }
        .tint(theme.primaryText)
        .toolbarBackground(theme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(theme.background.ignoresSafeArea())
        .onAppear {
            if isWelcomePlanGating {
                selectedSection = .coach
            }
            _ = UserSessionCoordinator.shared
        }
        .onChange(of: session.hasCompletedWelcomePlanChat) { _, completed in
            if !completed {
                selectedSection = .coach
            }
        }
        .onChange(of: selectedSection) { _, _ in
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
        .onChange(of: planBridge.shouldOpenCoach) { _, should in
            guard should else { return }
            withAnimation(ProcessGlass.spring) {
                selectedSection = .coach
            }
            planBridge.shouldOpenCoach = false
        }
        .onChange(of: planBridge.shouldOpenPlan) { _, should in
            guard should else { return }
            withAnimation(ProcessGlass.spring) {
                selectedSection = .plan
            }
            planBridge.shouldOpenPlan = false
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
