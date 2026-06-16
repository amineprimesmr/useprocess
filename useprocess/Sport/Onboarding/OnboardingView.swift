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
    @State private var firstNameDebounceTask: Task<Void, Never>?

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

            if !isImmersiveOnboardingStep && shouldShowContinueButton {
                VStack {
                    Spacer()

                    Button(action: {
                        handleContinueButtonTap()
                    }) {
                        Group {
                            if viewModel.currentStep == OnboardingStep.firstNameInput.rawValue && !viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                AnimatedVerificationButtonText(isAvailable: isFirstNameAvailable)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            } else {
                                Text("CONTINUER")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(OnboardingTheme.actionButtonText)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .glassStyle()

                    .padding(.horizontal, 40)
                    .disabled(!canContinue)
                    .allowsHitTesting(canContinue)
                    .opacity(shouldHideButtonUntilValidated ? (canContinue ? 1.0 : 0.0) : (canContinue ? 1.0 : (isFirstNameVerifying ? 0.45 : 0.5)))

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
                        .frame(height: continueButtonBottomOffset)
                }
                .ios26SafeAnimation(.onboardingTransition, value: viewModel.currentStep)
                .ios26SafeAnimation(.easeInOut(duration: 0.3), value: viewModel.firstName.isEmpty)
                .zIndex(20)
            }

            if !isImmersiveOnboardingStep {
            if OnboardingHeaderLayout.showsAnyHeader(
                currentStep: viewModel.currentStep,
                shouldShowBackButton: shouldShowBackButton
            ) {
                OnboardingHeaderChrome(
                    viewModel: viewModel,
                    shouldShowBackButton: shouldShowBackButton,
                    flowProgress: onboardingFlowMetrics(viewModel: viewModel).progress,
                    onPreviousStep: previousStep
                )
            }

            if OnboardingHeaderLayout.showsFullHeader(currentStep: viewModel.currentStep) {
                AnimatedOnboardingGlow(
                    currentStep: viewModel.currentStep,
                    visitedStepsCount: onboardingFlowMetrics(viewModel: viewModel).glowProgressCount,
                    totalStepsForFlow: onboardingFlowMetrics(viewModel: viewModel).totalSteps
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

                if let profile = profileService.currentProfile {
                    if let cached = OnboardingProgressService.shared.loadAnswers() {
                        viewModel.applyCachedAnswers(cached)
                    }
                    viewModel.syncWithExistingProfile(profile)

                    let savedStep = OnboardingProgressService.shared.loadCurrentStep()

                    guard let step = OnboardingStep(rawValue: savedStep), savedStep >= 0, savedStep < totalSteps else {
                        viewModel.currentStep = OnboardingStep.videoIntroduction.rawValue
                        viewModel.visitedSteps = [OnboardingStep.videoIntroduction.rawValue]
                        viewModel.saveProgress()
                        refreshOnboardingFlowProgress()
                        return
                    }

                    let canDisplayStep = validateOnboardingStepAvailability(step: step, viewModel: viewModel)

                    if canDisplayStep && savedStep > 0 {
                        if let stepEnum = OnboardingStep(rawValue: savedStep), stepEnum.isTransientSkippedStep,
                           let visibleStep = navigationEngine.resolveNextVisibleStep(from: savedStep) {
                            viewModel.currentStep = visibleStep
                        } else {
                            viewModel.currentStep = savedStep
                        }

                        if OnboardingProgressService.shared.loadVisitedSteps().isEmpty {
                            viewModel.visitedSteps = rebuildVisitedStepsPrefix(
                                to: viewModel.currentStep,
                                viewModel: viewModel,
                                navigationEngine: navigationEngine
                            )
                        }

                        viewModel.visitedSteps = normalizeOnboardingVisitedStack(
                            visitedSteps: viewModel.visitedSteps,
                            currentStep: viewModel.currentStep
                        )
                    } else if !canDisplayStep && savedStep > 0 {
                        let lastValidStep = findLastValidOnboardingStepIndex(visitedSteps: viewModel.visitedSteps, viewModel: viewModel)
                        viewModel.currentStep = lastValidStep
                        viewModel.visitedSteps = normalizeOnboardingVisitedStack(
                            visitedSteps: viewModel.visitedSteps,
                            currentStep: lastValidStep
                        )
                        viewModel.saveProgress()
                    } else {
                        if viewModel.visitedSteps.isEmpty {
                            viewModel.visitedSteps = [OnboardingStep.videoIntroduction.rawValue]
                        }
                        if viewModel.currentStep == 0 {
                            viewModel.currentStep = OnboardingStep.videoIntroduction.rawValue
                        }
                    }
                }

                refreshOnboardingFlowProgress()
            }
        }
        .onChange(of: profileService.currentProfile) { _, newValue in
            guard let profile = newValue else { return }
            Task { @MainActor in
                viewModel.syncWithExistingProfile(profile)
                refreshOnboardingFlowProgress()
            }

            // L'onboarding ne doit être complété QUE quand toutes les étapes sont terminées
            // (appel explicite de completeOnboarding() dans FeaturesUnlockView)
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

                let currentTrimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !currentTrimmed.isEmpty else { return }

                withAnimation(.easeInOut(duration: 0.4)) {
                        isFirstNameAvailable = true
                }
            }
        }
        .onChange(of: viewModel.currentStep) { oldValue, newValue in
            viewModel.saveProgress()

            Task { @MainActor in
                refreshOnboardingFlowProgress()
            }

            if oldValue == OnboardingStep.firstNameInput.rawValue && newValue != OnboardingStep.firstNameInput.rawValue {
                isFirstNameAvailable = false
                firstNameDebounceTask?.cancel()
                firstNameDebounceTask = nil
            }
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
            guard phase == .inactive || phase == .background else { return }
            viewModel.commitPendingStepAnswers()
            viewModel.saveProgress()
            OnboardingProgressService.shared.flush()
        }
    }
}
