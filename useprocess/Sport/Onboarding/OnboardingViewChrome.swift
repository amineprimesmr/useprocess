//
//  OnboardingViewChrome.swift
//  Process
//
//  Barre d’actions spécifiques (HealthKit, fin, calories, etc.) et header onboarding
//  (retour, progression, langue). Extrait de OnboardingView pour réduire la taille du fichier.
//

import SwiftUI

// MARK: - Barre du bas (étapes avec boutons dédiés)

struct OnboardingSpecificBottomBar: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var hapticManager: HapticManager
    @Binding var caloriesGoalSelected: Bool?
    @Binding var carryOverCaloriesSelected: Bool?
    @Binding var biometricAuthCompleted: Bool

    var onNextStep: () -> Void
    var onRequestHealthKit: () async -> Void
    var onCompleteOnboarding: () async -> Void
    var onBiometricContinue: () async -> Void

    var body: some View {
        bottomButtonContent
    }

    @ViewBuilder
    private var bottomButtonContent: some View {
        switch OnboardingStep(rawValue: viewModel.currentStep) {
        case .caloriesGoal:
            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    caloriesGoalSelected = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onNextStep()
                    }
                }) {
                    Text("Non")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(OnboardingTheme.actionButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))

                Button(action: {
                    HapticManager.shared.impact(.medium)
                    caloriesGoalSelected = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onNextStep()
                    }
                }) {
                    Text("Oui")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(OnboardingTheme.actionButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
            }
            .padding(.horizontal, 40)

        case .carryOverCalories:
            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    carryOverCaloriesSelected = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onNextStep()
                    }
                }) {
                    Text("Non")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(OnboardingTheme.actionButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))

                Button(action: {
                    HapticManager.shared.impact(.medium)
                    carryOverCaloriesSelected = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onNextStep()
                    }
                }) {
                    Text("Oui")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(OnboardingTheme.actionButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
            }
            .padding(.horizontal, 40)

        case .hasDietaryRestrictions, .whichRestrictions:
            EmptyView()

        case .biometricAuth:
            if biometricAuthCompleted {
                Button(action: {
                    Task {
                        await onBiometricContinue()
                    }
                }) {
                    Text("Je m'engage envers moi-même")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(OnboardingTheme.actionButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .scale))
            }

        case .faceAnalysis:
            EmptyView()

        default:
            let isValid = viewModel.isCurrentStepValidated()
            let currentStep = OnboardingStep(rawValue: viewModel.currentStep)

            let canContinue: Bool = {
                if currentStep == .height {
                    return viewModel.selectedHeight > 0
                } else if currentStep == .weight {
                    return viewModel.selectedWeight > 0
                } else {
                    return isValid
                }
            }()

            Button(action: {
                onNextStep()
            }) {
                Text("CONTINUER")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 50))
            .padding(.horizontal, 40)
            .disabled(!canContinue)
            .opacity(canContinue ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.3), value: canContinue)
            .allowsHitTesting(canContinue)
            .onAppear {
                if currentStep == .height || currentStep == .weight {
                }
            }
        }
    }
}

// MARK: - Header (retour, progression, langue)

struct OnboardingHeaderChrome: View {
    @EnvironmentObject private var profileService: UnifiedProfileService
    @ObservedObject var viewModel: OnboardingViewModel
    var hapticManager: HapticManager
    var shouldShowBackButton: Bool
    var flowProgress: Double
    var onPreviousStep: () -> Void

    var body: some View {
        headerContent
    }

    @ViewBuilder
    private var headerContent: some View {
        let showsFull = OnboardingHeaderLayout.showsFullHeader(currentStep: viewModel.currentStep)
        let showsBack = OnboardingHeaderLayout.showsBackOnly(
            currentStep: viewModel.currentStep,
            shouldShowBackButton: shouldShowBackButton
        )

        if showsFull || showsBack {
            onboardingHeaderBar(showsProgressAndLanguage: showsFull)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func onboardingHeaderBar(showsProgressAndLanguage: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if shouldShowBackButton {
                    OnboardingBackButton(action: onPreviousStep)
                } else {
                    Color.clear
                        .frame(
                            width: OnboardingConstants.backButtonSize,
                            height: OnboardingConstants.backButtonSize
                        )
                }

                if showsProgressAndLanguage {
                    OnboardingProgressBar(progress: flowProgress)
                        .frame(maxWidth: .infinity)
                        .frame(height: 4)

                    LanguageSelectorView()
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, OnboardingConstants.headerHorizontalPadding)
            .frame(height: OnboardingConstants.backButtonSize, alignment: .center)
            .padding(.top, OnboardingConstants.headerBackButtonTopPadding)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }
}
