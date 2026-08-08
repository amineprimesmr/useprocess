import SwiftUI

/// Racine SwiftUI — onboarding sport puis écran principal.
struct AppShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var session = AppSession.shared
    @Bindable private var launchRouter = AppLaunchRouter.shared
    @Bindable private var appLanguage = ProcessAppLanguage.shared
    @State private var didPrepareMainApp = false
    @State private var didPrepareCoachRuntime = false
    /// Armé après le cold start — évite de monter le deferral Home pendant le 1er frame Review.
    @State private var isHomeSwipeArmed = false

    private var theme: AppTheme {
        AppTheme(appearance: session.appearance, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            ProcessScreenBackground()

            if session.hasCompletedOnboarding {
                MainAppView()
                    .transition(.opacity)
                    .id("main-app-\(appLanguage.code.rawValue)")
            } else {
                SportOnboardingRootView()
                    .transition(.opacity)
                    .id("welcome-onboarding-\(appLanguage.code.rawValue)")
            }
        }
        .environment(\.locale, appLanguage.locale)
        .animation(.easeInOut(duration: 0.28), value: session.hasCompletedOnboarding)
        // Double-swipe Home après stabilisation du launch (pas au tout premier frame).
        .processPreAccessDoubleHomeSwipe(
            isActive: !session.hasCompletedOnboarding && isHomeSwipeArmed
        )
        .onChange(of: scenePhase) { _, phase in
            CoachPresentationTracker.shared.applicationIsActive = (phase == .active)
            switch phase {
            case .background:
                ProcessMarketingNotificationService.shared.handleAppLeftForeground()
            case .active:
                ProcessMarketingNotificationService.shared.handleAppBecameActive()
                ProcessAudioSession.configureForMixingWithOthersIfIdle()
                ProcessHomeScreenQuickActions.syncForCurrentUser()
                if let delegate = UIApplication.shared.delegate as? ProcessAppDelegate {
                    delegate.consumePendingLaunchShortcut()
                }
                launchRouter.flushPendingPresentation()
                Task {
                    await ProcessMarketingNotificationService.shared.refreshIfNeededOnAppOpen()
                    await ProcessMarketingHealthPulseService.shared.evaluateAfterHealthSync(reason: "app_open")
                }
            default:
                break
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
        .task {
            // Garantit Firebase prêt avant tout usage Auth tardif.
            FirebaseBootstrap.configure()
            ProcessAnalytics.configure()
            ProcessAnalytics.trackAppOpened(hasCompletedOnboarding: session.hasCompletedOnboarding)
            if let uid = AuthUser.current?.uid {
                ProcessAnalytics.identify(userId: uid)
            }
            ProcessAnalytics.syncFirstNameFromProfile()
            // Laisse le 1er frame se peindre avant d’armer le double-swipe Home.
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            isHomeSwipeArmed = !session.hasCompletedOnboarding
            ProcessHomeScreenQuickActions.syncForCurrentUser()
            if let delegate = UIApplication.shared.delegate as? ProcessAppDelegate {
                delegate.consumePendingLaunchShortcut()
            }
            launchRouter.flushPendingPresentation()
        }
        .onChange(of: session.hasCompletedOnboarding) { _, completed in
            if completed { isHomeSwipeArmed = false }
        }
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
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
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
                AccountDeletionOverlayView(statusMessage: session.accountDeletionStatusMessage)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isAccountWipeInProgress)
        .alert(
            AppCopy.t("Suppression impossible", en: "Deletion Failed"),
            isPresented: Binding(
                get: { session.accountDeletionErrorMessage != nil },
                set: { if !$0 { session.accountDeletionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                session.accountDeletionErrorMessage = nil
            }
        } message: {
            Text(session.accountDeletionErrorMessage ?? AppCopy.t("Réessaie dans un instant.", en: "Please try again in a moment."))
        }
        .fullScreenCover(isPresented: $launchRouter.showsLifetimeRetentionOffer) {
            PaywallTrialRetentionView(
                source: launchRouter.activeLifetimeOfferSource,
                onDismiss: {
                    launchRouter.clearLifetimeOfferPresentation()
                },
                onSubscribed: {
                    launchRouter.clearLifetimeOfferPresentation()
                    ProcessHomeScreenQuickActions.syncForCurrentUser()
                }
            )
            .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $launchRouter.showsSpinWinbackFromMarketing) {
            PaywallSpinWinbackView(
                presentation: .spinWheel,
                analyticsSource: "marketing_notif_spin"
            ) {
                launchRouter.clearSpinPresentation()
                ProcessHomeScreenQuickActions.syncForCurrentUser()
            }
            .interactiveDismissDisabled()
        }
    }
}
