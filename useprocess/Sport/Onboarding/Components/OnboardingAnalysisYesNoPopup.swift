//
//  OnboardingAnalysisYesNoPopup.swift
//  Process
//
//  Popup Oui / Non partagée (chat analyse + création programme).
//

import SwiftUI

struct OnboardingAnalysisYesNoPopup: View {
    let subtitle: String?
    let question: String
    let affirmativeTitle: String
    let negativeTitle: String
    let popupOffset: CGFloat
    let onAnswer: (Bool) -> Void

    private let popupCornerRadius: CGFloat = 28
    private let actionCornerRadius: CGFloat = 20

    private var popupShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: popupCornerRadius, style: .continuous)
    }

    private var actionButtonShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: actionCornerRadius, style: .continuous)
    }

    init(
        subtitle: String? = nil,
        question: String,
        affirmativeTitle: String = "Oui",
        negativeTitle: String = "Non",
        popupOffset: CGFloat = 0,
        onAnswer: @escaping (Bool) -> Void
    ) {
        self.subtitle = subtitle
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
                VStack(spacing: subtitle == nil ? 34 : 26) {
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(OnboardingTheme.mutedText.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }

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
            .processGlassButton(in: popupShape, interactive: false)
            .buttonBorderShape(.roundedRectangle(radius: popupCornerRadius))
            .controlSize(.large)
            .padding(.horizontal, 12)
            .offset(y: popupOffset)
        }
        .padding(.bottom, 34)
        .allowsHitTesting(true)
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
        .clipShape(actionButtonShape)
        .buttonBorderShape(.roundedRectangle(radius: actionCornerRadius))
        .controlSize(.large)
    }
}
