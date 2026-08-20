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

var shouldShowGlobalContinueButton: Bool {
    guard !isImmersiveOnboardingStep else { return false }
    guard let step = OnboardingStep(rawValue: viewModel.currentStep) else { return false }
    return !step.usesInternalContinueAction
}

var continueButtonTitle: String {
    if OnboardingStep(rawValue: viewModel.currentStep) == .referralCode {
        return AppCopy.tSync("PASSER", en: "SKIP")
    }
    return OnboardingCopy.continueCTAUpper
}

var continueButtonOpacity: Double {
    if OnboardingStep(rawValue: viewModel.currentStep) == .referralCode {
        return 1.0
    }
    if OnboardingStep(rawValue: viewModel.currentStep) == .weightEstimation {
        return 1.0
    }
    return canContinue ? 1.0 : 0.5
}

var continueButtonHitTestingEnabled: Bool {
    if OnboardingStep(rawValue: viewModel.currentStep) == .referralCode {
        return true
    }
    if OnboardingStep(rawValue: viewModel.currentStep) == .weightEstimation {
        return viewModel.estimationContinueUnlockProgress >= 0.999 || canContinue
    }
    return true
}

var isEstimationContinueUnlocked: Bool {
    viewModel.estimationContinueUnlockProgress >= 0.999 || canContinue
}

/// Résultat scan à réafficher sur le 1er dashboard (reprise après kill).
var pendingDashboardScanResultForRestore: FaceScanResult? {
    guard viewModel.dashboardPreviewPresentation == .firstScanPending else { return nil }
    guard viewModel.isFaceAnalysisCompleted, !viewModel.hasCompletedFirstDashboardPreview else { return nil }
    guard viewModel.dashboardScanPersistedState == nil else { return nil }
    return viewModel.restoredFaceScanResultForNavigation()
}

/// Marge au-dessus du haut du clavier (EN QuickType / pad US inclus).
var continueButtonKeyboardGap: CGFloat { 16 }

/// Steps où le clavier est ouvert par défaut — le CTA doit suivre la hauteur réelle.
var isKeyboardAnchoredContinueStep: Bool {
    switch OnboardingStep(rawValue: viewModel.currentStep) {
    case .firstNameInput, .weight, .idealWeight, .referralCode:
        return true
    default:
        return false
    }
}

/// Marge basse standard (sans clavier).
var standardContinueBottomOffset: CGFloat { OnboardingConstants.standardContinueBottomOffset }

private static let estimatedDecimalPadOverlap: CGFloat = 308

private static let estimatedASCIIKeyboardOverlap: CGFloat = 336

/// Projection clavier pendant le slide taille → poids (avant willShow).
var shouldProjectKeyboardOverlapForCurrentStep: Bool {
    guard isKeyboardAnchoredContinueStep, keyboardHeight.height == 0 else { return false }
    guard let previous = previousStepIndex,
          let previousStep = OnboardingStep(rawValue: previous) else { return false }
    switch OnboardingStep(rawValue: viewModel.currentStep) {
    case .weight:
        return previousStep == .height || previousStep == .heightWeight
    case .referralCode:
        return previousStep == .transformationPreview
    default:
        return false
    }
}

/// Offset bas du bouton CONTINUER (espace sous le bouton jusqu'au bord écran).
var continueButtonBottomOffset: CGFloat {
    if isKeyboardAnchoredContinueStep {
        let overlap: CGFloat = {
            if keyboardHeight.height > 0 { return keyboardHeight.height }
            if keyboardHeight.lastKnownOverlap > 0 { return keyboardHeight.lastKnownOverlap }
            if shouldProjectKeyboardOverlapForCurrentStep {
                if OnboardingStep(rawValue: viewModel.currentStep) == .referralCode {
                    return Self.estimatedASCIIKeyboardOverlap
                }
                return Self.estimatedDecimalPadOverlap
            }
            return 0
        }()
        if overlap > 0 {
            return overlap + continueButtonKeyboardGap
        }
        return standardContinueBottomOffset
    }
    return standardContinueBottomOffset
}

/// Animation du CTA global — explicite (ios26SafeAnimation désactive `.animation` sur iOS 26).
func syncAnimatedContinueBottomOffset(stepTransition: Bool) {
    let target = continueButtonBottomOffset
    guard animatedContinueBottomOffset != target else { return }

    if reduceMotion {
        animatedContinueBottomOffset = target
        return
    }

    let animation: Animation = {
        if stepTransition {
            return onboardingPageChangeAnimation
        }
        if keyboardHeight.height > 0 || keyboardHeight.lastKnownOverlap > 0 {
            return .smooth(duration: keyboardHeight.transitionDuration, extraBounce: 0)
        }
        return .onboardingPage
    }()

    withAnimation(animation) {
        animatedContinueBottomOffset = target
    }
}

