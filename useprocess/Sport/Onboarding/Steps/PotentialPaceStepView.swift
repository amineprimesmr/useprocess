//
//  PotentialPaceStepView.swift
//  Process
//
//  Vue pour sélectionner la vitesse d'atteinte de 100% du potentiel
//

import SwiftUI

struct PotentialPaceStepView: View {
    @Binding var selectedPace: GoalPace?
    var onValidationChanged: ((Bool) -> Void)?

    @State private var sliderValue: Double = 2.0

    private let minValue: Double = 0.0
    private let maxValue: Double = 4.0

    var body: some View {
        VStack(spacing: 60) {
            // Titre aligné en haut (même position pour toutes les pages)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(OnboardingCopy.titleLines(from: ["À quelle vitesse", "veux-tu atteindre", "100% de ton potentiel ?"]).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position fixe en haut (même que les autres pages)

            VStack(spacing: 30) {
                // Affichage du rythme sélectionné
                if let pace = selectedPace {
                    VStack(spacing: 12) {
                        Image(systemName: pace.icon)
                            .font(.system(size: 50))
                            .foregroundColor(getPaceColor(pace))

                        Text(OnboardingCopy.choiceLabel(index: 0, sport: pace.rawValue))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text(OnboardingCopy.text(pace.description, blank: "Description à personnaliser"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(getPaceColor(pace).opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(getPaceColor(pace).opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .scale))
                }

                // Slider
                VStack(spacing: 16) {
                    Slider(value: $sliderValue, in: minValue...maxValue, step: 1.0)
                        .accentColor(selectedPace.map { getPaceColor($0) } ?? .blue)
                        .padding(.horizontal, 30)
                        .onChange(of: sliderValue) { _, newValue in
                            HapticManager.shared.selection()
                            updatePace(from: newValue)
                        }

                    // Labels des extrémités
                    HStack {
                        Text(OnboardingCopy.binaryLabels(sportFirst: "Lent", sportSecond: "Rapide").0)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        Spacer()

                        Text(OnboardingCopy.binaryLabels(sportFirst: "Lent", sportSecond: "Rapide").1)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 30)
                }
            }

            Spacer()
        }
        .onAppear {
            if let pace = selectedPace {
                sliderValue = paceSliderPosition(for: pace)
            } else {
                sliderValue = 2.0
                updatePace(from: sliderValue)
            }

            DispatchQueue.main.async {
                onValidationChanged?(selectedPace != nil)
            }
        }
    }

    private func paceSliderPosition(for pace: GoalPace) -> Double {
        switch pace {
        case .noRush: return 0.0
        case .relaxed: return 1.0
        case .moderate: return 2.0
        case .aggressive: return 3.0
        case .asFastAsPossible: return 4.0
        }
    }

    private func updatePace(from value: Double) {
        let pace: GoalPace

        // Mapper la valeur du slider (0-4) aux valeurs de GoalPace
        switch value {
        case 0.0:
            pace = .noRush  // Lent (gauche)
        case 1.0:
            pace = .relaxed
        case 2.0:
            pace = .moderate
        case 3.0:
            pace = .aggressive
        case 4.0:
            pace = .asFastAsPossible  // Rapide (droite)
        default:
            pace = .moderate
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedPace = pace
        }

        // ✅ CORRECTION: Un seul appel à onValidationChanged pour éviter les animations conflictuelles
        DispatchQueue.main.async {
            self.onValidationChanged?(true)
        }
    }

    private func getPaceColor(_ pace: GoalPace) -> Color {
        switch pace {
        case .asFastAsPossible:
            return .red
        case .aggressive:
            return .orange
        case .moderate:
            return .blue
        case .relaxed:
            return .green
        case .noRush:
            return .mint
        }
}
}
