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

/// Shell principal — tab bar (Accueil · Routine · Série · Profil).
struct MainAppView: View {
    @State private var selectedSection: ProcessMainSection = .plan
    @State private var tabBeforeCoach: ProcessMainSection = .plan
    @State private var requiredEveningCheckIn: RequiredEveningCheckInTarget?
    @State private var lastPresentedEveningCheckInDayKey: String?
    @State private var coachViewModel = CoachChatViewModel()
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var coachTracker = CoachPresentationTracker.shared
    @Bindable private var session = AppSession.shared
    @Bindable private var tutorialStore = PlanHomeTutorialStore.shared
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
        .onChange(of: requiredEveningCheckIn) { _, target in
            guard let target else { return }
            presentRequiredEveningCheckIn(target)
        }
        .onAppear {
            _ = UserSessionCoordinator.shared
            syncCoachPresentationState()
            evaluateRequiredEveningCheckIn()
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
        .onChange(of: session.hasCompletedWelcomePlanChat) { _, completed in
            if completed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    evaluateRequiredEveningCheckIn()
                }
            }
        }
        .onChange(of: tutorialStore.isActive) { wasActive, isActive in
            guard wasActive, !isActive else { return }
            evaluateRequiredEveningCheckIn()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            evaluateRequiredEveningCheckIn()
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
            evaluateRequiredEveningCheckIn()
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
        Group {
            switch selectedSection {
            case .plan:
                planTabRoot
            case .routine:
                routineTabRoot
            case .coach:
                if ProcessMainSection.isCoachTabEnabled {
                    coachTabRoot
                } else {
                    planTabRoot
                }
            case .statistics:
                statisticsTabRoot
            case .profile:
                profileTabRoot
            }
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
        lastPresentedEveningCheckInDayKey = nil
        requiredEveningCheckIn = nil

        PlanHomeTutorialStore.shared.schedulePresentationIfNeeded(
            planAvailable: WelcomePlanStore.shared.plan != nil,
            preferImmediate: true
        )

        guard !submitted else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            evaluateRequiredEveningCheckIn()
        }
    }

    private func evaluateRequiredEveningCheckIn() {
        guard session.hasCompletedOnboarding, session.hasCompletedWelcomePlanChat else {
            requiredEveningCheckIn = nil
            return
        }
        if tutorialStore.shouldDeferEveningCheckIn {
            if ProcessEveningCheckInPresenter.shared.presentation != nil {
                ProcessEveningCheckInPresenter.shared.clear()
                requiredEveningCheckIn = nil
            }
            tutorialStore.activateImmediatelyIfNeeded()
            if tutorialStore.shouldDeferEveningCheckIn {
                return
            }
        }
        guard !isCoachTabActive else { return }
        guard let target = firstRequiredEveningCheckInTarget() else {
            requiredEveningCheckIn = nil
            return
        }
        guard ProcessEveningCheckInPresenter.shared.presentation == nil else { return }
        if requiredEveningCheckIn?.id != target.id {
            requiredEveningCheckIn = target
        } else {
            presentRequiredEveningCheckIn(target)
        }
    }

    private func presentRequiredEveningCheckIn(_ target: RequiredEveningCheckInTarget) {
        lastPresentedEveningCheckInDayKey = target.id
        ProcessEveningCheckInPresenter.shared.present(
            targetDate: target.date,
            isRequired: true,
            onCompleted: {
                lastPresentedEveningCheckInDayKey = nil
            }
        )
    }

    private func firstRequiredEveningCheckInTarget(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RequiredEveningCheckInTarget? {
        let eveningStore = ProcessEveningCheckInStore.shared

        guard let plan = WelcomePlanStore.shared.plan else { return nil }
        let today = calendar.startOfDay(for: now)
        let hour = calendar.component(.hour, from: now)

        func isDue(_ date: Date) -> Bool {
            OriginPlanPresenter.programDay(in: plan, for: date) != nil
                && ProcessActivityStatusStore.shared.status(for: date, calendar: calendar) == .active
                && !eveningStore.hasSubmitted(on: date)
        }

        // Après 21h : checklist du jour, tant qu’elle n’est pas validée.
        if hour >= ProcessEveningCheckInSchedule.openHour {
            guard isDue(today) else { return nil }
            return RequiredEveningCheckInTarget(date: today, calendar: calendar)
        }

        // Avant 21h : rattrapage d’hier seulement.
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
        guard isDue(yesterday) else { return nil }
        return RequiredEveningCheckInTarget(date: yesterday, calendar: calendar)
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
