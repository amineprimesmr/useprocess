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

var shouldShowBottomButton: Bool {
    let step = OnboardingStep(rawValue: viewModel.currentStep)
    switch step {
    case .videoIntroduction, .faceAnalysis, .sportSelection, .sleepDataRecovery,
         .payment, .appleSignIn, .notificationPermission, .healthKitPermissions, .sleepInfo,
         .processWelcome, .featuresUnlock, .referralCode, .referralReward:  // ✅ Pas de bouton en bas (elles ont leur propre bouton)
        return false
    default:
        return true
    }
}

// ✅ NOUVEAU: Bouton CONTINUER global visible sur certaines pages
var shouldShowContinueButton: Bool {
    if isImmersiveOnboardingStep { return false }

    let step = OnboardingStep(rawValue: viewModel.currentStep)
    switch step {
    case .videoIntroduction, .faceAnalysis, .sleepDataRecovery,
         .payment, .appleSignIn, .notificationPermission, .sleepInfo,
         .processWelcome, .featuresUnlock, .referralCode, .referralReward,
         .healthKitPermissions, .biometricAuth, .caloriesGoal, .carryOverCalories:
        // ✅ programCreation retiré - utilise maintenant le bouton global CONTINUER
        return false
    default:
        return true
    }
}

// ✅ Pages qui ont un bouton spécifique (pas le bouton global CONTINUER)
var shouldShowSpecificButton: Bool {
    let step = OnboardingStep(rawValue: viewModel.currentStep)
    switch step {
    case .complete, .caloriesGoal, .carryOverCalories:
        return true
    default:
        return false
    }
}

// ✅ NOUVEAU: Offset depuis le bas pour le bouton selon la page
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

// ✅ NOUVEAU: Vérifier si on peut continuer (étape validée)
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

// ✅ NOUVEAU: Pages où le bouton doit être complètement caché jusqu'à validation
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

// ✅ NOUVEAU: Gérer le tap sur le bouton global
func handleContinueButtonTap() {
    HapticManager.shared.impact(.medium)

    let step = OnboardingStep(rawValue: viewModel.currentStep)

    switch step {
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

/// Progression de la lueur — alignée sur la barre (100 % avant le scan facial).
var onboardingGlowProgressCount: Int {
    let path = buildOnboardingProgressFlowPath(viewModel: viewModel, navigationEngine: navigationEngine)
    guard !path.isEmpty else { return 1 }

    if let current = OnboardingStep(rawValue: viewModel.currentStep),
       isPostFaceScanOnboardingPhase(current) {
        return path.count
    }

    if let index = path.firstIndex(of: viewModel.currentStep) {
        return index + 1
    }

    if let furthestIndex = furthestProgressIndex(in: path, viewModel: viewModel) {
        return furthestIndex + 1
    }

    return 1
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

}
