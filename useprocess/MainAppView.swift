import SwiftUI
import UIKit

/// Shell principal — tab bar native iOS en bas + coach plein écran.
struct MainAppView: View {
    @State private var selectedSection: ProcessMainSection = .plan
    @State private var isCoachPresented = false
    @State private var tabBeforeCoach: ProcessMainSection = .plan
    @State private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var session = AppSession.shared
    @Environment(\.appTheme) private var theme

    private var isWelcomePlanGating: Bool {
        !session.hasCompletedWelcomePlanChat
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedSection) {
                PlanDashboardView(selectedSection: $selectedSection)
                    .background(theme.background.ignoresSafeArea())
                    .tag(ProcessMainSection.plan)
                    .tabItem {
                        Image(systemName: ProcessMainSection.plan.icon)
                    }
                    .accessibilityLabel(ProcessMainSection.plan.label)

                coachTabPlaceholder
                    .tag(ProcessMainSection.coach)
                    .tabItem {
                        Image(systemName: ProcessMainSection.coach.icon)
                    }
                    .accessibilityLabel(ProcessMainSection.coach.label)

                ProcessProfileView(selectedSection: $selectedSection)
                    .background(theme.background.ignoresSafeArea())
                    .tag(ProcessMainSection.profile)
                    .tabItem {
                        Image(systemName: ProcessMainSection.profile.icon)
                    }
                    .accessibilityLabel(ProcessMainSection.profile.label)
                    .welcomePlanSectionGate(isLocked: isWelcomePlanGating) {
                        openWelcomePlanConfiguration()
                    }
            }
            .tint(theme.primaryText)
            .toolbarBackground(theme.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .background(theme.background.ignoresSafeArea())

            if isCoachPresented {
                CoachFullScreenPresentationView(
                    selectedSection: $selectedSection,
                    onDismiss: dismissCoachPresentation,
                    onOpenProfile: openProfileFromCoach,
                    onOpenWelcomePlan: openWelcomePlanFromCoach
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: isCoachPresented)
        .onAppear {
            if isWelcomePlanGating {
                selectedSection = .plan
            }
            _ = UserSessionCoordinator.shared
        }
        .onChange(of: session.hasCompletedWelcomePlanChat) { _, completed in
            if !completed {
                selectedSection = .plan
            }
        }
        .onChange(of: selectedSection) { oldValue, newValue in
            resignFirstResponder()

            guard newValue == .coach else { return }
            tabBeforeCoach = oldValue == .coach ? tabBeforeCoach : oldValue
            selectedSection = tabBeforeCoach
            presentCoach()
        }
        .onChange(of: planBridge.shouldOpenCoach) { _, should in
            guard should else { return }
            presentCoach()
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

    private var coachTabPlaceholder: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background.ignoresSafeArea())
            .accessibilityHidden(true)
    }

    private func presentCoach() {
        guard !isCoachPresented else { return }
        HapticManager.shared.impact(.light)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            isCoachPresented = true
        }
    }

    private func dismissCoachPresentation() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            isCoachPresented = false
        }
    }

    private func openProfileFromCoach() {
        dismissCoachPresentation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            openProfile()
        }
    }

    private func openWelcomePlanFromCoach() {
        dismissCoachPresentation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            openWelcomePlanConfiguration()
        }
    }

    private func openProfile() {
        withAnimation(ProcessGlass.spring) {
            selectedSection = .profile
        }
    }

    private func openWelcomePlanConfiguration() {
        withAnimation(ProcessGlass.spring) {
            selectedSection = .plan
        }
    }

    private func resignFirstResponder() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
