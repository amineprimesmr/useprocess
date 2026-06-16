//
//  OnboardingView.swift
//  Process
//
//  Version refactorée complète utilisant ViewModel et NavigationEngine
//

import SwiftUI

struct SportOnboardingView: View {
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
    @State var flowProgress: Double = 0
    @State var flowTotalSteps: Int = 1
    @State var flowGlowProgressCount: Int = 1

    @State var isFirstNameAvailable: Bool = false
    @State var firstNameDebounceTask: Task<Void, Never>?
    @State var animatedContinueBottomOffset: CGFloat = 50

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            } else {
            VStack(spacing: 0) {
                // Contenu principal avec transition ultra fluide
                Group {
                    if let step = OnboardingStep(rawValue: viewModel.currentStep) {
                        onboardingStepContent(for: step)
                    } else {
                        OnboardingWelcomeStepView(onComplete: nextStep)
                            .task {
                                viewModel.currentStep = OnboardingStep.videoIntroduction.rawValue
                                viewModel.visitedSteps = [OnboardingStep.videoIntroduction.rawValue]
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, shouldAddTopPadding ? OnboardingConstants.titleTopPaddingFromScreenTop : 0)
                .ignoresSafeArea(.all)
                .ios26SafeAnimation(.onboardingTransition, value: viewModel.currentStep)
                .id("onboarding_content_\(viewModel.currentStep)") // Force le re-render pour animations fluides

            }
            }

            continueButtonOverlay
                .opacity(shouldShowGlobalContinueButton ? continueButtonOpacity : 0)
                .allowsHitTesting(shouldShowGlobalContinueButton && canContinue && continueButtonHitTestingEnabled)
                .accessibilityHidden(!shouldShowGlobalContinueButton)
                .zIndex(shouldShowGlobalContinueButton ? 20 : -1)

            if !isImmersiveOnboardingStep {
            if OnboardingHeaderLayout.showsAnyHeader(
                currentStep: viewModel.currentStep,
                shouldShowBackButton: shouldShowBackButton
            ) {
                OnboardingHeaderChrome(
                    viewModel: viewModel,
                    shouldShowBackButton: shouldShowBackButton,
                    flowProgress: flowProgress,
                    onPreviousStep: previousStep
                )
            }

            if OnboardingHeaderLayout.showsProgressAndLanguage(currentStep: viewModel.currentStep) {
                AnimatedOnboardingGlow(
                    currentStep: viewModel.currentStep,
                    visitedStepsCount: flowGlowProgressCount,
                    totalStepsForFlow: flowTotalSteps
                )
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
            }
            }
            }
            .ignoresSafeArea(.all)
        .onAppear {
            Task { @MainActor in
                refreshOnboardingFlowProgress()
                if !authManager.isInOnboarding {
                    authManager.startOnboarding()
                }
                checkPermissions()

                if profileService.currentProfile == nil {
                    await profileService.loadProfile()
                }

                if let cached = OnboardingProgressService.shared.loadAnswers() {
                    viewModel.applyCachedAnswers(cached)
                }

                if let profile = profileService.currentProfile {
                    viewModel.syncWithExistingProfile(profile)
                }

                restoreOnboardingProgressFromSavedState()
                refreshOnboardingFlowProgress()
                updateContinueButtonLayout(animated: false)
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
        .onChange(of: viewModel.firstName) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                isFirstNameAvailable = false
                firstNameDebounceTask?.cancel()
                firstNameDebounceTask = nil
                return
            }

            firstNameDebounceTask?.cancel()

            isFirstNameAvailable = false

            firstNameDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde

                guard !Task.isCancelled else { return }
                guard viewModel.currentStep == OnboardingStep.firstNameInput.rawValue else { return }

                let currentTrimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !currentTrimmed.isEmpty else { return }

                withAnimation(.easeInOut(duration: 0.4)) {
                        isFirstNameAvailable = true
                }
            }
        }
        .onChange(of: viewModel.currentStep) { oldValue, newValue in
            viewModel.saveProgress()
            updateContinueButtonLayout(animated: true)

            if newValue != OnboardingStep.firstNameInput.rawValue {
                isFirstNameAvailable = false
                firstNameDebounceTask?.cancel()
                firstNameDebounceTask = nil
            }

            Task { @MainActor in
                refreshOnboardingFlowProgress()
            }

            if oldValue == OnboardingStep.firstNameInput.rawValue && newValue != OnboardingStep.firstNameInput.rawValue {
                isFirstNameAvailable = false
                firstNameDebounceTask?.cancel()
                firstNameDebounceTask = nil
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
    }

    private var continueButtonOverlay: some View {
        VStack {
            Spacer()

            Button(action: {
                handleContinueButtonTap()
            }) {
                Group {
                    if shouldShowFirstNameVerificationLabel {
                        AnimatedVerificationButtonText(isAvailable: isFirstNameAvailable)
                    } else {
                        Text("CONTINUER")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(OnboardingTheme.actionButtonText)
                    }
                }
                .id("continue_button_label_\(viewModel.currentStep)")
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .glassStyle()
            .padding(.horizontal, 40)
            .disabled(!canContinue)

            if shouldShowNoWeightGoalLink {
                Button(action: skipWeightGoalFromIdealWeight) {
                    Text("Je n'ai pas d'objectif de poids")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.bodyText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
            }

            Spacer()
                .frame(height: animatedContinueBottomOffset)
        }
        .id("onboarding_global_continue")
    }
}
