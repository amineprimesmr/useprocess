import SwiftUI

/// Racine SwiftUI — onboarding sport puis écran principal.
struct AppShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var session = AppSession.shared

    private var theme: AppTheme {
        AppTheme(appearance: session.appearance, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if session.hasCompletedOnboarding {
                MainAppView()
                    .transition(.opacity)
                    .id("main-app")
            } else {
                SportOnboardingRootView()
                    .transition(.opacity)
                    .id("welcome-onboarding")
            }
        }
        .animation(.easeInOut(duration: 0.28), value: session.hasCompletedOnboarding)
        .onChange(of: scenePhase) { _, phase in
            CoachPresentationTracker.shared.applicationIsActive = (phase == .active)
            guard phase == .active else { return }
            Task { @MainActor in
                let delivered = await CoachEveningChecklistService.deliverEveningMessageIfNeeded()
                if delivered {
                    CoachPlanNavigationBridge.shared.bumpEveningChecklistRefresh()
                }
            }
        }
        .environment(\.appTheme, theme)
        .processThirdPartyAIConsentSheet()
        .preferredColorScheme(session.appearance.preferredColorScheme)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(UnifiedProfileService.shared)
        .environmentObject(HealthManager.shared)
        .environmentObject(PermissionsManager.shared)
        .environmentObject(DailyDataManager.shared)
        .task(id: session.hasCompletedOnboarding) {
            guard session.hasCompletedOnboarding else { return }
            WelcomePlanStore.shared.reloadForCurrentUser()
            if AppConfiguration.firebaseConfigured {
                _ = UserSessionCoordinator.shared
                await UnifiedProfileService.shared.loadProfile()
            }
        }
        .task(id: session.hasCompletedWelcomePlanChat) {
            guard session.hasCompletedOnboarding, session.hasCompletedWelcomePlanChat else { return }
            WelcomePlanStore.shared.reloadForCurrentUser()
            if let plan = WelcomePlanStore.shared.plan {
                await OriginPlanNotificationService.scheduleMorningBrief(plan: plan)
            }
            await CoachMemorySummarizer.refreshIfNeeded(
                profile: UnifiedProfileService.shared.currentProfile,
                force: false
            )
            CoachIntelligenceNotificationService.configure()
            CoachCheckInStore.shared.reload()
            CoachMyMemoryStore.shared.reload()
            CoachProcessFilesStore.shared.reload()
            CoachIntelligenceSettingsStore.shared.syncSubscriberCreditsIfNeeded()
            await CoachCheckInScheduler.rescheduleAll()
            await CoachDailyRhythmService.reschedule()
            if HealthManager.shared.isHealthDataAvailable, HealthManager.shared.isAuthorized {
                await HealthManager.shared.performFullSync()
                await DailyDataManager.shared.updateCurrentDayData(with: HealthManager.shared)
            }
        }
        .overlay {
            if session.isAccountWipeInProgress {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Suppression du compte…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .allowsHitTesting(true)
            }
        }
        .alert(
            "Suppression impossible",
            isPresented: Binding(
                get: { session.accountDeletionErrorMessage != nil },
                set: { if !$0 { session.accountDeletionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                session.accountDeletionErrorMessage = nil
            }
        } message: {
            Text(session.accountDeletionErrorMessage ?? "Réessaie dans un instant.")
        }
    }
}
