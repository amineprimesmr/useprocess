import SwiftUI
import UIKit

private struct RequiredEveningCheckInTarget: Identifiable, Equatable {
    let date: Date
    let id: String

    init(date: Date, calendar: Calendar = .current) {
        self.date = calendar.startOfDay(for: date)
        self.id = ProcessStreakStore.dayKey(for: date, calendar: calendar)
    }
}

/// Shell principal — tab bar Bevel (liquid glass iOS 26 + fallback flottant).
struct MainAppView: View {
    @Namespace private var coachZoomNamespace

    @State private var selectedSection: ProcessMainSection = .plan
    @State private var isCoachPresented = false
    @State private var requiredEveningCheckIn: RequiredEveningCheckInTarget?
    @State private var lastPresentedEveningCheckInDayKey: String?
    @State private var tabBeforeCoach: ProcessMainSection = .plan
    @State private var coachViewModel = CoachChatViewModel()
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var coachTracker = CoachPresentationTracker.shared
    @Bindable private var session = AppSession.shared
    @Bindable private var screenFlash = FaceScanScreenFlash.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            Group {
                if screenFlash.isActive {
                    Color.white
                        .ignoresSafeArea()
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
        .fullScreenCover(isPresented: $isCoachPresented) {
            if isCoachPresented {
                CoachFullScreenPresentationView(
                    selectedSection: $selectedSection,
                    viewModel: coachViewModel,
                    onDismiss: dismissCoachPresentation,
                    onOpenProfile: openProfileFromCoach,
                    onOpenWelcomePlan: openWelcomePlanFromCoach
                )
                .processCoachZoomTransition(namespace: coachZoomNamespace)
            }
        }
        .sheet(item: $requiredEveningCheckIn, onDismiss: handleEveningCheckInDismiss) { target in
            ProcessEveningCheckInSheet(
                targetDate: target.date,
                isRequired: true,
                onCompleted: {
                    lastPresentedEveningCheckInDayKey = nil
                }
            )
            .onAppear {
                lastPresentedEveningCheckInDayKey = target.id
            }
        }
        .onAppear {
            _ = UserSessionCoordinator.shared
            CoachPresentationTracker.shared.isCoachPresented = isCoachPresented
            evaluateRequiredEveningCheckIn()
        }
        .onChange(of: isCoachPresented) { _, presented in
            CoachPresentationTracker.shared.isCoachPresented = presented
            if !presented {
                CoachPresentationTracker.shared.isCoachChatActive = false
                HapticManager.shared.endTypewriterSession()
                evaluateRequiredEveningCheckIn()
            }
        }
        .onChange(of: session.hasCompletedWelcomePlanChat) { _, completed in
            if completed {
                WelcomePlanStore.shared.reloadForCurrentUser()
                evaluateRequiredEveningCheckIn()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            evaluateRequiredEveningCheckIn()
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
        .onChange(of: planBridge.shouldOpenEveningCheckIn) { _, should in
            guard should else { return }
            planBridge.shouldOpenEveningCheckIn = false
            withAnimation(ProcessGlass.spring) {
                selectedSection = .plan
            }
            evaluateRequiredEveningCheckIn()
        }
    }

    // MARK: - Instagram-style floating tab bar

    private var igTabShell: some View {
        ProcessIGTabShell(
            selectedSection: $selectedSection,
            coachZoomNamespace: coachZoomNamespace,
            onPresentCoach: openCoachFromAccessory
        ) {
            if #available(iOS 26.0, *) {
                TabView(selection: $selectedSection) {
                    Tab("", systemImage: ProcessMainSection.plan.icon, value: ProcessMainSection.plan) {
                        planTabRoot
                            .processHideNativeTabBar()
                    }
                    .accessibilityLabel(ProcessMainSection.plan.label)

                    Tab("", systemImage: ProcessMainSection.profile.icon, value: ProcessMainSection.profile) {
                        profileTabRoot
                            .processHideNativeTabBar()
                    }
                    .accessibilityLabel(ProcessMainSection.profile.label)
                }
                .processHideNativeTabBar()
                .background(Color.clear)
                .tint(theme.primaryText)
            } else {
                Group {
                    switch selectedSection {
                    case .plan, .coach:
                        planTabRoot
                    case .profile:
                        profileTabRoot
                    }
                }
            }
        }
    }

    // MARK: - Tab roots

    private var planTabRoot: some View {
        PlanDashboardView(
            selectedSection: $selectedSection,
            isTabActive: selectedSection == .plan
        )
            .background(Color.clear)
    }

    private var profileTabRoot: some View {
        ProcessProfileView(
            selectedSection: $selectedSection,
            isTabActive: selectedSection == .profile
        )
            .background(Color.clear)
    }

    // MARK: - Navigation

    private func handleSectionChange(from oldValue: ProcessMainSection, to newValue: ProcessMainSection) {
        resignFirstResponder()

        if newValue == .profile {
            ProcessPerformanceTrace.beginProfileOpen()
        }
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
        let delay: TimeInterval = planBridge.hasPendingFaceScanHandoff ? 0 : 0.12
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
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

        ProcessPerformanceTrace.beginCoachOpen()
        isCoachPresented = true
    }

    private func openCoach() {
        presentCoachSurface()
    }

    private func presentCoach() {
        presentCoachSurface()
    }

    private func handleEveningCheckInDismiss() {
        let dayKey = lastPresentedEveningCheckInDayKey ?? requiredEveningCheckIn?.id
        lastPresentedEveningCheckInDayKey = nil
        requiredEveningCheckIn = nil

        guard let dayKey,
              !ProcessEveningCheckInStore.shared.submittedDayKeys.contains(dayKey) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            evaluateRequiredEveningCheckIn()
        }
    }

    private func evaluateRequiredEveningCheckIn() {
        guard session.hasCompletedOnboarding, session.hasCompletedWelcomePlanChat else {
            requiredEveningCheckIn = nil
            return
        }
        guard !isCoachPresented else { return }
        guard let target = firstRequiredEveningCheckInTarget() else {
            requiredEveningCheckIn = nil
            return
        }
        if requiredEveningCheckIn?.id != target.id {
            requiredEveningCheckIn = target
        }
    }

    /// Un seul rappel soft : hier. Pas de rattrapage forcé des jours plus anciens.
    private func firstRequiredEveningCheckInTarget(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RequiredEveningCheckInTarget? {
        let eveningStore = ProcessEveningCheckInStore.shared
        eveningStore.reload()
        ProcessActivityStatusStore.shared.reload()

        guard let plan = WelcomePlanStore.shared.plan else { return nil }
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }

        let target = RequiredEveningCheckInTarget(date: yesterday, calendar: calendar)
        guard OriginPlanPresenter.programDay(in: plan, for: yesterday) != nil else { return nil }
        guard ProcessActivityStatusStore.shared.status(for: yesterday, calendar: calendar) == .active else { return nil }
        guard !eveningStore.hasSubmitted(on: yesterday) else { return nil }
        return target
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
        presentCoachSurface()
    }

    private func openProfile() {
        withAnimation(ProcessGlass.spring) {
            selectedSection = .profile
        }
    }

    private func openWelcomePlanConfiguration() {
        presentCoachSurface()
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
