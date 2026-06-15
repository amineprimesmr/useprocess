//
//  HasWeightGoalStepView.swift
//  Process
//
//  As-tu un objectif de poids ? (Oui / Non)
//

import SwiftUI

struct HasWeightGoalStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var onValidationChanged: ((Bool) -> Void)?

    var body: some View {
        OnboardingStandardStepLayout("As-tu un", "objectif de poids ?") {
            VStack(spacing: 20) {
                binaryButton(title: "Oui", selected: viewModel.hasWeightGoal == true) {
                    viewModel.applyHasWeightGoal(true)
                    onValidationChanged?(true)
                }

                binaryButton(title: "Non", selected: viewModel.hasWeightGoal == false) {
                    viewModel.applyHasWeightGoal(false)
                    onValidationChanged?(true)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear {
            OnboardingValidationScheduler.deferValidation {
                onValidationChanged?(viewModel.hasWeightGoal != nil)
            }
        }
    }

    private func binaryButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? .green : OnboardingTheme.mutedText)
                    .font(.system(size: 20))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .glassStyle()
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .opacity(selected ? 1.0 : 0.6)
    }
}
