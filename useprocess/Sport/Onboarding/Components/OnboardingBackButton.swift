//
//  OnboardingBackButton.swift
//  Process
//
//  Bouton retour unique — même taille et style sur tout l'onboarding.
//

import SwiftUI

struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OnboardingTheme.bodyText)
                .frame(
                    width: OnboardingConstants.backButtonSize,
                    height: OnboardingConstants.backButtonSize
                )
        }
        .glassStyle()

    }
}
