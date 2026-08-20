//
//  OnboardingView.swift
//  Process
//
//  Version refactorée complète utilisant ViewModel et NavigationEngine
//

import SwiftUI

struct SportOnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject var profileService: UnifiedProfileService
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var permissionsManager: PermissionsManager
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.scenePhase) private var scenePhase

    /// `internal` : accès depuis `OnboardingView+StepContent`, `+Computed`, `+Navigation` (autres fichiers).
    @StateObject var viewModel = OnboardingViewModel()
    @State var previousStepIndex: Int?
    @State var transitionDirection: TransitionDirection = .forward
    @State var isTransitioning: Bool = false

    /// Recherche sport active : masque le bouton retour
    @State var isSportSearchActive = false

    /// Progression header — fraction 0…1.
    @State var flowProgress: Double = OnboardingProgressService.shared.loadFlowProgress() ?? 0
    @State var flowTotalSteps: Int = 1
    @State var flowGlowProgressCount: Int = 1
    @State private var isOnboardingRestoreComplete = false
    @State var flowProgressRefreshTask: Task<Void, Never>?

    /// Padding bas animé du CTA — monte avec le clavier (taille → poids, etc.).
    @State var animatedContinueBottomOffset: CGFloat = 50

    /// Hauteur live du clavier — le CTA global ignoreSafeArea, donc SwiftUI
    /// n'évite pas le clavier tout seul (bug CONTINUER sous le pad sur certains iPhone).
    @StateObject var keyboardHeight = KeyboardHeightObserver()
    @Bindable private var appLanguage = ProcessAppLanguage.shared

    var navigationEngine: OnboardingNavigationEngine {
        OnboardingNavigationEngine(viewModel: viewModel, profileService: profileService)
    }

    let totalSteps = OnboardingStep.validSavedStepUpperBound

    var body: some View {
        ZStack {
            // Fond adaptatif clair / sombre
            onboardingScreenBackground
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            onboardingAnimatedStepLayer

            if !isImmersiveOnboardingStep,
               isOnboardingRestoreComplete,
               !OnboardingHeaderLayout.usesDedicatedFullScreenChrome(currentStep: viewModel.currentStep),
               OnboardingHeaderLayout.showsProgressAndLanguage(currentStep: viewModel.currentStep) {
                AnimatedOnboardingGlow(
                    currentStep: viewModel.currentStep,
                    visitedStepsCount: flowGlowProgressCount,
                    totalStepsForFlow: flowTotalSteps
                )
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            continueButtonOverlay
                .opacity(shouldShowGlobalContinueButton ? 1 : 0)
                .accessibilityHidden(!shouldShowGlobalContinueButton)
                .allowsHitTesting(shouldShowGlobalContinueButton)
                .zIndex(shouldShowGlobalContinueButton ? 20 : -1)
        }
        .overlay(alignment: .top) {
            if !isImmersiveOnboardingStep,
               isOnboardingRestoreComplete,
               !OnboardingHeaderLayout.usesDedicatedFullScreenChrome(currentStep: viewModel.currentStep),
               OnboardingHeaderLayout.showsAnyHeader(
                   currentStep: viewModel.currentStep,
                   shouldShowBackButton: shouldShowBackButton
               ) {
                OnboardingHeaderChrome(
                    currentStep: viewModel.currentStep,
                    shouldShowBackButton: shouldShowBackButton,
                    flowProgress: flowProgress,
                    chatSegmentedProgress: OnboardingStep(rawValue: viewModel.currentStep) == .weightMotivation
                        ? viewModel.profileChatHeaderProgress
                        : nil,
                    onPreviousStep: handleOnboardingBack
                )
                .ignoresSafeArea(edges: .top)
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            if !authManager.isInOnboarding {
                authManager.startOnboarding()
            }

            if let cached = OnboardingProgressService.shared.loadAnswers() {
                viewModel.applyCachedAnswers(cached)
            }

            if let profile = profileService.currentProfile {
                viewModel.syncWithExistingProfile(profile)
            }

            restoreOnboardingProgressFromSavedState()
            reconcileVisitedStepsForRestore(
                viewModel: viewModel,
                navigationEngine: navigationEngine
            )
            refreshOnboardingFlowProgress()
            animatedContinueBottomOffset = continueButtonBottomOffset
            isOnboardingRestoreComplete = true

            ProcessReferralAttribution.applyPendingIfNeeded(to: viewModel)

            let step = OnboardingStep(rawValue: viewModel.currentStep)
            ProcessAnalytics.trackOnboardingStarted(step: step)
            ProcessAnalytics.trackOnboardingStep(step: step)

            Task { @MainActor in
                if FirebaseBootstrap.isConfigured,
                   AuthUser.current != nil,
                   profileService.currentProfile == nil {
                    await profileService.loadProfile()
                    if let profile = profileService.currentProfile {
                        viewModel.syncWithExistingProfile(profile)
                        reconcileVisitedStepsForRestore(
                            viewModel: viewModel,
                            navigationEngine: navigationEngine
                        )
                        scheduleRefreshOnboardingFlowProgress()
                    }
                }

                await SubscriptionService.shared.checkSubscriptionStatus()
                reconcileUnpaidOnboardingResumeIfNeeded()
                reconcilePostPaymentStepIfNeeded()
                scheduleRefreshOnboardingFlowProgress()
            }
        }
        .onChange(of: profileService.currentProfile) { _, newValue in
            guard let profile = newValue else { return }
            viewModel.syncWithExistingProfile(profile)
            reconcileVisitedStepsForRestore(
                viewModel: viewModel,
                navigationEngine: navigationEngine
            )
            scheduleRefreshOnboardingFlowProgress()
        }
        .onChange(of: viewModel.currentStep) { _, newStep in
            viewModel.saveProgress()
            syncAnimatedContinueBottomOffset(stepTransition: true)
            ProcessAnalytics.trackOnboardingStep(step: OnboardingStep(rawValue: newStep))
            scheduleRefreshOnboardingFlowProgress()
        }
        .onChange(of: keyboardHeight.height) { _, _ in
            syncAnimatedContinueBottomOffset(stepTransition: false)
        }
        .onChange(of: viewModel.visitedSteps) { _, _ in
            scheduleRefreshOnboardingFlowProgress()
        }
        .onChange(of: viewModel.hasWeightGoal) { _, _ in
            viewModel.saveProgress()
            scheduleRefreshOnboardingFlowProgress()
        }
        .onChange(of: viewModel.hasSportActivity) { _, _ in
            viewModel.saveProgress()
            scheduleRefreshOnboardingFlowProgress()
        }
        .onChange(of: viewModel.nutritionProfile.weightManagementExperience) { _, _ in
            viewModel.saveProgress()
            scheduleRefreshOnboardingFlowProgress()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ProcessReferralAttribution.applyPendingIfNeeded(to: viewModel)
                reconcileVisitedStepsForRestore(
                    viewModel: viewModel,
                    navigationEngine: navigationEngine
                )
                scheduleRefreshOnboardingFlowProgress()
            }
            guard phase == .inactive || phase == .background else { return }
            cancelScheduledFlowProgressRefresh()
            viewModel.commitPendingStepAnswers()
            viewModel.saveProgress()
            OnboardingProgressService.shared.flush()
        }
        .onReceive(NotificationCenter.default.publisher(for: .processReferralCodeCaptured)) { _ in
            ProcessReferralAttribution.applyPendingIfNeeded(to: viewModel)
        }
        .alert(
            OnboardingCopy.t("Finalisation impossible", en: "Couldn't finish setup"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(AppCopy.t("OK", en: "OK"), role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(item: $viewModel.presentedOnboardingFaceScan) { presentation in
            OnboardingFaceScanSessionView(
                initialResult: presentation.initialResult,
                showsBackButton: presentation.usesChatCallbacks,
                onCancel: {
                    viewModel.dismissOnboardingFaceScan()
                    if presentation.usesChatCallbacks {
                        viewModel.onOnboardingFaceScanCancel?()
                    }
                },
                onSkip: presentation.usesChatCallbacks ? {
                    viewModel.dismissOnboardingFaceScan()
                    viewModel.onOnboardingFaceScanSkip?()
                } : nil,
                onResultReady: { result in
                    if presentation.usesChatCallbacks {
                        viewModel.onOnboardingFaceScanResult?(result)
                    } else {
                        viewModel.recordDashboardFaceScanResult(result)
                    }
                },
                onContinueAfterResults: {
                    viewModel.dismissOnboardingFaceScan()
                    if presentation.usesChatCallbacks {
                        viewModel.onOnboardingFaceScanContinue?()
                    } else {
                        viewModel.onOnboardingFaceScanContinueFromDashboard?()
                    }
                }
            )
            .environmentObject(profileService)
            .interactiveDismissDisabled(true)
            .presentationBackground(FaceScanWhoopPalette.canvas)
        }
    }

    private var continueButtonOverlay: some View {
        VStack(spacing: 0) {
            Group {
                if OnboardingStep(rawValue: viewModel.currentStep) == .weightEstimation {
                    Button(action: {
                        handleContinueButtonTap()
                    }) {
                        OnboardingContinueFillRevealLabel(
                            title: OnboardingCopy.continueCTAUpper,
                            progress: viewModel.estimationContinueUnlockProgress
                        )
                        .id("continue_button_label_\(viewModel.currentStep)")
                    }
                    .buttonStyle(
                        OnboardingContinueFillRevealButtonStyle(
                            isUnlocked: isEstimationContinueUnlocked
                        )
                    )
                } else {
                    Button(action: {
                        handleContinueButtonTap()
                    }) {
                        Text(OnboardingCopy.continueCTAUpper)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                            .id("continue_button_label_\(viewModel.currentStep)")
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                    }
                    .onboardingPrimaryActionStyle()
                }
            }
            .padding(.horizontal, 34)
            .disabled(!canContinue && OnboardingStep(rawValue: viewModel.currentStep) != .referralCode)
            .opacity(continueButtonOpacity)
            .allowsHitTesting(continueButtonHitTestingEnabled && !isTransitioning)

            if shouldShowCreatorCodeSkipLink {
                Button(action: skipCreatorCodeStep) {
                    Text(AppCopy.t("Passer", en: "Skip"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.mutedText)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .processTappableButtonLabel(maxWidth: true)
                }
                .buttonStyle(.processPlain)
                .allowsHitTesting(!isTransitioning)
            }
        }
        .padding(.bottom, animatedContinueBottomOffset)
        .id("onboarding_global_continue")
    }

    private var onboardingContentIdentity: String {
        "\(appLanguage.code)_\(viewModel.currentStep)"
    }

    @ViewBuilder
    private var onboardingAnimatedStepLayer: some View {
        Group {
            if let step = OnboardingStep(rawValue: viewModel.currentStep) {
                onboardingStepContent(for: step)
            } else {
                GenderSelectionStepView(
                    selectedGender: $viewModel.selectedGender,
                    onValidationChanged: { isValid in
                        viewModel.isGenderSelected = isValid
                    }
                )
                .task {
                    viewModel.currentStep = OnboardingStep.genderSelection.rawValue
                    viewModel.visitedSteps = [OnboardingStep.genderSelection.rawValue]
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(
            .top,
            isImmersiveOnboardingStep || !shouldAddTopPadding
                ? 0
                : OnboardingConstants.titleTopPaddingFromScreenTop
        )
        .modifier(OnboardingStepLayoutModifier(immersive: isImmersiveOnboardingStep))
        .transition(onboardingPageTransition)
        .ios26SafeAnimation(onboardingPageChangeAnimation, value: viewModel.currentStep)
        .id(onboardingContentIdentity)
    }
}
