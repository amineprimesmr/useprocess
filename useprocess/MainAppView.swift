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

/// Shell principal — tab bar (Accueil · Process IA · Streak · Réglages).
struct MainAppView: View {
    @State private var selectedSection: ProcessMainSection = .plan
    @State private var tabBeforeCoach: ProcessMainSection = .plan
    @State private var requiredEveningCheckIn: RequiredEveningCheckInTarget?
    @State private var lastPresentedEveningCheckInDayKey: String?
    @State private var coachViewModel = CoachChatViewModel()
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var coachTracker = CoachPresentationTracker.shared
    @Bindable private var session = AppSession.shared
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
        .onChange(of: requiredEveningCheckIn) { _, target in
            guard let target else { return }
            lastPresentedEveningCheckInDayKey = target.id
            ProcessEveningCheckInPresenter.shared.present(
                targetDate: target.date,
                isRequired: true,
                onCompleted: {
                    lastPresentedEveningCheckInDayKey = nil
                }
            )
        }
        .onAppear {
            _ = UserSessionCoordinator.shared
            syncCoachPresentationState()
            evaluateRequiredEveningCheckIn()
        }
        .onChange(of: selectedSection) { oldValue, newValue in
            if newValue == .coach, oldValue != .coach {
                tabBeforeCoach = oldValue
            }
            handleSectionChange(to: newValue)
        }
        .onChange(of: session.hasCompletedWelcomePlanChat) { _, completed in
            if completed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    evaluateRequiredEveningCheckIn()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            evaluateRequiredEveningCheckIn()
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

    // MARK: - Tab shell

    private var igTabShell: some View {
        ProcessIGTabShell(selectedSection: $selectedSection) {
            Group {
                switch selectedSection {
                case .plan:
                    planTabRoot
                case .coach:
                    coachTabRoot
                case .statistics:
                    statisticsTabRoot
                case .profile:
                    profileTabRoot
                }
            }
            .background(Color.clear)
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

        if newValue == .statistics {
            ProcessPerformanceTrace.beginProfileOpen()
        }
        if newValue == .coach {
            ProcessPerformanceTrace.beginCoachOpen()
        }
        if newValue != .coach {
            HapticManager.shared.endTypewriterSession()
            evaluateRequiredEveningCheckIn()
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
        let dayKey = lastPresentedEveningCheckInDayKey ?? requiredEveningCheckIn?.id
        lastPresentedEveningCheckInDayKey = nil
        requiredEveningCheckIn = nil

        // Bilan volontaire (aujourd'hui) — pas de re-prompt.
        guard let dayKey else { return }
        guard !submitted,
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
        guard !isCoachTabActive else { return }
        guard let target = firstRequiredEveningCheckInTarget() else {
            requiredEveningCheckIn = nil
            return
        }
        if requiredEveningCheckIn?.id != target.id {
            requiredEveningCheckIn = target
        }
    }

    private func firstRequiredEveningCheckInTarget(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RequiredEveningCheckInTarget? {
        let eveningStore = ProcessEveningCheckInStore.shared

        guard let plan = WelcomePlanStore.shared.plan else { return nil }
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }

        let target = RequiredEveningCheckInTarget(date: yesterday, calendar: calendar)
        guard OriginPlanPresenter.programDay(in: plan, for: yesterday) != nil else { return nil }
        guard ProcessActivityStatusStore.shared.status(for: yesterday, calendar: calendar) == .active else { return nil }
        guard !eveningStore.hasSubmitted(on: yesterday) else { return nil }
        return target
    }

    private func openWelcomePlanFromCoach() {
        withAnimation(ProcessGlass.spring) {
            selectedSection = .plan
        }
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
