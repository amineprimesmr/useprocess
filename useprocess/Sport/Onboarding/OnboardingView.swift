//
//  OnboardingView.swift
//  Process
//
//  Version refactorée complète utilisant ViewModel et NavigationEngine
//

import SwiftUI
import AuthenticationServices
import HealthKit
import LocalAuthentication

struct SportOnboardingView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var permissionsManager: PermissionsManager
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager

    /// `internal` : accès depuis `OnboardingView+StepContent`, `+Computed`, `+Navigation` (autres fichiers).
    @StateObject var viewModel = OnboardingViewModel()
    private var hapticManager: HapticManager { HapticManager.shared }

    // ✅ État pour les transitions fluides
    @State var previousStepIndex: Int?
    @State var transitionDirection: TransitionDirection = .forward
    @State var isTransitioning: Bool = false

    // État pour les choix Oui/Non
    @State private var caloriesGoalSelected: Bool?
    @State private var carryOverCaloriesSelected: Bool?

    // État pour l'authentification biométrique
    @State var biometricAuthCompleted: Bool = false

    /// Recherche sport active : masque le bouton retour
    @State var isSportSearchActive = false

    /// Progression header — fraction 0…1.
    @State var flowProgress: Double = 0

    // ✅ État pour gérer la transition "Vérification" → "Disponible"
    @State var isFirstNameAvailable: Bool = false
    @State private var firstNameDebounceTask: Task<Void, Never>?

    var navigationEngine: OnboardingNavigationEngine {
        OnboardingNavigationEngine(viewModel: viewModel, profileService: profileService)
    }

    let totalSteps = 70  // ✅ CORRECTION: Permettre d'aller jusqu'à complete + weight (67) + autres étapes

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
                    // ✅ CORRECTION: Gérer le cas où rawValue est invalide (EXC_BAD_ACCESS)
                    if let step = OnboardingStep(rawValue: viewModel.currentStep) {
                        onboardingStepContent(for: step)
                    } else {
                        // ✅ CORRECTION: Si rawValue est invalide, réinitialiser à l'étape de départ
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

            // ✅ Bouton CONTINUER — masqué en mode immersif (scan corporel, vidéo…)
            if !isImmersiveOnboardingStep && shouldShowContinueButton {
                VStack {
                    Spacer()

                    Button(action: {
                        handleContinueButtonTap()
                    }) {
                        // ✅ Texte du bouton avec transition fluide entre "CONTINUER", "Vérification" et "Disponible"
                        Group {
                            if viewModel.currentStep == OnboardingStep.firstNameInput.rawValue && !viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                // ✅ Afficher "Vérification" ou "Disponible" avec animation de couleur
                                AnimatedVerificationButtonText(isAvailable: isFirstNameAvailable)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            } else {
                                // ✅ Afficher "CONTINUER" normal
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

                    Spacer()
                        .frame(height: continueButtonBottomOffset)
                }
                .ios26SafeAnimation(.onboardingTransition, value: viewModel.currentStep)
                .ios26SafeAnimation(.easeInOut(duration: 0.3), value: viewModel.firstName.isEmpty)
            }

            // ✅ Boutons spécifiques
            if !isImmersiveOnboardingStep && shouldShowSpecificButton {
                VStack {
                    Spacer()
                    OnboardingSpecificBottomBar(
                        viewModel: viewModel,
                        hapticManager: hapticManager,
                        caloriesGoalSelected: $caloriesGoalSelected,
                        carryOverCaloriesSelected: $carryOverCaloriesSelected,
                        biometricAuthCompleted: $biometricAuthCompleted,
                        onNextStep: nextStep,
                        onRequestHealthKit: { await requestHealthKitAndContinue() },
                        onCompleteOnboarding: { await completeOnboarding() },
                        onBiometricContinue: { await triggerBiometricAuthAndContinue() }
                    )
                    Spacer()
                        .frame(height: 50)
                }
            }

            // ✅ Header unifié : Bouton retour | Barre de progression | Bouton langue
            if !isImmersiveOnboardingStep {
            if OnboardingHeaderLayout.showsAnyHeader(
                currentStep: viewModel.currentStep,
                shouldShowBackButton: shouldShowBackButton
            ) {
                OnboardingHeaderChrome(
                    viewModel: viewModel,
                    hapticManager: hapticManager,
                    shouldShowBackButton: shouldShowBackButton,
                    flowProgress: flowProgress,
                    onPreviousStep: previousStep
                )
            }

            if OnboardingHeaderLayout.showsFullHeader(currentStep: viewModel.currentStep) {
                AnimatedOnboardingGlow(
                    currentStep: viewModel.currentStep,
                    visitedStepsCount: onboardingGlowProgressCount,
                    totalStepsForFlow: calculateTotalOnboardingStepsForFlow(
                        viewModel: viewModel,
                        navigationEngine: navigationEngine
                    )
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
            // ✅ Détecter quand l'utilisateur arrête de taper pour afficher "Disponible"
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

            // ✅ Réinitialiser l'état "Disponible" si le champ est vide
            if trimmed.isEmpty {
                isFirstNameAvailable = false
                firstNameDebounceTask?.cancel()
                firstNameDebounceTask = nil
                return
            }

            // ✅ Annuler la tâche précédente si elle existe
            firstNameDebounceTask?.cancel()

            // ✅ Réinitialiser à "Vérification" immédiatement quand l'utilisateur tape
            isFirstNameAvailable = false

            // ✅ Créer une nouvelle tâche avec debounce de 1 seconde
            firstNameDebounceTask = Task {
                // Attendre 1 seconde
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde

                // ✅ Vérifier que la tâche n'a pas été annulée et que le prénom n'est pas vide
                guard !Task.isCancelled else { return }

                let currentTrimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !currentTrimmed.isEmpty else { return }

                // ✅ Passer à "Disponible" avec animation fluide
                withAnimation(.easeInOut(duration: 0.4)) {
                        isFirstNameAvailable = true
                }
            }
        }
        .onChange(of: viewModel.currentStep) { oldValue, newValue in
            Task { @MainActor in
                refreshOnboardingFlowProgress()
            }

            if oldValue == OnboardingStep.firstNameInput.rawValue && newValue != OnboardingStep.firstNameInput.rawValue {
                isFirstNameAvailable = false
                firstNameDebounceTask?.cancel()
                firstNameDebounceTask = nil
            }
        }
    }
}
