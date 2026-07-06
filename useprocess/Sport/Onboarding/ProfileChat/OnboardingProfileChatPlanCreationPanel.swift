//
//  OnboardingProfileChatPlanCreationPanel.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatPlanCreationPanel: View {
    let isVisible: Bool
    let isComplete: Bool

    var body: some View {
        VStack(spacing: 28) {
            statusIcon

            VStack(spacing: 10) {
                Text(isComplete ? "Expérience personnalisée" : "Personnalisation de votre expérience...")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                if isComplete {
                    Text("Tout est prêt pour toi.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(OnboardingTheme.mutedText)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    VStack(spacing: 4) {
                        Text("Cela peut prendre quelques secondes.")
                        Text("Veuillez ne pas fermer l'application.")
                    }
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(OnboardingTheme.mutedText)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: isVisible)
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: isComplete)
    }

    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(OnboardingProfileChatDepthStyle.chatAccentViolet)
                    .symbolEffect(.bounce, value: isComplete)
                    .transition(.scale.combined(with: .opacity))
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .tint(OnboardingTheme.mutedText)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 56, height: 56)
    }
}
