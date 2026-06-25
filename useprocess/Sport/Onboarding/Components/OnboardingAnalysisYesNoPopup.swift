//
//  OnboardingAnalysisYesNoPopup.swift
//  Process
//
//  Popup Oui / Non partagée (chat analyse + création programme).
//

import SwiftUI

struct OnboardingAnalysisYesNoPopup: View {
    let question: String
    let affirmativeTitle: String
    let negativeTitle: String
    let popupOffset: CGFloat
    let onAnswer: (Bool) -> Void

    init(
        question: String,
        affirmativeTitle: String = "Oui",
        negativeTitle: String = "Non",
        popupOffset: CGFloat,
        onAnswer: @escaping (Bool) -> Void
    ) {
        self.question = question
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
                VStack(spacing: 34) {
                    Text(question)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(OnboardingTheme.narrativeText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 14)

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
                    .padding(.horizontal, 6)
                }
                .padding(.vertical, 38)
                .padding(.horizontal, 34)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 230)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 18))
            .controlSize(.large)
            .padding(.horizontal, 12)
            .offset(y: popupOffset)
            .scaleEffect(popupOffset == 0 ? 1.0 : 0.94)
            .opacity(popupOffset == 0 ? 1.0 : 0.0)
        }
        .padding(.bottom, 34)
    }

    private func popupButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 20, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
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
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .buttonBorderShape(.roundedRectangle(radius: 22))
        .controlSize(.large)
    }
}
