//
//  OnboardingView+Navigation.swift
//  Process
//
//  Navigation, HealthKit, finalisation onboarding et actions bouton Continuer.
//

import SwiftUI
import LocalAuthentication

extension SportOnboardingView {

// MARK: - Navigation

/// Avance automatiquement à travers une étape transitoire (sans validation).
func skipTransientStep() {
    guard let nextStepIndex = navigationEngine.resolveNextVisibleStep(from: viewModel.currentStep),
          nextStepIndex < totalSteps else {
        return
    }

    commitVisibleStepToHistory(viewModel.currentStep)

    previousStepIndex = viewModel.currentStep
    transitionDirection = .forward
    isTransitioning = true

    withAnimation(.onboardingTransition) {
        viewModel.currentStep = nextStepIndex
    }

    commitVisibleStepToHistory(nextStepIndex)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        isTransitioning = false
    }

    OnboardingProgressService.shared.saveCurrentStep(nextStepIndex)
    viewModel.saveProgress()
    refreshOnboardingFlowProgress()
}

func nextStep() {
    guard viewModel.isCurrentStepValidated() else {
        return
    }

    let warnings = viewModel.validateCrossStepConsistency()
    if !warnings.isEmpty {
    }

    guard let nextStepIndex = navigationEngine.resolveNextVisibleStep(from: viewModel.currentStep),
          nextStepIndex < totalSteps else {
        return
    }

    HapticManager.shared.impact(.medium)

    OnboardingProgressService.shared.saveLastCompletedStep(viewModel.currentStep)

    commitVisibleStepToHistory(viewModel.currentStep)

    previousStepIndex = viewModel.currentStep
    transitionDirection = .forward
    isTransitioning = true

    withAnimation(.onboardingTransition) {
        viewModel.currentStep = nextStepIndex
    }

    commitVisibleStepToHistory(nextStepIndex)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        isTransitioning = false
    }

    OnboardingProgressService.shared.saveCurrentStep(nextStepIndex)
    viewModel.saveProgress()
    refreshOnboardingFlowProgress()
}

// MARK: - Biometric Auth

func triggerBiometricAuthAndContinue() async {
    HapticManager.shared.impact(.medium)

    let context = LAContext()
    var error: NSError?

    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        nextStep()
        return
    }

    let biometricType = context.biometryType
    let reason: String

    switch biometricType {
    case .faceID:
        reason = "Utilise Face ID pour confirmer ton engagement"
    case .touchID:
        reason = "Restez appuyé avec votre doigt pour confirmer votre engagement"
    default:
        reason = "Authentifie-toi pour confirmer ton engagement"
    }

    do {
        let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        if success {
            HapticManager.shared.notification(.success)
            try? await Task.sleep(nanoseconds: 500_000_000)
            nextStep()
        }
    } catch {
        nextStep()
    }
}

func previousStep() {
    HapticManager.shared.impact(.light)

    viewModel.visitedSteps = normalizeOnboardingVisitedStack(
        visitedSteps: viewModel.visitedSteps,
        currentStep: viewModel.currentStep
    )

    guard viewModel.visitedSteps.count > 1 else {
        return
    }

    if viewModel.visitedSteps.last == viewModel.currentStep {
        viewModel.visitedSteps.removeLast()
    } else if let index = viewModel.visitedSteps.lastIndex(of: viewModel.currentStep) {
        viewModel.visitedSteps = Array(viewModel.visitedSteps.prefix(index))
    } else {
        return
    }

    guard let stepToGoBackTo = viewModel.visitedSteps.last else {
        return
    }

    previousStepIndex = viewModel.currentStep
    transitionDirection = .backward
    isTransitioning = true

    withAnimation(.onboardingTransition) {
        viewModel.currentStep = stepToGoBackTo
    }

    OnboardingProgressService.shared.saveCurrentStep(stepToGoBackTo)
    viewModel.saveProgress()
    refreshOnboardingFlowProgress()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        isTransitioning = false
    }
}

/// Ajoute une étape visible à la pile (tronque une éventuelle branche future).
private func commitVisibleStepToHistory(_ step: Int) {
    guard let onboardingStep = OnboardingStep(rawValue: step),
          !onboardingStep.isTransientSkippedStep else {
        return
    }

    if let existingIndex = viewModel.visitedSteps.lastIndex(of: step) {
        viewModel.visitedSteps = Array(viewModel.visitedSteps.prefix(existingIndex + 1))
        return
    }

    if viewModel.visitedSteps.last != step {
        viewModel.visitedSteps.append(step)
    }
}

// MARK: - Progression header (hors body)

func refreshOnboardingFlowProgress() {
    flowProgress = onboardingFlowProgress(
        viewModel: viewModel,
        navigationEngine: navigationEngine
    )
}

func buildPendingStepsQueue() {
    viewModel.pendingSpecificSteps = [.hasSportActivity]
}

// MARK: - HealthKit

func requestHealthKitAndContinue() async {
    HapticManager.shared.impact(.heavy)
    viewModel.isRequestingHealthKit = true

    await healthManager.requestAuthorizationAsync()

    viewModel.healthKitGranted = healthManager.isAuthorized
    viewModel.isRequestingHealthKit = false

    nextStep()
}

func checkPermissions() {
    viewModel.healthKitGranted = healthManager.isAuthorized
}

// MARK: - Completion

    func completeOnboarding() async {
        guard !viewModel.isCompleting else { return }

        HapticManager.shared.impact(.heavy)
        viewModel.isCompleting = true

        do {
            await OnboardingProgressService.shared.savePendingDataIfNeeded(to: profileService)
            let coordinator = OnboardingCoordinator(viewModel: viewModel, profileService: profileService)
            try await coordinator.saveAllOnboardingData()
            try await OnboardingService.shared.completeOnboarding()
            AppSession.shared.completeOnboarding()
            HapticManager.shared.notification(.success)

            if ClaudeConfiguration.isConfigured,
               let summary = await CoachEngine.generateProgramSummary(profile: profileService.currentProfile) {
                let msg = CoachMessage(
                    role: .assistant,
                    text: "## Bienvenue dans useprocess\n\n\(summary)\n\nOuvre l'onglet **Coach** pour continuer la conversation.",
                    modelUsed: ClaudeModel.preferred(for: .programSummary).rawValue
                )
                CoachConversationStore.appendMessage(msg)
            }
        } catch {
            HapticManager.shared.notification(.error)
            viewModel.errorMessage = "Erreur lors de la finalisation. Veuillez réessayer."
            // Même en cas d'erreur Firestore, débloquer l'accès à l'app.
            AppSession.shared.completeOnboarding()
        }

        viewModel.isCompleting = false
    }

// MARK: - Helpers

func savePlanDataProgressively() async {
    await OnboardingProgressService.shared.savePlanData(
        mainGoal: nil,
        experienceLevel: viewModel.selectedExperienceLevel,
        yearsOfExperience: viewModel.selectedYearsOfExperience,
        sessionsPerWeek: viewModel.selectedSessionsPerWeek,
        sessionDuration: viewModel.selectedSessionDuration,
        trainingLocation: viewModel.selectedTrainingLocation,
        equipment: viewModel.selectedEquipment,
        weightGoal: viewModel.selectedWeightGoal,
        to: profileService
    )
}
}
