import SwiftUI
import UIKit

/// Shell principal — tab bar (Accueil · Routine · Série · Profil).
struct MainAppView: View {
    @State private var selectedSection: ProcessMainSection = .plan
    @State private var tabBeforeCoach: ProcessMainSection = .plan
    @State private var coachViewModel = CoachChatViewModel()
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var coachTracker = CoachPresentationTracker.shared
    @State private var showMealPhotoScan = false
    @Bindable private var screenFlash = FaceScanScreenFlash.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var theme

    private var isCoachTabActive: Bool {
        selectedSection == .coach
    }

    var body: some View {
        ZStack {
            Group {
                if screenFlash.isActive {
                    Color.white
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                } else {
                    Color.clear
                }
            }

            igTabShell
                .background(Color.clear)
                .processClearUIKitHostingBackground()
        }
        .animation(.easeInOut(duration: 0.22), value: screenFlash.isActive)
        .eveningCheckInIsland { submitted in
            handleEveningCheckInDismiss(submitted: submitted)
        }
        .planHomeTutorial(selectedSection: $selectedSection)
        .processStackedToasts()
        .onAppear {
            _ = UserSessionCoordinator.shared
            syncCoachPresentationState()
            redirectFromDisabledCoachTabIfNeeded()
            ProcessHydrationTimerMonitor.shared.handleSceneBecameActive()
        }
        .onChange(of: selectedSection) { oldValue, newValue in
            if ProcessMainSection.isCoachTabEnabled, newValue == .coach, oldValue != .coach {
                tabBeforeCoach = oldValue
            }
            if !ProcessMainSection.isCoachTabEnabled, newValue == .coach {
                selectedSection = .plan
                return
            }
            handleSectionChange(to: newValue)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                FaceScanScreenFlash.shared.deactivate(animated: false)
            }
            guard phase == .active else { return }
            ProcessHydrationTimerMonitor.shared.handleSceneBecameActive()
        }
        .onChange(of: planBridge.shouldOpenCoach) { _, should in
            guard should, ProcessMainSection.isCoachTabEnabled else {
                planBridge.shouldOpenCoach = false
                return
            }
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
        .modifier(MealPhotoScanCoverModifier(
            isPresented: $showMealPhotoScan,
            selectedSection: $selectedSection,
            planBridge: planBridge
        ))
        .onChange(of: planBridge.shouldOpenEveningCheckIn) { _, should in
            guard should else { return }
            planBridge.shouldOpenEveningCheckIn = false
            withAnimation(ProcessGlass.spring) {
                selectedSection = .plan
            }
            ProcessEveningCheckInPresenter.shared.present(
                targetDate: ProcessEveningCheckInSchedule.preferredManualCheckInDate(),
                isRequired: false
            )
        }
    }

    // MARK: - Tab shell

    @ViewBuilder
    private var igTabShell: some View {
        ProcessIGTabShell(
            selectedSection: $selectedSection,
            onMealScan: openMealPhotoScan
        ) {
            tabContent
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            planTabRoot
                .opacity(selectedSection == .plan ? 1 : 0)
                .allowsHitTesting(selectedSection == .plan)
                .accessibilityHidden(selectedSection != .plan)

            scanTabRoot
                .opacity(selectedSection == .scan ? 1 : 0)
                .allowsHitTesting(selectedSection == .scan)
                .accessibilityHidden(selectedSection != .scan)

            routineTabRoot
                .opacity(selectedSection == .routine ? 1 : 0)
                .allowsHitTesting(selectedSection == .routine)
                .accessibilityHidden(selectedSection != .routine)

            if ProcessMainSection.isCoachTabEnabled {
                coachTabRoot
                    .opacity(selectedSection == .coach ? 1 : 0)
                    .allowsHitTesting(selectedSection == .coach)
                    .accessibilityHidden(selectedSection != .coach)
            }

            statisticsTabRoot
                .opacity(selectedSection == .statistics ? 1 : 0)
                .allowsHitTesting(selectedSection == .statistics)
                .accessibilityHidden(selectedSection != .statistics)

            profileTabRoot
                .opacity(selectedSection == .profile ? 1 : 0)
                .allowsHitTesting(selectedSection == .profile)
                .accessibilityHidden(selectedSection != .profile)
        }
        .background(Color.clear)
    }

    // MARK: - Tab roots

    private var planTabRoot: some View {
        PlanDashboardView(
            selectedSection: $selectedSection,
            isTabActive: selectedSection == .plan
        )
        .background(Color.clear)
    }

    private var scanTabRoot: some View {
        ProcessFaceScanHomeView(
            selectedSection: $selectedSection,
            isTabActive: selectedSection == .scan
        )
        .environmentObject(UnifiedProfileService.shared)
        .background(Color.clear)
    }

    private var routineTabRoot: some View {
        ProcessRoutineHomeView(
            selectedSection: $selectedSection,
            isTabActive: selectedSection == .routine
        )
        .background(Color.clear)
    }

