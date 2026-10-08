//
//  OnboardingAnalysisYesNoPopup.swift
//  Process
//
//  Popup Oui / Non partagée (chat analyse + création programme).
//

import SwiftUI

struct OnboardingAnalysisYesNoPopup: View {
    let subtitle: String?
    let headerImageName: String?
    let question: String
    let affirmativeTitle: String
    let negativeTitle: String
    let showsNegativeButton: Bool
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
        headerImageName: String? = nil,
        question: String,
        affirmativeTitle: String? = nil,
        negativeTitle: String? = nil,
        showsNegativeButton: Bool = true,
        popupOffset: CGFloat = 0,
        onAnswer: @escaping (Bool) -> Void
    ) {
        self.subtitle = subtitle
        self.headerImageName = headerImageName
        self.question = question
        self.affirmativeTitle = affirmativeTitle ?? OnboardingCopy.t("Oui", en: "Yes")
        self.negativeTitle = negativeTitle ?? OnboardingCopy.t("Non", en: "No")
        self.showsNegativeButton = showsNegativeButton
        self.popupOffset = popupOffset
        self.onAnswer = onAnswer
    }

    var body: some View {
        VStack {
            Spacer()
            Spacer()

            // Conteneur simple (pas un `Button`) : des boutons imbriqués dans un bouton sont fusionnés
            // par VoiceOver en un seul élément inerte, alors que la progression attend une réponse.
            Group {
                VStack(spacing: headerSpacing) {
                    if let headerImageName {
                        Image(headerImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(OnboardingTheme.mutedText.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }

                    Text(question)
                        .font(.system(size: headerImageName == nil ? 24 : 22, weight: .bold))
                        .foregroundStyle(OnboardingTheme.narrativeText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 14)

                    HStack(spacing: 16) {
                        if showsNegativeButton {
                            popupButton(title: negativeTitle, icon: "xmark") {
                                HapticManager.shared.impact(.medium)
                                onAnswer(false)
                            }
                        }

                        popupButton(title: affirmativeTitle, icon: showsNegativeButton ? "checkmark" : "arrow.right") {
                            HapticManager.shared.impact(.medium)
                            onAnswer(true)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .padding(.vertical, 38)
                .padding(.horizontal, 34)
                .frame(maxWidth: .infinity)
                .frame(minHeight: headerImageName == nil ? 230 : 250)
            }
            .processGlassEffect(in: popupShape, interactive: false)
            .padding(.horizontal, 12)
            .offset(y: popupOffset)
        }
        .padding(.bottom, 34)
        .allowsHitTesting(true)
    }

    private var headerSpacing: CGFloat {
        if headerImageName != nil {
            return subtitle == nil ? 22 : 18
        }
        return subtitle == nil ? 34 : 26
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
            .contentShape(actionButtonShape)
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
