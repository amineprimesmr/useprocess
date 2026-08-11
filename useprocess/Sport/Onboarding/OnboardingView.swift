//
//  OnboardingView.swift
//  Process
//
//  Version refactorée complète utilisant ViewModel et NavigationEngine
//

import SwiftUI

struct SportOnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
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

    // État pour l'authentification biométrique
    @State var biometricAuthCompleted: Bool = false

    /// Recherche sport active : masque le bouton retour
    @State var isSportSearchActive = false

    /// Progression header — fraction 0…1.
    @State var flowProgress: Double = OnboardingProgressService.shared.loadFlowProgress() ?? 0
    @State var flowTotalSteps: Int = 1
    @State var flowGlowProgressCount: Int = 1
    @State private var isOnboardingRestoreComplete = false

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
            OnboardingTheme.screenBackground
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            if isImmersiveOnboardingStep {
                Group {
                    if let step = OnboardingStep(rawValue: viewModel.currentStep) {
                        onboardingStepContent(for: step)
                    }
                }
                .id(appLanguage.code)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            } else {
            VStack(spacing: 0) {
                // Contenu principal avec transition ultra fluide
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
                .id(appLanguage.code)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, shouldAddTopPadding ? OnboardingConstants.titleTopPaddingFromScreenTop : 0)
                .ignoresSafeArea(.all)
                .regularWidthContainer(maxWidth: AdaptiveScreenLayout.onboardingChatMaxWidth)
                .ios26SafeAnimation(.onboardingTransition, value: viewModel.currentStep)
                .id("onboarding_content_\(viewModel.currentStep)") // Force le re-render pour animations fluides

            }
            }

            continueButtonOverlay
                .opacity(shouldShowGlobalContinueButton ? continueButtonOpacity : 0)
                .accessibilityHidden(!shouldShowGlobalContinueButton)
                .zIndex(shouldShowGlobalContinueButton ? 20 : -1)

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
        .overlay(alignment: .top) {
            if !isImmersiveOnboardingStep,
               isOnboardingRestoreComplete,
               !OnboardingHeaderLayout.usesDedicatedFullScreenChrome(currentStep: viewModel.currentStep),
               OnboardingHeaderLayout.showsAnyHeader(
                   currentStep: viewModel.currentStep,
                   shouldShowBackButton: shouldShowBackButton
               ) {
                OnboardingHeaderChrome(
                    viewModel: viewModel,
                    shouldShowBackButton: shouldShowBackButton,
                    flowProgress: flowProgress,
                    onPreviousStep: handleOnboardingBack
                )
                .ignoresSafeArea(edges: .top)
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            Task { @MainActor in
                if !authManager.isInOnboarding {
                    authManager.startOnboarding()
                }
                checkPermissions()

                if FirebaseBootstrap.isConfigured,
                   AuthUser.current != nil,
                   profileService.currentProfile == nil {
                    await profileService.loadProfile()
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
                await SubscriptionService.shared.checkSubscriptionStatus()
                reconcilePostPaymentStepIfNeeded()
                refreshOnboardingFlowProgress()
                updateContinueButtonLayout(animated: false)
                isOnboardingRestoreComplete = true

                ProcessReferralAttribution.captureFromClipboardIfNeeded()
                ProcessReferralAttribution.applyPendingIfNeeded(to: viewModel)

                let step = OnboardingStep(rawValue: viewModel.currentStep)
                ProcessAnalytics.trackOnboardingStarted(step: step)
                ProcessAnalytics.trackOnboardingStep(step: step)
            }
        }
        .onChange(of: profileService.currentProfile) { _, newValue in
            guard let profile = newValue else { return }
            Task { @MainActor in
                viewModel.syncWithExistingProfile(profile)
                reconcileVisitedStepsForRestore(
                    viewModel: viewModel,
                    navigationEngine: navigationEngine
                )
                refreshOnboardingFlowProgress()
            }
        }
        .onChange(of: viewModel.currentStep) { _, newStep in
            viewModel.saveProgress()
            updateContinueButtonLayout(animated: true)
            ProcessAnalytics.trackOnboardingStep(step: OnboardingStep(rawValue: newStep))

            Task { @MainActor in
                refreshOnboardingFlowProgress()
            }
        }
        .onChange(of: viewModel.visitedSteps) { _, _ in
            refreshOnboardingFlowProgress()
        }
        .onChange(of: viewModel.hasWeightGoal) { _, _ in
            viewModel.saveProgress()
            refreshOnboardingFlowProgress()
        }
        .onChange(of: viewModel.hasSportActivity) { _, _ in
            viewModel.saveProgress()
            refreshOnboardingFlowProgress()
        }
        .onChange(of: viewModel.nutritionProfile.weightManagementExperience) { _, _ in
            viewModel.saveProgress()
            refreshOnboardingFlowProgress()
        }
        .onChange(of: viewModel.makeAnswersSnapshot()) { _, _ in
            viewModel.saveProgress()
            refreshOnboardingFlowProgress()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ProcessReferralAttribution.captureFromClipboardIfNeeded()
                ProcessReferralAttribution.applyPendingIfNeeded(to: viewModel)
                reconcileVisitedStepsForRestore(
                    viewModel: viewModel,
                    navigationEngine: navigationEngine
                )
                refreshOnboardingFlowProgress()
            }
            guard phase == .inactive || phase == .background else { return }
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
        .fullScreenCover(item: $viewModel.presentedFaceScanResult) { result in
            OnboardingFaceScanSessionView(
                initialResult: result,
                onCancel: {
                    viewModel.presentedFaceScanResult = nil
                },
                onResultReady: { _ in },
                onContinueAfterResults: {
                    viewModel.presentedFaceScanResult = nil
                }
            )
            .environmentObject(profileService)
            .interactiveDismissDisabled(true)
        }
    }

    private var continueButtonOverlay: some View {
        VStack {
            Spacer()
                .allowsHitTesting(false)

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
            .padding(.horizontal, 34)
            .disabled(!canContinue)
            .allowsHitTesting(
                shouldShowGlobalContinueButton
                    && continueButtonHitTestingEnabled
                    && canContinue
            )

            if shouldShowNoWeightGoalLink {
                Button(action: skipWeightGoalFromIdealWeight) {
                    Text(OnboardingCopy.t("Passer — je me concentre sur mon visage", en: "Skip — I'm focusing on my face"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(OnboardingTheme.mutedText.opacity(0.75))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .processTappableButtonLabel(maxWidth: true)
                }
                .buttonStyle(.processPlain)
            }

            Spacer()
                .frame(height: effectiveContinueBottomOffset)
                .allowsHitTesting(false)
        }
        .id("onboarding_global_continue")
        .animation(.easeOut(duration: 0.25), value: keyboardHeight.height)
    }
}
