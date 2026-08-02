import SwiftUI

/// Racine SwiftUI — onboarding sport puis écran principal.
struct AppShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var session = AppSession.shared
    @State private var didPrepareMainApp = false
    @State private var didPrepareCoachRuntime = false

    private var theme: AppTheme {
        AppTheme(appearance: session.appearance, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            ProcessScreenBackground()

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
        // Double-swipe Home dès le téléchargement jusqu’à l’accès app (après paiement).
        .processPreAccessDoubleHomeSwipe(isActive: !session.hasCompletedOnboarding)
        .onChange(of: scenePhase) { _, phase in
            CoachPresentationTracker.shared.applicationIsActive = (phase == .active)
            guard phase == .active else { return }
            ProcessAudioSession.configureForMixingWithOthersIfIdle()
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
            guard session.hasCompletedOnboarding else {
                didPrepareMainApp = false
                didPrepareCoachRuntime = false
                return
            }
            guard !didPrepareMainApp else { return }
            didPrepareMainApp = true
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, session.hasCompletedOnboarding else { return }
            WelcomePlanStore.shared.reloadForCurrentUser()
            PostOnboardingActivationService.prepareFirstAppEntry(
                profile: UnifiedProfileService.shared.currentProfile
            )
            if AppConfiguration.firebaseConfigured {
                _ = UserSessionCoordinator.shared
            }
        }
        .task(id: session.hasCompletedWelcomePlanChat) {
            guard session.hasCompletedOnboarding, session.hasCompletedWelcomePlanChat else {
                didPrepareCoachRuntime = false
                return
            }
            guard !didPrepareCoachRuntime else { return }
            didPrepareCoachRuntime = true
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled,
                  session.hasCompletedOnboarding,
                  session.hasCompletedWelcomePlanChat else { return }
            WelcomePlanStore.shared.reloadForCurrentUser()
            await CoachMemorySummarizer.refreshIfNeeded(
                profile: UnifiedProfileService.shared.currentProfile,
                force: false
            )
            CoachIntelligenceNotificationService.configure()
            CoachCheckInStore.shared.reload()
            CoachMyMemoryStore.shared.reload()
            CoachProcessFilesStore.shared.reload()
            CoachIntelligenceSettingsStore.shared.syncSubscriberCreditsIfNeeded()
            await CoachDailyRhythmService.rescheduleAll()
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
                .allowsHitTesting(false)
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
