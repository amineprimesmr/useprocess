import SwiftUI
import UIKit

/// Shell principal — tab bar Bevel (liquid glass iOS 26 + fallback flottant).
struct MainAppView: View {
    @Namespace private var coachZoomNamespace

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
        Group {
            if #available(iOS 26.0, *) {
                modernTabShell
            } else {
                legacyTabShell
            }
        }
        .fullScreenCover(isPresented: $isCoachPresented) {
            CoachFullScreenPresentationView(
                selectedSection: $selectedSection,
                onDismiss: dismissCoachPresentation,
                onOpenProfile: openProfileFromCoach,
                onOpenWelcomePlan: openWelcomePlanFromCoach
            )
            .processCoachZoomTransition(namespace: coachZoomNamespace)
        }
        .onAppear {
            if isWelcomePlanGating {
                selectedSection = .plan
            }
            _ = UserSessionCoordinator.shared
            CoachPresentationTracker.shared.isCoachPresented = isCoachPresented
        }
        .onChange(of: isCoachPresented) { _, presented in
            CoachPresentationTracker.shared.isCoachPresented = presented
        }
        .onChange(of: session.hasCompletedWelcomePlanChat) { _, completed in
            if !completed {
                selectedSection = .plan
            }
        }
        .onChange(of: selectedSection) { oldValue, newValue in
            handleSectionChange(from: oldValue, to: newValue)
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

    // MARK: - iOS 26 native liquid glass

    @available(iOS 26.0, *)
    private var modernTabShell: some View {
        TabView(selection: $selectedSection) {
            Tab("", systemImage: ProcessMainSection.plan.icon, value: ProcessMainSection.plan) {
                planTabRoot
            }
            .accessibilityLabel(ProcessMainSection.plan.label)

            Tab("", systemImage: ProcessMainSection.coach.icon, value: ProcessMainSection.coach) {
                coachTabPlaceholder
            }
            .accessibilityLabel(ProcessMainSection.coach.label)

            Tab("", systemImage: ProcessMainSection.profile.icon, value: ProcessMainSection.profile) {
                profileTabRoot
            }
            .accessibilityLabel(ProcessMainSection.profile.label)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if !isWelcomePlanGating {
                ProcessCoachTabAccessory(namespace: coachZoomNamespace, onTap: openCoachFromAccessory)
            }
        }
        .tint(theme.primaryText)
    }

    // MARK: - iOS 18–25 fallback

    private var legacyTabShell: some View {
        ProcessBevelLegacyTabShell(
            selectedSection: $selectedSection,
            coachZoomNamespace: coachZoomNamespace,
            isWelcomePlanGating: isWelcomePlanGating,
            onPresentCoach: openCoachFromAccessory
        ) {
            legacyTabContent
                .coordinateSpace(name: "processMainScroll")
        }
    }

    @ViewBuilder
    private var legacyTabContent: some View {
        switch selectedSection {
        case .plan:
            planTabRoot
        case .profile:
            profileTabRoot
        case .coach:
            coachTabPlaceholder
        }
    }

    // MARK: - Tab roots

    private var planTabRoot: some View {
        PlanDashboardView(selectedSection: $selectedSection)
            .background(theme.background.ignoresSafeArea())
    }

    private var profileTabRoot: some View {
        ProcessProfileView(selectedSection: $selectedSection)
            .background(theme.background.ignoresSafeArea())
            .welcomePlanSectionGate(isLocked: isWelcomePlanGating) {
                openWelcomePlanConfiguration()
            }
    }

    private var coachTabPlaceholder: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background.ignoresSafeArea())
            .accessibilityHidden(true)
    }

    // MARK: - Navigation

    private func handleSectionChange(from oldValue: ProcessMainSection, to newValue: ProcessMainSection) {
        resignFirstResponder()

        guard newValue == .coach else { return }
        tabBeforeCoach = oldValue.isShellTab ? oldValue : tabBeforeCoach
        selectedSection = tabBeforeCoach
        openCoach()
    }

    private func openCoachFromAccessory() {
        if selectedSection.isShellTab, selectedSection != .coach {
            tabBeforeCoach = selectedSection
        }
        openCoach()
    }

    private func openCoach() {
        guard !isCoachPresented else { return }
        resignFirstResponder()
        HapticManager.shared.impact(.light)
        isCoachPresented = true
    }

    private func presentCoach() {
        openCoach()
    }

    private func dismissCoachPresentation() {
        isCoachPresented = false
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
