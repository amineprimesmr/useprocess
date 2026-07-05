//
//  OnboardingProfileChatPlanCreationPanel.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatPlanCreationPanel: View {
    let isVisible: Bool

    var body: some View {
        VStack(spacing: 28) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.large)
                .tint(OnboardingTheme.mutedText)

            VStack(spacing: 10) {
                Text("Personnalisation de votre expérience...")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(.center)

                VStack(spacing: 4) {
                    Text("Cela peut prendre quelques secondes.")
                    Text("Veuillez ne pas fermer l'application.")
                }
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingTheme.mutedText)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: isVisible)
    }
}