var canContinue: Bool {
    viewModel.isCurrentStepValidated()
}

func handleContinueButtonTap() {
    HapticManager.shared.impact(.medium)

    viewModel.commitPendingStepAnswers()

    let step = OnboardingStep(rawValue: viewModel.currentStep)

    switch step {
    case .firstNameInput, .weight, .idealWeight:
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        nextStep()

    case .referralCode:
        skipCreatorCodeStep()

    default:
        nextStep()
    }
}

/// À partir du chat / scan : même slide que capture → analyse → résultats.
var shouldUseScanPagePush: Bool {
    if shouldUseDashboardRevealTransition { return false }
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

/// Chat Moss ou témoignages → dashboard : fondu croisé au lieu du push scan.
var shouldUseDashboardRevealTransition: Bool {
    Self.usesDashboardRevealTransition(
        from: previousStepIndex ?? viewModel.currentStep,
        to: viewModel.currentStep
    )
}

/// Genre → prénom : transitions spring + slide directionnel (comme avant).
var shouldUseEarlyOnboardingTransition: Bool {
    Self.usesEarlyOnboardingTransition(
        from: previousStepIndex ?? viewModel.currentStep,
        to: viewModel.currentStep
    )
}

static func usesEarlyOnboardingTransition(from: Int, to: Int) -> Bool {
    let cap = OnboardingStep.firstNameInput.semanticOrderIndex
    let fromIndex = OnboardingStep(rawValue: from)?.semanticOrderIndex ?? 0
    let toIndex = OnboardingStep(rawValue: to)?.semanticOrderIndex ?? 0
    return fromIndex <= cap && toIndex <= cap
}

var activeNavigationUnlockDelay: TimeInterval {
    OnboardingTransitionTiming.navigationUnlockDelay(
        early: shouldUseEarlyOnboardingTransition,
        dashboardReveal: shouldUseDashboardRevealTransition
    )
}

var onboardingPageChangeAnimation: Animation {
    if shouldUseDashboardRevealTransition { return .onboardingDashboardReveal }
    if shouldUseScanPagePush { return .onboardingScanPagePush }
    if shouldUseEarlyOnboardingTransition { return .onboardingTransition }
    return .onboardingPage
}

var onboardingPageTransition: AnyTransition {
    if shouldUseDashboardRevealTransition {
        return .onboardingDashboardReveal(direction: transitionDirection)
    }
    if shouldUseScanPagePush {
        return .onboardingScanPagePush(direction: transitionDirection)
    }
    if shouldUseEarlyOnboardingTransition {
        return .onboardingQuestionnaireSlide(direction: transitionDirection)
    }
    return .onboardingPageSlide(direction: transitionDirection)
}

static func usesScanStylePagePush(from: Int, to: Int) -> Bool {
    let threshold = OnboardingStep.weightMotivation.semanticOrderIndex
    let fromIndex = OnboardingStep(rawValue: from)?.semanticOrderIndex ?? 0
    let toIndex = OnboardingStep(rawValue: to)?.semanticOrderIndex ?? 0
    return fromIndex >= threshold || toIndex >= threshold
}

static func usesDashboardRevealTransition(from: Int, to: Int) -> Bool {
    guard let fromStep = OnboardingStep(rawValue: from),
          let toStep = OnboardingStep(rawValue: to) else { return false }
    if toStep == .dashboardPreview, fromStep == .weightMotivation { return true }
    if fromStep == .dashboardPreview, toStep == .weightMotivation { return true }
    return false
}

func commitAnimatedStepChange(to newStep: Int) {
    let animation: Animation
    if Self.usesDashboardRevealTransition(from: viewModel.currentStep, to: newStep) {
        animation = .onboardingDashboardReveal
    } else if Self.usesScanStylePagePush(from: viewModel.currentStep, to: newStep) {
        animation = .onboardingScanPagePush
    } else if Self.usesEarlyOnboardingTransition(from: viewModel.currentStep, to: newStep) {
        animation = .onboardingTransition
    } else {
        animation = .onboardingPage
    }
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

    // Création du programme et toutes les étapes suivantes : pas de retour.
    if currentStep.semanticOrderIndex >= OnboardingStep.programCreation.semanticOrderIndex {
        return false
    }

    return viewModel.visitedSteps.count > 1
}

var onboardingScreenBackground: Color {
    OnboardingTheme.screenBackground
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
        || step == .referralCode
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

}
