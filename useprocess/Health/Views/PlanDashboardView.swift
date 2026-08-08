import SwiftUI

/// Page Plan — timeline chronologique du jour + ressources en fiches séparées.
struct PlanDashboardView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var session = AppSession.shared

    @State private var planStore = WelcomePlanStore.shared
    @State private var isRestoringPlan = false
    @State private var showCalendar = false
    @State private var selectedPlanDate = Calendar.current.startOfDay(for: Date())
    @State private var planHealthMetrics = PlanHomeHealthMetrics()

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
                VStack(alignment: .leading, spacing: 24) {
                    PlanHomeTopChrome(
                        selectedSection: $selectedSection,
                        selectedDate: $selectedPlanDate,
                        showCalendar: $showCalendar,
                        plan: livePlan,
                        onOpenStreak: presentDailyChecklist
                    )

                    planContent
                }
                .padding()
                .padding(.bottom, ProcessIGTabMetrics.tabBarOverlayClearance + 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .processClearUIKitHostingBackground()
            .processMorphingRefreshable {
                planStore.reloadForCurrentUser(force: true)
                refreshPlanHealthMetrics()
            }
            .onAppear {
                if let plan = livePlan {
                    selectedPlanDate = OriginPlanPresenter.preferredHomeDate(in: plan)
                }
                refreshPlanHealthMetrics()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, isTabActive else { return }
                refreshPlanHealthMetrics()
            }
            .onChange(of: livePlan?.calendar.totalDays) { _, _ in
                if let plan = livePlan {
                    selectedPlanDate = OriginPlanPresenter.preferredHomeDate(in: plan)
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
            Text(AppCopy.t("Ton plan", en: "Your plan"))
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
                        Text(
                            isRestoringPlan
                                ? AppCopy.t("Restauration…", en: "Restoring…")
                                : AppCopy.t("Restaurer mon plan personnalisé", en: "Restore my personalized plan")
                        )
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
            return AppCopy.t(
                "Ton programme n'a pas pu être chargé. Restaure-le en un clic.",
                en: "Your program couldn't be loaded. Restore it in one tap."
            )
        }
        return AppCopy.t(
            "Ton plan se prépare. Reviens dans un instant.",
            en: "Your plan is getting ready. Check back in a moment."
        )
    }

    private func restorePlan() async {
        isRestoringPlan = true
        defer { isRestoringPlan = false }
        _ = planStore.repairAccessIfNeeded(profile: profileService.currentProfile)
        planStore.reloadForCurrentUser(force: true)
    }

    private func presentDailyChecklist() {
        HapticManager.shared.impact(.medium)
        ProcessStreakStore.shared.sync(from: planStore.plan)
        ProcessEveningCheckInPresenter.shared.present(
            targetDate: Date(),
            isRequired: false
        )
    }
}
