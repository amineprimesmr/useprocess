import SwiftUI

/// Page Plan — timeline chronologique du jour + ressources en fiches séparées.
struct PlanDashboardView: View {
    @Binding var selectedSection: ProcessMainSection

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme
    @Bindable private var session = AppSession.shared
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared

    @State private var planStore = WelcomePlanStore.shared
    @State private var isRestoringPlan = false
    @State private var showHomeLayoutEditor = false
    @State private var showSettings = false
    @State private var showStreakToast = false
    @State private var showEveningCheckIn = false
    @State private var streakToast = DynamicIslandToastMessage.streak(
        snapshot: ProcessStreakStore.shared.snapshot,
        firstName: nil
    )
    @State private var streakToastDismissTask: Task<Void, Never>?
    @State private var selectedPlanDate = Calendar.current.startOfDay(for: Date())
    @Namespace private var homeChromeZoomNamespace

    private var livePlan: FaceOriginPlan? { planStore.plan }

    var body: some View {
        planDashboard
            .animation(.spring(response: 0.44, dampingFraction: 0.88), value: session.hasCompletedWelcomePlanChat)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var planDashboard: some View {
        NavigationStack {
            processMainScrollableChrome(
                selectedSection: $selectedSection,
                pageSection: .plan
            ) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    PlanHomeTopChrome(
                        selectedSection: $selectedSection,
                        selectedDate: $selectedPlanDate,
                        showSettings: $showSettings,
                        onOpenStreak: presentStreakToast,
                        zoomNamespace: homeChromeZoomNamespace
                    )

                    if livePlan != nil, session.hasCompletedWelcomePlanChat {
                        ProcessEveningCheckInEntryButton {
                            showEveningCheckIn = true
                        }
                    }

                    planContent

                    if livePlan != nil, session.hasCompletedWelcomePlanChat {
                        PlanHomeCustomizeFloatingButton(
                            zoomNamespace: homeChromeZoomNamespace,
                            action: { showHomeLayoutEditor = true }
                        )
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .processClearUIKitHostingBackground()
            .refreshable { planStore.reloadForCurrentUser(force: true) }
            .fullScreenCover(isPresented: $showHomeLayoutEditor) {
                if let plan = livePlan {
                    PlanHomeLayoutEditorSheet(
                        plan: plan,
                        selectedDate: $selectedPlanDate,
                        selectedSection: $selectedSection
                    )
                    .environmentObject(profileService)
                    .processZoomTransition(id: .homeLayoutEditor, namespace: homeChromeZoomNamespace)
                }
            }
            .fullScreenCover(isPresented: $showSettings) {
                ProcessSettingsFullScreenView()
                    .environmentObject(profileService)
                    .environmentObject(HealthManager.shared)
                    .environmentObject(AuthenticationManager.shared)
                    .processZoomTransition(id: .activityStatus, namespace: homeChromeZoomNamespace)
            }
            .dynamicIslandToast(isPresented: $showStreakToast, value: streakToast, onTap: openProfileStatistics)
            .sheet(isPresented: $showEveningCheckIn) {
                ProcessEveningCheckInSheet(onCompleted: presentStreakToast)
            }
            .onAppear {
                ProcessEveningCheckInStore.shared.reload()
                if CoachPlanNavigationBridge.shared.consumePendingEveningCheckIn() {
                    showEveningCheckIn = true
                }
            }
            .onChange(of: planBridge.shouldOpenEveningCheckIn) { _, should in
                guard should else { return }
                planBridge.shouldOpenEveningCheckIn = false
                showEveningCheckIn = true
            }
        }
    }

    @ViewBuilder
    private var planContent: some View {
        if let plan = livePlan {
            DailyJournalChecklistView(
                plan: plan,
                selectedDate: $selectedPlanDate,
                showHeader: false,
                showWeekStrip: false,
                showChecklist: false
            )
            .environmentObject(HealthManager.shared)
        } else {
            noPlanCard
        }
    }

    private var noPlanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ton plan")
                .font(.headline)

            Text(noPlanMessage)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if planStore.canRestorePlan {
                Button {
                    Task { await restorePlan() }
                } label: {
                    HStack(spacing: 8) {
                        if isRestoringPlan {
                            ProgressView().controlSize(.small)
                        }
                        Text(isRestoringPlan ? "Restauration…" : "Restaurer mon plan personnalisé")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRestoringPlan)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HealthHubDesign.surfaceCard(theme: theme))
    }

    private var noPlanMessage: String {
        if planStore.canRestorePlan {
            return "Tu as déjà répondu au questionnaire, mais ton programme n'a pas pu être chargé. Restaure-le en un clic ou reprends la configuration avec le coach."
        }
        return "Ouvre le coach pour personnaliser ton plan quand tu es prêt."
    }

    private func restorePlan() async {
        isRestoringPlan = true
        defer { isRestoringPlan = false }
        _ = planStore.repairAccessIfNeeded(profile: profileService.currentProfile)
        planStore.reloadForCurrentUser(force: true)
    }

    private func presentStreakToast() {
        HapticManager.shared.impact(.light)

        let streakStore = ProcessStreakStore.shared
        streakStore.sync(from: planStore.plan)

        let firstName = profileService.currentProfile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        streakToastDismissTask?.cancel()
        streakToast = .streak(
            snapshot: streakStore.snapshot,
            firstName: firstName?.isEmpty == false ? firstName : nil
        )

        if showStreakToast {
            showStreakToast = false
            DispatchQueue.main.async {
                showStreakToast = true
                scheduleStreakToastDismiss()
            }
        } else {
            showStreakToast = true
            scheduleStreakToastDismiss()
        }
    }

    private func openProfileStatistics() {
        streakToastDismissTask?.cancel()
        showStreakToast = false
        planBridge.openProfileStatistics()
        withAnimation(ProcessGlass.spring) {
            selectedSection = .profile
        }
    }

    private func scheduleStreakToastDismiss() {
        streakToastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.8))
            guard !Task.isCancelled else { return }
            showStreakToast = false
        }
    }
}
