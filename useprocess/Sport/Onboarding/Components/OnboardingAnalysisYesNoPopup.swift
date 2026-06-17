//
//  OnboardingAnalysisYesNoPopup.swift
//  Process
//
//  Popup Oui / Non partagée (chat analyse + création programme).
//

import SwiftUI

struct OnboardingAnalysisYesNoPopup: View {
    let question: String
    let subtitle: String
    let affirmativeTitle: String
    let negativeTitle: String
    let popupOffset: CGFloat
    let onAnswer: (Bool) -> Void

    init(
        question: String,
        subtitle: String = "Pour pouvoir continuer, précise",
        affirmativeTitle: String = "Oui",
        negativeTitle: String = "Non",
        popupOffset: CGFloat,
        onAnswer: @escaping (Bool) -> Void
    ) {
        self.question = question
        self.subtitle = subtitle
        self.affirmativeTitle = affirmativeTitle
        self.negativeTitle = negativeTitle
        self.popupOffset = popupOffset
        self.onAnswer = onAnswer
    }

    var body: some View {
        VStack {
            Spacer()
            Spacer()

            Button(action: {}) {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(OnboardingTheme.bodyText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)

                        Text(question)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.narrativeText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    HStack(spacing: 16) {
                        popupButton(title: negativeTitle, icon: "xmark") {
                            HapticManager.shared.impact(.medium)
                            onAnswer(false)
                        }

                        popupButton(title: affirmativeTitle, icon: "checkmark") {
                            HapticManager.shared.impact(.medium)
                            onAnswer(true)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 30))
            .controlSize(.large)
            .padding(.horizontal, 20)
            .offset(y: popupOffset)
            .scaleEffect(popupOffset == 0 ? 1.0 : 0.9)
            .opacity(popupOffset == 0 ? 1.0 : 0.0)
        }
        .padding(.bottom, 40)
    }

    private func popupButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.92, blue: 0.98),
                    Color(red: 0.92, green: 0.95, blue: 0.98)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }
}
