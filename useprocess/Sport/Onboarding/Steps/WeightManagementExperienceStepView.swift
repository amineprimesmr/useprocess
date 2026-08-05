//
//  WeightManagementExperienceStepView.swift
//  Process
//
//  Vue pour l'expérience avec la perte/prise de poids
//

import SwiftUI

struct WeightManagementExperienceStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedExperience: WeightManagementExperience?
    var weightGoal: WeightGoal?  // Pour adapter le texte (perdre ou prendre)
    var onValidationChanged: ((Bool) -> Void)?

    private var actionText: String {
        guard let goal = weightGoal else {
            return OnboardingCopy.t("perdre ou prendre", en: "lose or gain")
        }
        switch goal {
        case .lose:
            return OnboardingCopy.t("perdre", en: "lose")
        case .gain:
            return OnboardingCopy.t("prendre", en: "gain")
        }
    }

    private let choiceShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Image de fond nutri
                NutritionStepBackground()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Espace pour le titre en overlay (150pt)
                    Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement uniforme entre titre et réponses
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(Array(WeightManagementExperience.allCases.enumerated()), id: \.element.id) { index, experience in
                                Button(action: {
                                    HapticManager.shared.selection()
                                    selectedExperience = experience
                                    onValidationChanged?(true)
                                }) {
                                    HStack(spacing: 12) {
                                        Text(experience.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(OnboardingTheme.primaryText)

                                        Spacer()

                                        if selectedExperience == experience {
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
                                .opacity(selectedExperience == experience ? 1.0 : 0.6)
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
                        OnboardingCopy.t("As-tu déjà", en: "Have you ever"),
                        OnboardingCopy.t("essayé de \(actionText) du poids ?", en: "tried to \(actionText) weight?")
                    )
                        .padding(.top, OnboardingConstants.titleTopPadding) // Position ABSOLUE : 55pt depuis le haut
                    Spacer()
                }

                // ✅ Fond noir progressif en bas pour belle UX (dégradé fluide)
                VStack {
                    Spacer()

                    // Gradient progressif pour effet de transition fluide
                    LinearGradient(
                        colors: [Color.clear] + OnboardingTheme.imageScrimGradient(for: colorScheme),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
                }
            }
        }
        .onAppear {
            onValidationChanged?(selectedExperience != nil)
        }
}
}
