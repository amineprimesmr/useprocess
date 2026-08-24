//
//  OnboardingConstants.swift
//  Process
//
//  Constantes pour l'espacement uniforme dans l'onboarding
//

import SwiftUI
import UIKit

struct OnboardingConstants {
    // MARK: - Header (retour, progression, langue)

    static let backButtonSize: CGFloat = 30
    static let headerHorizontalPadding: CGFloat = 24
    /// Espace entre la safe area et le haut du bouton retour.
    static let backButtonOffsetBelowSafeArea: CGFloat = 6
    /// Espace entre la barre header et le titre.
    static let spacingBelowHeaderBar: CGFloat = 18

    static var safeAreaTop: CGFloat {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: \.isKeyWindow) else {
            return LayoutConstants.isIPad ? 24 : 59
        }
        return window.safeAreaInsets.top
    }

    /// Padding `.top` du bouton retour dans le header (depuis le haut de l'écran).
    static var headerBackButtonTopPadding: CGFloat {
        safeAreaTop + backButtonOffsetBelowSafeArea
    }

    /// Position du titre (overlay) depuis le haut de l'écran — juste sous le header.
    static var titleTopPaddingFromScreenTop: CGFloat {
        headerBackButtonTopPadding + backButtonSize + spacingBelowHeaderBar
    }

    // MARK: - Contenu

    static let titleToContentSpacing: CGFloat = 60
    static let titleAreaHeight: CGFloat = 150

    /// Alias historique — même valeur que `titleTopPaddingFromScreenTop`.
    static var titleTopPadding: CGFloat { titleTopPaddingFromScreenTop }

    /// Repère haut après la page prénom (retour seul, sans barre ni drapeau).
    static var backOnlyContentTopInset: CGFloat {
        headerBackButtonTopPadding + backButtonSize + spacingBelowHeaderBar
    }

    /// Repère haut du fil Moss — retour + barre segmentée, puis marge avant la 1ʳᵉ bulle.
    static let mossChatSpacingBelowHeaderBar: CGFloat = 40

    static var mossChatContentTopInset: CGFloat {
        headerBackButtonTopPadding + backButtonSize + mossChatSpacingBelowHeaderBar
    }

    /// Marge basse standard du CTA onboarding (prénom, poids, etc.).
    static let standardContinueBottomOffset: CGFloat = 50

    /// Étape code créateur / parrainage juste avant le paywall.
    static let showsReferralCodeStepInOnboarding = true
}

// MARK: - Visibilité du header

enum OnboardingHeaderLayout {
    /// Barre de progression + sélecteur de langue (questionnaire jusqu'au prénom).
    static func showsProgressAndLanguage(currentStep: Int) -> Bool {
        showsFullHeader(currentStep: currentStep)
    }

    static func showsFullHeader(currentStep: Int) -> Bool {
        let step = OnboardingStep.resolved(from: currentStep)
        if isAfterQuestionnairePhase(step) { return false }
        return !isAfterFirstNameProgressPhase(step)
    }

    /// Retour seul après la page prénom (pas de barre ni drapeau).
    static func showsBackOnly(currentStep: Int, shouldShowBackButton: Bool) -> Bool {
        guard shouldShowBackButton else { return false }
        let step = OnboardingStep.resolved(from: currentStep)
        if showsBackOnlyOnboardingHeader(step) { return true }
        if isAfterQuestionnairePhase(step) { return false }
        return isAfterFirstNameProgressPhase(step)
    }

    static func showsAnyHeader(currentStep: Int, shouldShowBackButton: Bool) -> Bool {
        showsProgressAndLanguage(currentStep: currentStep)
            || showsBackOnly(currentStep: currentStep, shouldShowBackButton: shouldShowBackButton)
    }

    /// Étapes sans chrome global (pas de barre, drapeau ni retour overlay).
    static func usesDedicatedFullScreenChrome(currentStep: Int) -> Bool {
        switch OnboardingStep.resolved(from: currentStep) {
        case .payment, .appleSignIn, .complete, .dashboardPreview, .dreamFaceCommit:
            return true
        default:
            return false
        }
    }
}