    private var coachTabRoot: some View {
        CoachChatView(
            selectedSection: $selectedSection,
            viewModel: coachViewModel,
            isTabActive: isCoachTabActive,
            onDismiss: dismissCoachTab,
            onOpenProfile: openProfile,
            onOpenWelcomePlan: openWelcomePlanFromCoach
        )
        .background(Color.clear)
    }

    private var profileTabRoot: some View {
        ProcessProfileSettingsTabView(
            selectedSection: $selectedSection,
            isTabActive: selectedSection == .profile
        )
            .environmentObject(UnifiedProfileService.shared)
            .environmentObject(HealthManager.shared)
            .background(Color.clear)
    }

    private var statisticsTabRoot: some View {
        ProcessProfileView(
            selectedSection: $selectedSection,
            isTabActive: selectedSection == .statistics
        )
        .background(Color.clear)
    }

    // MARK: - Navigation

    private func handleSectionChange(to newValue: ProcessMainSection) {
        resignFirstResponder()
        syncCoachPresentationState()

        if newValue == .profile {
            FaceScanScreenFlash.shared.deactivate(animated: false)
            ProcessEveningCheckInPresenter.shared.dismissImmediately()
            PlanHomeTutorialStore.shared.cancelScheduledPresentation()
        }
        if newValue == .scan {
            FaceScanScreenFlash.shared.deactivate(animated: false)
        }
        if newValue == .statistics {
            ProcessPerformanceTrace.beginProfileOpen()
        }
        if newValue == .coach {
            ProcessPerformanceTrace.beginCoachOpen()
        }
        if newValue != .coach {
            HapticManager.shared.endTypewriterSession()
        }
    }

    private func syncCoachPresentationState() {
        CoachPresentationTracker.shared.isCoachPresented = isCoachTabActive
        if !isCoachTabActive {
            CoachPresentationTracker.shared.isCoachChatActive = false
        }
    }

    private func queueCoachPresentationFromBridge() {
        if coachTracker.isMealDetailPresented {
            planBridge.shouldOpenCoach = true
            return
        }
        let delay: TimeInterval = planBridge.hasPendingFaceScanHandoff ? 0 : 0.08
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            openCoachTab()
        }
    }

    private func flushQueuedCoachPresentationIfNeeded() {
        guard planBridge.shouldOpenCoach else { return }
        planBridge.shouldOpenCoach = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            openCoachTab()
        }
    }

    private func openCoachTab() {
        guard ProcessMainSection.isCoachTabEnabled else {
            planBridge.shouldOpenCoach = false
            return
        }
        if coachTracker.isMealDetailPresented {
            planBridge.shouldOpenCoach = true
            return
        }

        resignFirstResponder()
        HapticManager.shared.impact(.light)

        if selectedSection != .coach {
            tabBeforeCoach = selectedSection
            withAnimation(ProcessGlass.spring) {
                selectedSection = .coach
            }
        } else {
            Task { await coachViewModel.consumePendingNavigationIfNeeded() }
        }
    }

    private func dismissCoachTab() {
        resignFirstResponder()
        HapticManager.shared.endTypewriterSession()
        HapticManager.shared.impact(.light)
        withAnimation(ProcessGlass.spring) {
            selectedSection = tabBeforeCoach
        }
    }

    private func handleEveningCheckInDismiss(submitted: Bool) {
        _ = submitted
        PlanHomeTutorialStore.shared.schedulePresentationIfNeeded(
            planAvailable: WelcomePlanStore.shared.plan != nil,
            preferImmediate: true
        )
    }

    private func openMealPhotoScan() {
        resignFirstResponder()
        showMealPhotoScan = true
    }

    private func openWelcomePlanFromCoach() {
        withAnimation(ProcessGlass.spring) {
            selectedSection = .plan
        }
    }

    private func redirectFromDisabledCoachTabIfNeeded() {
        guard !ProcessMainSection.isCoachTabEnabled, selectedSection == .coach else { return }
        selectedSection = .plan
    }

    private func openProfile() {
        withAnimation(ProcessGlass.spring) {
            selectedSection = .profile
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

// MARK: - Scan repas (fullScreenCover extrait pour le type-checker)

private struct MealPhotoScanCoverModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var selectedSection: ProcessMainSection
    var planBridge: CoachPlanNavigationBridge

    func body(content: Content) -> some View {
        content
            .blur(radius: isPresented ? 5 : 0)
            .opacity(isPresented ? 0.82 : 1)
            .overlay {
                if isPresented {
                    MealPhotoScanFlowView(
                        onDismiss: { isPresented = false },
                        onValidated: { _, _ in
                            selectedSection = .plan
                            planBridge.shouldOpenPlan = true
                        }
                    )
                    .environmentObject(UnifiedProfileService.shared)
                    .transition(.opacity)
                    .zIndex(200)
                    .onDisappear {
                        // Filet de sécurité — le tab bar ne doit jamais rester masqué.
                        DispatchQueue.main.async {
                            if isPresented {
                                isPresented = false
                            }
                        }
                    }
                }
            }
            .animation(MealPhotoScanCameraPresentation.spring, value: isPresented)
    }
}
