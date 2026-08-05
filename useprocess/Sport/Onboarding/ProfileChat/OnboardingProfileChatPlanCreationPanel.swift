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
                Text(
                    isComplete
                        ? OnboardingCopy.t("Expérience personnalisée", en: "Personalized experience")
                        : OnboardingCopy.t(
                            "Personnalisation de votre expérience...",
                            en: "Personalizing your experience..."
                        )
                )
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                if isComplete {
                    Text(OnboardingCopy.t("Tout est prêt pour toi.", en: "Everything is ready for you."))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(OnboardingTheme.mutedText)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    VStack(spacing: 4) {
                        Text(OnboardingCopy.t(
                            "Cela peut prendre quelques secondes.",
                            en: "This may take a few seconds."
                        ))
                        Text(OnboardingCopy.t(
                            "Veuillez ne pas fermer l'application.",
                            en: "Please don’t close the app."
                        ))
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
