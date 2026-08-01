import SwiftUI

/// Page Plan — timeline chronologique du jour + ressources en fiches séparées.
struct PlanDashboardView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var session = AppSession.shared
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared

    @State private var planStore = WelcomePlanStore.shared
    @State private var isRestoringPlan = false
    @State private var showSettings = false
    @State private var showStreakToast = false
    @State private var streakToast = DynamicIslandToastMessage.streak(
        snapshot: ProcessStreakStore.shared.snapshot,
        firstName: nil
    )
    @State private var streakToastDismissTask: Task<Void, Never>?
    @State private var selectedPlanDate = Calendar.current.startOfDay(for: Date())
    @State private var planHealthMetrics = PlanHomeHealthMetrics()
    @Namespace private var homeChromeZoomNamespace

    private var isPlanRuntimeActive: Bool {
        isTabActive && scenePhase == .active
    }

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

                    planContent
                }
                .padding()
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .processClearUIKitHostingBackground()
            .processMorphingRefreshable {
                planStore.reloadForCurrentUser(force: true)
                refreshPlanHealthMetrics()
            }
            .fullScreenCover(isPresented: $showSettings) {
                ProcessSettingsFullScreenView()
                    .environmentObject(profileService)
                    .environmentObject(HealthManager.shared)
                    .environmentObject(AuthenticationManager.shared)
                    .processZoomTransition(id: .settings, namespace: homeChromeZoomNamespace)
            }
            .dynamicIslandToast(isPresented: $showStreakToast, value: streakToast, onTap: openProfileStatistics)
            .onAppear {
                ProcessEveningCheckInStore.shared.reload()
                if let plan = livePlan {
                    selectedPlanDate = OriginPlanPresenter.preferredHomeDate(in: plan)
                }
                refreshPlanHealthMetrics()
            }
            .onChange(of: livePlan?.calendar.totalDays) { _, _ in
                if let plan = livePlan {
                    selectedPlanDate = OriginPlanPresenter.preferredHomeDate(in: plan)
                }
            }
            .task(id: isPlanRuntimeActive) {
                guard isPlanRuntimeActive else { return }
                refreshPlanHealthMetrics()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    refreshPlanHealthMetrics()
                }
            }
        }
    }

    @MainActor
    private func refreshPlanHealthMetrics() {
        planHealthMetrics = PlanHomeHealthMetrics.fromTodaySnapshot()
    }

    @ViewBuilder
    private var planContent: some View {
        if let plan = livePlan {
            DailyJournalChecklistView(
                plan: plan,
                selectedDate: $selectedPlanDate,
                isPlanActive: isPlanRuntimeActive,
                healthMetrics: planHealthMetrics,
                showHeader: false,
                showWeekStrip: false,
                showChecklist: false
            )
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
            return "Ton programme n'a pas pu être chargé. Restaure-le en un clic."
        }
        return "Ton plan se prépare. Reviens dans un instant."
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
