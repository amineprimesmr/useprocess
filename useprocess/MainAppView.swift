import SwiftUI
import UIKit

/// Shell principal — swipe horizontal + menu sticky overlay.
struct MainAppView: View {
    @State private var selectedSection: ProcessMainSection = .coach
    @State private var profileSubrouteActive = false
    @State private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var session = AppSession.shared
    @Environment(\.appTheme) private var theme

    private var isWelcomePlanGating: Bool {
        !session.hasCompletedWelcomePlanChat
    }

    private var lockedSections: Set<ProcessMainSection> {
        isWelcomePlanGating ? [.plan, .profile] : []
    }

    private var isHorizontalPagingLocked: Bool {
        isWelcomePlanGating
    }

    var body: some View {
        TabView(selection: $selectedSection) {
            CoachChatView(
                selectedSection: $selectedSection,
                onOpenProfile: openProfile
            )
            .background(theme.background.ignoresSafeArea())
            .tag(ProcessMainSection.coach)

            PlanDashboardView(selectedSection: $selectedSection)
                .background(theme.background.ignoresSafeArea())
                .tag(ProcessMainSection.plan)
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
        .ignoresSafeArea(.container, edges: .bottom)
        .overlay(alignment: .top) {
            CoachMainStickyChromeLayer(
                selection: $selectedSection,
                lockedSections: lockedSections,
                profileSubrouteActive: profileSubrouteActive
            )
            .ignoresSafeArea(edges: .top)
        }
        .processMainTabPaging(swipeDisabled: isHorizontalPagingLocked)
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
        .onPreferenceChange(ProfileSubrouteActiveKey.self) { active in
            profileSubrouteActive = active
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
