//
//  GenderSelectionStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

struct GenderSelectionStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @Binding var selectedGender: Gender?
    @State private var isAnimating = false

    // Callback pour notifier la validation
    var onValidationChanged: ((Bool) -> Void)?

    var body: some View {
        ZStack {
            // ✅ Le fond noir et la lueur animée sont gérés par OnboardingView

            VStack(spacing: 0) {
                // Espace pour le titre en overlay + espacement uniforme
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement uniforme entre titre et réponses
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                // Images de sélection du genre (sans boutons LiquidGlass) - TAILLE ADAPTÉE POUR iPad
                HStack(spacing: LayoutConstants.isIPad ? 32 : 16) { // ✅ Plus d'espace entre les images sur iPad
                    Spacer()

                    // Image Homme
                    Button(action: {
                        selectGender(.male)
                    }) {
                        VStack(spacing: 4) {
                            Image("homme")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: LayoutConstants.isIPad
                                        ? (selectedGender == .male ? 200 : 160) // ✅ Plus grandes sur iPad
                                        : (selectedGender == .male ? 150 : 120),
                                    height: LayoutConstants.isIPad
                                        ? (selectedGender == .male ? 280 : 220) // ✅ Plus grandes sur iPad
                                        : (selectedGender == .male ? 210 : 170)
                                )
                                .opacity(selectedGender == .male ? 1.0 : 0.6)

                            Text(OnboardingCopy.binaryLabels(sportFirst: "Homme", sportSecond: "Femme").0)
                                .font(.system(size: LayoutConstants.isIPad ? 20 : 16, weight: .medium, design: .rounded))
                                .foregroundStyle(OnboardingTheme.primaryText)
                                .opacity(selectedGender == .male ? 1.0 : 0.6)
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(selectedGender == .male ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedGender)

                    Spacer()

                    // Image Femme
                    Button(action: {
                        selectGender(.female)
                    }) {
                        VStack(spacing: 4) {
                            Image("femme")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: LayoutConstants.isIPad
                                        ? (selectedGender == .female ? 200 : 160) // ✅ Plus grandes sur iPad
                                        : (selectedGender == .female ? 150 : 120),
                                    height: LayoutConstants.isIPad
                                        ? (selectedGender == .female ? 280 : 220) // ✅ Plus grandes sur iPad
                                        : (selectedGender == .female ? 210 : 170)
                                )
                                .opacity(selectedGender == .female ? 1.0 : 0.6)

                            Text(OnboardingCopy.binaryLabels(sportFirst: "Homme", sportSecond: "Femme").1)
                                .font(.system(size: LayoutConstants.isIPad ? 20 : 16, weight: .medium, design: .rounded))
                                .foregroundStyle(OnboardingTheme.primaryText)
                                .opacity(selectedGender == .female ? 1.0 : 0.6)
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(selectedGender == .female ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedGender)

                    Spacer()
                }
                .adaptiveHorizontalPadding() // ✅ Padding adaptatif pour iPad
                .frame(height: LayoutConstants.isIPad ? 320 : 250) // ✅ Plus de hauteur sur iPad

                Spacer()
                    .frame(height: 100) // Espacement en bas
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Choisis ton genre")
                    .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
            }

        }
        .onAppear {
            // Animation d'entrée
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                isAnimating = true
            }
        }
    }

    private func selectGender(_ gender: Gender) {
        HapticManager.shared.impact(.medium)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedGender = gender
        }

        // Notifier la validation
        onValidationChanged?(true)

        // ✅ FINALISATION: Sauvegarde directe dans le profil pour persistance immédiate
        // Le ViewModel sera synchronisé via OnboardingCoordinator à la fin
        Task {
            do {
                if var currentProfile = profileService.currentProfile {
                    currentProfile.gender = gender
                    try await profileService.saveProfile(currentProfile)
                }
            } catch {
            DebugLogger.error("\(error.localizedDescription)")
        }
}
}
}
