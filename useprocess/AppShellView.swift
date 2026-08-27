import SwiftUI

/// Racine SwiftUI — onboarding sport puis écran principal.
struct AppShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var session = AppSession.shared
    @Bindable private var launchRouter = AppLaunchRouter.shared
    @Bindable private var appLanguage = ProcessAppLanguage.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var didPrepareMainApp = false
    @State private var didPrepareCoachRuntime = false
    /// Armé après le cold start — évite de monter le deferral Home pendant le 1er frame Review.
    @State private var isHomeSwipeArmed = false

    private var theme: AppTheme {
        AppTheme(appearance: session.appearance, colorScheme: colorScheme)
    }

    private var mainAppBootstrapToken: String {
        guard session.hasCompletedOnboarding,
              subscriptionService.hasResolvedInitialSubscriptionStatus,
              subscriptionService.subscriptionStatus.isActive else {
            return "main-app-idle"
        }
        return "main-app-ready-\(appLanguage.code.rawValue)"
    }

    private var coachRuntimeBootstrapToken: String {
        guard session.hasCompletedOnboarding,
              subscriptionService.hasResolvedInitialSubscriptionStatus,
              subscriptionService.subscriptionStatus.isActive,
              session.hasCompletedWelcomePlanChat else {
            return "coach-runtime-idle"
        }
        return "coach-runtime-ready-\(appLanguage.code.rawValue)"
    }

    var body: some View {
        ZStack {
            ProcessScreenBackground()

            if session.hasCompletedOnboarding {
                if !subscriptionService.hasResolvedInitialSubscriptionStatus {
                    Color.clear
                        .task {
                            await subscriptionService.checkSubscriptionStatus()
                        }
                } else if subscriptionService.subscriptionStatus.isActive {
                    MainAppView()
                        .processAppStoreReviewPrompts()
                        .transition(.opacity)
                } else {
                    PaywallView(
                        allowsLeaveWithoutPurchase: false,
                        analyticsSource: "subscription_gate"
                    )
                    .transition(.opacity)
                }
            } else {
                SportOnboardingRootView()
                    .transition(.opacity)
                    .id("welcome-onboarding-\(session.hasCompletedOnboarding)")
            }
        }
        .environment(\.locale, appLanguage.locale)
        .animation(.easeInOut(duration: 0.28), value: session.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.28), value: subscriptionService.subscriptionStatus)
        .animation(.easeInOut(duration: 0.28), value: subscriptionService.hasResolvedInitialSubscriptionStatus)
        // Double-swipe Home après stabilisation du launch (pas au tout premier frame).
        .processPreAccessDoubleHomeSwipe(
            isActive: !session.hasCompletedOnboarding && isHomeSwipeArmed
        )
        .onChange(of: scenePhase) { _, phase in
            CoachPresentationTracker.shared.applicationIsActive = (phase == .active)
            switch phase {
            case .background:
                ProcessMarketingNotificationService.shared.handleAppLeftForeground()
                ProcessHydrationTimerMonitor.shared.handleSceneWillBackground()
            case .active:
                ProcessMarketingNotificationService.shared.handleAppBecameActive()
                ProcessAudioSession.configureForMixingWithOthersIfIdle()
                ProcessHomeScreenQuickActions.syncForCurrentUser()
                if session.hasCompletedOnboarding {
                    Task { await subscriptionService.checkSubscriptionStatus() }
                }
                CoachDailyRhythmService.cancelEveningCheckNotification()
                if let delegate = UIApplication.shared.delegate as? ProcessAppDelegate {
                    delegate.consumePendingLaunchShortcut()
                }
                Task {
                    await launchRouter.flushPendingPresentationAfterSubscriptionReady()
                }
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
        .processAppUpdatePrompt()
        .preferredColorScheme(session.appearance.preferredColorScheme)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(UnifiedProfileService.shared)
        .environmentObject(HealthManager.shared)
        .environmentObject(PermissionsManager.shared)
        .environmentObject(DailyDataManager.shared)
        .onOpenURL { url in
            ProcessAppsFlyer.shared.handleOpen(url)
            if ProcessReferralLink.parseCode(from: url) != nil {
                ProcessReferralAttribution.capture(from: url)
                NotificationCenter.default.post(name: .processReferralCodeCaptured, object: nil)
            } else if ProcessReferralLink.isAcquisitionURL(url) {
                ProcessAcquisitionAttribution.capture(from: url)
            } else {
                ProcessAcquisitionAttribution.capture(from: url)
                AppLaunchRouter.shared.handleHydrationURL(url)
            }
        }
        .task {
            ProcessHydrationTimerMonitor.shared.bootstrapAtLaunch()
            // Garantit Firebase prêt avant tout usage Auth tardif.
            FirebaseBootstrap.configure()
            if AppConfiguration.firebaseConfigured {
                _ = UserSessionCoordinator.shared
            }
            AppSession.shared.reloadForCurrentUser()
            ProcessAnalytics.configure()
            ProcessAppsFlyer.shared.configure()
            ProcessCrispSupport.configure()
            ProcessAnalytics.trackAppOpened(hasCompletedOnboarding: session.hasCompletedOnboarding)
            if let uid = AuthUser.current?.uid {
                ProcessAnalytics.identify(userId: uid)
            }
            ProcessAnalytics.syncFirstNameFromProfile()
            ProcessCrispSupport.syncUser()
            // Laisse le 1er frame se peindre avant d’armer le double-swipe Home.
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            isHomeSwipeArmed = !session.hasCompletedOnboarding
            ProcessHomeScreenQuickActions.syncForCurrentUser()
            if let delegate = UIApplication.shared.delegate as? ProcessAppDelegate {
                delegate.consumePendingLaunchShortcut()
            }
            await launchRouter.flushPendingPresentationAfterSubscriptionReady()
        }
        .onChange(of: session.hasCompletedOnboarding) { _, completed in
            if completed { isHomeSwipeArmed = false }
        }
        .onChange(of: subscriptionService.subscriptionStatus) { _, status in
            guard status.isActive else { return }
            launchRouter.clearSpinPresentation()
            launchRouter.clearLifetimeOfferPresentation()
        }
        .onChange(of: appLanguage.code) { _, _ in
            WelcomePlanStore.shared.refreshLocalizedCopy(
                profile: UnifiedProfileService.shared.currentProfile
            )
        }
        .task(id: mainAppBootstrapToken) {
            guard session.hasCompletedOnboarding,
                  subscriptionService.hasResolvedInitialSubscriptionStatus,
                  subscriptionService.subscriptionStatus.isActive else {
                didPrepareMainApp = false
                didPrepareCoachRuntime = false
                return
            }
            guard !didPrepareMainApp else { return }
            didPrepareMainApp = true
            WelcomePlanStore.shared.reloadForCurrentUser()
            ProcessCreatorModeStore.shared.syncFromCurrentProfile()
            PostOnboardingActivationService.prepareFirstAppEntry(
                profile: UnifiedProfileService.shared.currentProfile
            )
            PlanHomeTutorialStore.shared.suppressPresentationForPreview(false)
            PlanHomeTutorialStore.shared.activateImmediatelyIfNeeded()
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled,
                  session.hasCompletedOnboarding,
                  subscriptionService.subscriptionStatus.isActive else { return }
            if AppConfiguration.firebaseConfigured {
                _ = UserSessionCoordinator.shared
            }
        }
        .task(id: coachRuntimeBootstrapToken) {
            guard session.hasCompletedOnboarding,
                  subscriptionService.hasResolvedInitialSubscriptionStatus,
                  subscriptionService.subscriptionStatus.isActive,
                  session.hasCompletedWelcomePlanChat else {
                didPrepareCoachRuntime = false
                return
            }
            guard !didPrepareCoachRuntime else { return }
            didPrepareCoachRuntime = true
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled,
                  session.hasCompletedOnboarding,
                  subscriptionService.subscriptionStatus.isActive,
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
            Button(AppCopy.t("OK", en: "OK"), role: .cancel) {
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
            ZStack(alignment: .topTrailing) {
                PaywallSpinWinbackView(
                    presentation: .spinWheel,
                    analyticsSource: "marketing_notif_spin"
                ) {
                    launchRouter.clearSpinPresentation()
                    ProcessHomeScreenQuickActions.syncForCurrentUser()
                }
                .interactiveDismissDisabled()

                Button {
                    launchRouter.clearSpinPresentation()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 36, height: 36)
                }
                .processGlassIconButtonStyle()
                .padding(.top, 12)
                .padding(.trailing, 18)
                .accessibilityLabel(AppCopy.t("Fermer", en: "Close"))
            }
        }
    }
}
