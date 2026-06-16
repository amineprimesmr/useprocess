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

    static let backButtonSize: CGFloat = 34
    static let headerHorizontalPadding: CGFloat = 20
    /// Espace entre la safe area et le haut du bouton retour.
    static let backButtonOffsetBelowSafeArea: CGFloat = 8
    /// Espace entre la barre header et le titre.
    static let spacingBelowHeaderBar: CGFloat = 16

    static var safeAreaTop: CGFloat {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: \.isKeyWindow) else {
            return 59
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

    /// Alias historique — aligné sur le même repère que les autres pages.
    static var titleTopPaddingAfterPrimaryGoal: CGFloat { titleTopPaddingFromScreenTop }

    /// Espace réservé en haut du contenu scrollé (pages sans overlay titre).
    static var scrollContentTopInset: CGFloat { titleTopPaddingFromScreenTop + 24 }

    /// Repère haut après la page prénom (retour seul, sans barre ni drapeau).
    static var backOnlyContentTopInset: CGFloat {
        headerBackButtonTopPadding + backButtonSize + spacingBelowHeaderBar
    }
}

// MARK: - Visibilité du header

enum OnboardingHeaderLayout {
    /// Barre de progression + sélecteur de langue (questionnaire jusqu'au prénom).
    static func showsProgressAndLanguage(currentStep: Int) -> Bool {
        showsFullHeader(currentStep: currentStep)
    }

    static func showsFullHeader(currentStep: Int) -> Bool {
        guard let step = OnboardingStep(rawValue: currentStep) else { return false }

        if step == .videoIntroduction || isAfterQuestionnairePhase(step) { return false }
        if isAfterFirstNameProgressPhase(step) { return false }

        switch step {
        case .healthKitPermissions, .programCreation, .biometricAuth, .notificationPermission,
             .payment, .processWelcome, .referralReward, .featuresUnlock, .complete,
             .caloriesGoal, .carryOverCalories, .appleSignIn, .referralCode, .appRating:
            return false
        default:
            return true
        }
    }

    /// Retour seul après la page prénom (pas de barre ni drapeau).
    static func showsBackOnly(currentStep: Int, shouldShowBackButton: Bool) -> Bool {
        guard shouldShowBackButton else { return false }
        guard let step = OnboardingStep(rawValue: currentStep) else { return false }
        if step == .videoIntroduction || isAfterQuestionnairePhase(step) { return false }
        return isAfterFirstNameProgressPhase(step)
    }

    static func showsAnyHeader(currentStep: Int, shouldShowBackButton: Bool) -> Bool {
        showsProgressAndLanguage(currentStep: currentStep)
            || showsBackOnly(currentStep: currentStep, shouldShowBackButton: shouldShowBackButton)
    }
}
