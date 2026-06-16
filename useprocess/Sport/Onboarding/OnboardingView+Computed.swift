//
//  OnboardingView+Computed.swift
//  Process
//
//  Propriétés calculées (visibilité boutons, padding) extraites de OnboardingView.
//

import SwiftUI
import UIKit

extension SportOnboardingView {

// MARK: - Computed Properties

var shouldShowFirstNameVerificationLabel: Bool {
    viewModel.currentStep == OnboardingStep.firstNameInput.rawValue
        && !viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

var shouldShowContinueButton: Bool {
    if isImmersiveOnboardingStep { return false }

    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else {
        return false
    }

    return !step.usesInternalContinueAction
}

var shouldShowGlobalContinueButton: Bool {
    guard !isImmersiveOnboardingStep else { return false }
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else { return false }
    return !step.usesInternalContinueAction
}

var continueButtonOpacity: Double {
    if shouldHideButtonUntilValidated {
        return canContinue ? 1.0 : 0.0
    }
    if canContinue {
        return 1.0
    }
    return isFirstNameVerifying ? 0.45 : 0.5
}

var continueButtonHitTestingEnabled: Bool {
    if shouldHideButtonUntilValidated {
        return canContinue
    }
    return true
}

var continueButtonBottomOffset: CGFloat {
    let step = OnboardingStep(rawValue: viewModel.currentStep)

    switch step {
    case .firstNameInput:
        // Position plus haute pour la page prénom (clavier texte)
        return ScreenMetrics.height * 0.38
    case .weight, .idealWeight:
        return ScreenMetrics.height * 0.35
    default:
        // Position standard en bas (comme avant)
        return 50
    }
}

var canContinue: Bool {
    guard viewModel.isCurrentStepValidated() else { return false }

    if viewModel.currentStep == OnboardingStep.firstNameInput.rawValue {
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return isFirstNameAvailable
        }
    }

    return true
}

/// Prénom saisi mais vérification en cours (bouton non cliquable).
var isFirstNameVerifying: Bool {
    viewModel.currentStep == OnboardingStep.firstNameInput.rawValue
        && !viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isFirstNameAvailable
}

var shouldShowNoWeightGoalLink: Bool {
    viewModel.currentStep == OnboardingStep.idealWeight.rawValue
}

var shouldHideButtonUntilValidated: Bool {
    let step = OnboardingStep(rawValue: viewModel.currentStep)
    switch step {
    case .programCreation, .weightEstimation, .goalProjection:
        // Ces pages ont des animations - le bouton doit être caché jusqu'à la fin
        return true
    default:
        return false
    }
}

func skipWeightGoalFromIdealWeight() {
    HapticManager.shared.impact(.light)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

    viewModel.applyHasWeightGoal(false)
    viewModel.idealWeightValue = 0
    viewModel.isIdealWeightEntered = false
    viewModel.selectedWeightGoal = nil
    viewModel.isWeightGoalSelected = false
    viewModel.saveProgress()

    OnboardingProgressService.shared.saveLastCompletedStep(viewModel.currentStep)
    commitVisibleStepToHistory(viewModel.currentStep)
    previousStepIndex = viewModel.currentStep
    transitionDirection = .forward
    isTransitioning = true

    withAnimation(.onboardingTransition) {
        viewModel.currentStep = OnboardingStep.firstNameInput.rawValue
    }

    commitVisibleStepToHistory(OnboardingStep.firstNameInput.rawValue)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        isTransitioning = false
    }

    viewModel.saveProgress()
    refreshOnboardingFlowProgress()
}

func handleContinueButtonTap() {
    HapticManager.shared.impact(.medium)

    viewModel.commitPendingStepAnswers()

    let step = OnboardingStep(rawValue: viewModel.currentStep)

    switch step {
    case .nutritionQuality:
        nextStep()

    case .firstNameInput:
        // Fermer le clavier et sauvegarder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task.detached(priority: .background) {
            // La sauvegarde est gérée par FirstNameInputStepView
        }
        nextStep()

    case .weight, .idealWeight:
        // Fermer le clavier et sauvegarder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        // La sauvegarde est gérée par les vues via onChange
        nextStep()

    default:
        nextStep()
    }
}

var isImmersiveOnboardingStep: Bool {
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else { return false }
    return step == .videoIntroduction || step == .faceAnalysis
}

var shouldShowBackButton: Bool {
    if isSportSearchActive {
        return false
    }

    guard let currentStep = OnboardingStep(rawValue: viewModel.currentStep) else {
        return false
    }

    let blockedSteps: Set<OnboardingStep> = [
        .videoIntroduction, .payment, .processWelcome, .featuresUnlock, .complete, .faceAnalysis
    ]
    if blockedSteps.contains(currentStep) {
        return false
    }

    return viewModel.visitedSteps.count > 1
}

var shouldAddTopPadding: Bool {
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else {
        return false
    }

    // Pages avec titre en overlay : pas de padding parent (évite le double décalage).
    if step == .videoIntroduction || step == .payment || step == .processWelcome || step == .faceAnalysis
        || step == .genderSelection || step == .ageSelection || step == .height || step == .weight
        || step == .heightWeight || step == .firstNameInput
        || step == .weightEstimation || step == .goalProjection
        || step == .primaryGoal || step == .idealWeight || step == .goalPace
        || step == .hasSportActivity || step == .nutritionQuality
        || step == .weightManagementExperience || step == .weightFailureReasons
        || step == .sportSelection || step == .weightMotivation || step == .weightGoalIncompatible
        || step == .biometricAuth || step == .notificationPermission || step == .healthKitPermissions {
        return false
    }

    // Pages avec header retour + contenu scrollé sans overlay titre.
    return OnboardingHeaderLayout.showsAnyHeader(
        currentStep: viewModel.currentStep,
        shouldShowBackButton: shouldShowBackButton
    )
}

func updateContinueButtonLayout(animated: Bool) {
    let target = continueButtonBottomOffset
    if animated {
        withAnimation(.onboardingTransition) {
            animatedContinueBottomOffset = target
        }
    } else {
        animatedContinueBottomOffset = target
    }
}

}
