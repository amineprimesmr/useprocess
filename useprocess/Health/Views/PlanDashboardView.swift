import SwiftUI

/// Page Plan — timeline chronologique du jour + ressources en fiches séparées.
struct PlanDashboardView: View {
    @Binding var selectedSection: ProcessMainSection

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme
    @Bindable private var session = AppSession.shared

    @State private var planStore = WelcomePlanStore.shared
    @State private var isRestoringPlan = false
    @State private var showHomeLayoutEditor = false
    @State private var selectedPlanDate = Calendar.current.startOfDay(for: Date())
    @Namespace private var homeChromeZoomNamespace

    private var livePlan: FaceOriginPlan? { planStore.plan }

    var body: some View {
        Group {
            if !session.hasCompletedWelcomePlanChat {
                welcomePlanConfiguration
            } else {
                planDashboard
            }
        }
        .animation(.spring(response: 0.44, dampingFraction: 0.88), value: session.hasCompletedWelcomePlanChat)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomePlanConfiguration: some View {
        ZStack {
            ProcessScreenBackground()
            WelcomePlanChatView(
                embeddedInMainApp: true,
                selectedSection: $selectedSection,
                onComplete: {
                    planStore.reloadForCurrentUser()
                }
            )
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .tabBar)
        .processClearUIKitHostingBackground()
    }

    private var planDashboard: some View {
        NavigationStack {
            ZStack {
                ProcessScreenBackground()

                processMainScrollableChrome(
                    selectedSection: $selectedSection,
                    pageSection: .plan
                ) {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        PlanHomeTopChrome(
                            selectedSection: $selectedSection,
                            selectedDate: $selectedPlanDate
                        )
                        planContent

                        if livePlan != nil {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .processClearUIKitHostingBackground()
            .refreshable { planStore.reloadForCurrentUser() }
            .onAppear {
                planStore.reloadForCurrentUser()
            }
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

            Button {
                openWelcomePlanConfiguration()
            } label: {
                Label("Terminer la configuration", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.onboardingAccent)

            if planStore.canRestorePlan {
                Button {
                    Task { await restorePlan() }
                } label: {
                    HStack(spacing: 8) {
                        if isRestoringPlan {
                            ProgressView().controlSize(.small)
                        }
                        Text(isRestoringPlan ? "Restauration…" : "Restaurer mon protocole")
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
        return "Le questionnaire Protocole Origine sur cet onglet débloque ton journal, tes repas IA et un plan calibré sur ton profil."
    }

    private func openWelcomePlanConfiguration() {
        HapticManager.shared.impact(.medium)
        withAnimation(ProcessGlass.spring) {
            selectedSection = .plan
        }
    }

    private func restorePlan() async {
        isRestoringPlan = true
        defer { isRestoringPlan = false }
        _ = planStore.repairAccessIfNeeded(profile: profileService.currentProfile)
        planStore.reloadForCurrentUser()
    }
}
