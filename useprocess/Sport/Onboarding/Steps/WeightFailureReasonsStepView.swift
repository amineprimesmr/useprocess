//
//  WeightFailureReasonsStepView.swift
//  Process
//
//  Vue pour identifier ce qui empêche l'utilisateur de réussir à perdre/prendre du poids
//

import SwiftUI

struct WeightFailureReasonsStepView: View {
    @Binding var selectedReasons: Set<NutritionObstacle>
    var onValidationChanged: ((Bool) -> Void)?

    private let choiceShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Image de fond nutri
                NutritionStepBackground()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Espace pour le titre en overlay
                    Spacer()
                        .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement uniforme entre titre et réponses
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            // ✅ Filtrer "Aucun obstacle" de la liste car ce n'est pas pertinent ici
                            ForEach(Array(NutritionObstacle.allCases.filter { $0 != .noObstacle }.enumerated()), id: \.element) { index, obstacle in
                                Button(action: {
                                    HapticManager.shared.selection()

                                    if selectedReasons.contains(obstacle) {
                                        selectedReasons.remove(obstacle)
                                    } else {
                                        selectedReasons.insert(obstacle)
                                    }

                                    onValidationChanged?(!selectedReasons.isEmpty)
                                }) {
                                    HStack(spacing: 12) {
                                        Text(obstacle.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(OnboardingTheme.primaryText)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Spacer()

                                        if selectedReasons.contains(obstacle) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 20))
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(OnboardingTheme.mutedText)
                                                .font(.system(size: 20))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .processGlassButton(in: choiceShape)
                                .opacity(selectedReasons.contains(obstacle) ? 1.0 : 0.6)
                            }
                        }
                        .padding(.horizontal, 40)

                        // Espace pour le bouton en bas
                        Spacer()
                            .frame(height: 100)
                    }
                }

                // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
                VStack {
                    OnboardingTitleView(
                        OnboardingCopy.t("Qu'est-ce qui", en: "What's getting"),
                        OnboardingCopy.t("t'empêche de réussir ?", en: "in your way?")
                    )
                        .padding(.top, OnboardingConstants.titleTopPadding)
                    Spacer()
                }
            }
        }
        .onAppear {
            onValidationChanged?(!selectedReasons.isEmpty)
        }
}
}
