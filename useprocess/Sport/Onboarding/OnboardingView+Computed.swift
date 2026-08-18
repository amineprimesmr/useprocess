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
    return canContinue ? 1.0 : 0.5
}

var continueButtonHitTestingEnabled: Bool {
    if shouldHideButtonUntilValidated {
        return canContinue
    }
    return true
}

/// Marge au-dessus du haut du clavier (EN QuickType / pad US inclus).
var continueButtonKeyboardGap: CGFloat { 16 }

/// Steps où le clavier est ouvert par défaut — le CTA doit suivre la hauteur réelle.
var isKeyboardAnchoredContinueStep: Bool {
    switch OnboardingStep(rawValue: viewModel.currentStep) {
    case .firstNameInput, .weight, .idealWeight:
        return true
    default:
        return false
    }
}

/// Offset bas du bouton CONTINUER (espace sous le bouton jusqu'au bord écran).
/// Avant : `height * 0.35` — OK sur grand iPhone, sous le decimal pad sur d'autres
/// (SE / mini / hauteurs clavier variables) → bouton visible mais non cliquable.
var continueButtonBottomOffset: CGFloat {
    if isKeyboardAnchoredContinueStep {
        // Sans clavier : bas d'écran standard. Avec clavier : ancrage exact.
        if keyboardHeight.height > 0 {
            return keyboardHeight.height + continueButtonKeyboardGap
        }
        return 50
    }
    return 50
}

/// Offset effectif rendu — une seule source (clavier live ou marge basse).
var effectiveContinueBottomOffset: CGFloat {
    continueButtonBottomOffset
}

var canContinue: Bool {
    viewModel.isCurrentStepValidated()
}

var shouldShowNoWeightGoalLink: Bool {
    false
}

var shouldHideButtonUntilValidated: Bool {
    false
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

    commitAnimatedStepChange(to: OnboardingStep.firstNameInput.rawValue)

    commitVisibleStepToHistory(OnboardingStep.firstNameInput.rawValue)

    DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingTransitionTiming.navigationUnlockDelay) {
        isTransitioning = false
    }

    viewModel.saveProgress()
    scheduleRefreshOnboardingFlowProgress()
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

/// À partir du chat / scan : même slide que capture → analyse → résultats.
var shouldUseScanPagePush: Bool {
    let from = OnboardingStep(rawValue: previousStepIndex ?? viewModel.currentStep)
    let to = OnboardingStep(rawValue: viewModel.currentStep)
    if from == .dashboardPreview || to == .dashboardPreview {
        return true
    }
    return Self.usesScanStylePagePush(
        from: previousStepIndex ?? viewModel.currentStep,
        to: viewModel.currentStep
    )
}

var onboardingPageChangeAnimation: Animation {
    shouldUseScanPagePush ? .onboardingScanPagePush : .onboardingTransition
}

var onboardingPageTransition: AnyTransition {
    if shouldUseScanPagePush {
        return .onboardingScanPagePush(direction: transitionDirection)
    }
    return .onboardingQuestionnaireSlide(direction: transitionDirection)
}

static func usesScanStylePagePush(from: Int, to: Int) -> Bool {
    let threshold = OnboardingStep.weightMotivation.semanticOrderIndex
    let fromIndex = OnboardingStep(rawValue: from)?.semanticOrderIndex ?? 0
    let toIndex = OnboardingStep(rawValue: to)?.semanticOrderIndex ?? 0
    return fromIndex >= threshold || toIndex >= threshold
}

func commitAnimatedStepChange(to newStep: Int) {
    let animation: Animation = Self.usesScanStylePagePush(from: viewModel.currentStep, to: newStep)
        ? .onboardingScanPagePush
        : .onboardingTransition
    withAnimation(animation) {
        viewModel.currentStep = newStep
    }
}

var isImmersiveOnboardingStep: Bool {
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else { return false }
    // Paywall en immersif : évite le remount `.id(onboarding_content_…)` qui cassait
    // le double-swipe Home (« Attends ! ») juste après la fin de l’onboarding.
    return step == .videoIntroduction || step == .faceAnalysis || step == .dashboardPreview || step == .dreamFaceCommit || step == .payment || step == .appleSignIn
}

var shouldShowBackButton: Bool {
    if isSportSearchActive {
        return false
    }

    guard let currentStep = OnboardingStep(rawValue: viewModel.currentStep) else {
        return false
    }

    let blockedSteps: Set<OnboardingStep> = [
        .videoIntroduction, .payment, .appleSignIn, .processWelcome, .featuresUnlock, .complete, .faceAnalysis,
        .dashboardPreview, .dreamFaceCommit
    ]
    if blockedSteps.contains(currentStep) {
        return false
    }

    return viewModel.visitedSteps.count > 1
}

var onboardingScreenBackground: Color {
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else {
        return OnboardingTheme.screenBackground
    }
    if step == .faceLeverageIntro {
        return OnboardingTheme.faceLeverageIntroBackground
    }
    return OnboardingTheme.screenBackground
}

var shouldAddTopPadding: Bool {
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else {
        return false
    }

    // Pages avec titre en overlay : pas de padding parent (évite le double décalage).
    if step == .videoIntroduction || step == .payment || step == .appleSignIn || step == .processWelcome || step == .faceAnalysis
        || step == .genderSelection || step == .ageSelection || step == .height || step == .weight
        || step == .heightWeight || step == .firstNameInput || step == .faceLeverageIntro
        || step == .weightEstimation || step == .goalProjection
        || step == .primaryGoal || step == .idealWeight || step == .goalPace
        || step == .hasSportActivity || step == .nutritionQuality
        || step == .weightManagementExperience || step == .weightFailureReasons
        || step == .sportSelection || step == .weightMotivation || step == .weightGoalIncompatible
        || step == .programCreation
        || step == .biometricAuth || step == .notificationPermission || step == .transformationPreview
        || step == .dashboardPreview || step == .dreamFaceCommit
        || step == .healthKitPermissions {
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
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            animatedContinueBottomOffset = target
        }
    } else {
        animatedContinueBottomOffset = target
    }
}

}
