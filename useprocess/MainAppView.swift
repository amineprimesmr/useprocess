import SwiftUI
import UIKit

/// Shell principal — tab bar Bevel (liquid glass iOS 26 + fallback flottant).
struct MainAppView: View {
    @Namespace private var coachZoomNamespace

    @State private var selectedSection: ProcessMainSection = .plan
    @State private var isCoachPresented = false
    @State private var tabBeforeCoach: ProcessMainSection = .plan
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var coachTracker = CoachPresentationTracker.shared
    @Bindable private var session = AppSession.shared
    @Bindable private var screenFlash = FaceScanScreenFlash.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            Group {
                if screenFlash.isActive {
                    Color.white
                        .ignoresSafeArea()
                        .transition(.opacity)
                } else {
                    ProcessScreenBackground()
                }
            }

            Group {
                if #available(iOS 26.0, *) {
                    modernTabShell
                } else {
                    legacyTabShell
                }
            }
            .background(Color.clear)
            .processClearUIKitHostingBackground()
        }
        .animation(.easeInOut(duration: 0.22), value: screenFlash.isActive)
        .fullScreenCover(isPresented: $isCoachPresented) {
            if isCoachPresented {
                CoachFullScreenPresentationView(
                    selectedSection: $selectedSection,
                    onDismiss: dismissCoachPresentation,
                    onOpenProfile: openProfileFromCoach,
                    onOpenWelcomePlan: openWelcomePlanFromCoach
                )
                .processCoachZoomTransition(namespace: coachZoomNamespace)
            }
        }
        .onAppear {
            _ = UserSessionCoordinator.shared
            CoachPresentationTracker.shared.isCoachPresented = isCoachPresented
        }
        .onChange(of: isCoachPresented) { _, presented in
            CoachPresentationTracker.shared.isCoachPresented = presented
            if !presented {
                CoachPresentationTracker.shared.isCoachChatActive = false
                HapticManager.shared.endTypewriterSession()
            }
        }
        .onChange(of: session.hasCompletedWelcomePlanChat) { _, completed in
            if completed {
                WelcomePlanStore.shared.reloadForCurrentUser()
            }
        }
        .onChange(of: selectedSection) { oldValue, newValue in
            handleSectionChange(from: oldValue, to: newValue)
        }
        .onChange(of: planBridge.shouldOpenCoach) { _, should in
            guard should else { return }
            planBridge.shouldOpenCoach = false
            queueCoachPresentationFromBridge()
        }
        .onChange(of: coachTracker.isMealDetailPresented) { _, mealDetailOpen in
            guard !mealDetailOpen else { return }
            flushQueuedCoachPresentationIfNeeded()
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

            Tab("", systemImage: ProcessMainSection.profile.icon, value: ProcessMainSection.profile) {
                profileTabRoot
            }
            .accessibilityLabel(ProcessMainSection.profile.label)
        }
        .background(Color.clear)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            ProcessCoachTabAccessory(namespace: coachZoomNamespace, onTap: openCoachFromAccessory)
        }
        .tint(theme.primaryText)
    }

    // MARK: - iOS 18–25 fallback

    private var legacyTabShell: some View {
        ProcessBevelLegacyTabShell(
            selectedSection: $selectedSection,
            coachZoomNamespace: coachZoomNamespace,
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
            planTabRoot
        }
    }

    // MARK: - Tab roots

    private var planTabRoot: some View {
        PlanDashboardView(selectedSection: $selectedSection)
            .background(Color.clear)
    }

    private var profileTabRoot: some View {
        ProcessProfileView(selectedSection: $selectedSection)
            .background(Color.clear)
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
        if selectedSection.isShellTab {
            tabBeforeCoach = selectedSection
        }
        presentCoachSurface()
    }

    private func queueCoachPresentationFromBridge() {
        if coachTracker.isMealDetailPresented {
            planBridge.shouldOpenCoach = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            presentCoachSurface()
        }
    }

    private func flushQueuedCoachPresentationIfNeeded() {
        guard planBridge.shouldOpenCoach else { return }
        planBridge.shouldOpenCoach = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            presentCoachSurface()
        }
    }

    private func presentCoachSurface() {
        if coachTracker.isMealDetailPresented {
            planBridge.shouldOpenCoach = true
            return
        }

        resignFirstResponder()
        HapticManager.shared.impact(.light)

        if isCoachPresented {
            return
        }

        isCoachPresented = true
    }

    private func openCoach() {
        presentCoachSurface()
    }

    private func presentCoach() {
        presentCoachSurface()
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
