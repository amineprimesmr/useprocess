//
//  OnboardingView+StepContent.swift
//  Process
//
//  Contenu des étapes d'onboarding (switch extrait de OnboardingView).
//

import SwiftUI

extension SportOnboardingView {
    @ViewBuilder
    func onboardingStepContent(for step: OnboardingStep) -> some View {
        switch step {
        case .videoIntroduction:
            OnboardingWelcomeStepView(onComplete: nextStep)
        case .genderSelection:
            GenderSelectionStepView(
                selectedGender: $viewModel.selectedGender,
                onValidationChanged: { isValid in
                    viewModel.isGenderSelected = isValid
                }
            )
        case .ageSelection:
            AgeSelectionStepView(
                selectedAge: $viewModel.selectedAge,
                onValidationChanged: { isValid in
                    viewModel.isAgeSelected = isValid
                }
            )
        case .height:
            HeightStepView(
                selectedHeight: $viewModel.selectedHeight,
                onValidationChanged: { isValid in
                    // ✅ Forcer la mise à jour sur le main thread
                    Task { @MainActor in
                        viewModel.isHeightWeightSelected = isValid
                    }
                }
            )
        case .weight:
            WeightStepView(
                selectedWeight: $viewModel.selectedWeight,
                onValidationChanged: { isValid in
                    viewModel.isHeightWeightSelected = isValid
                },
                onContinue: nextStep // ✅ NOUVEAU: Passer à l'étape suivante depuis le clavier
            )
        case .heightWeight, .bodyScan, .primaryGoal, .weightGoal, .sportClub, .experienceLevel, .hardestMeal,
             .appleSignIn,
             .yearsOfExperience, .deadlineSelection, .eventDetails,
             .potentialPace, .trainingFrequency, .nutritionScanFeature,
             .hasDietaryRestrictions, .whichRestrictions,
             .nutritionObstacles, .perfectNutritionBelief, .hasSufficientHydration, .hydrationLevel,
             .nutritionPotential,
             .goalPace, .hasSportActivity, .sportSelection,
             .weightManagementExperience, .weightFailureReasons, .nutritionQuality,
             .goalProjection,
             .sleepNeed, .planGeneration,
             .newsStep, .sleepNeedReveal, .sleepDebtInfo, .planReady, .onboardingInfo,
             .alarmConfiguration, .sleepWindowReveal,
             .referralCode, .caloriesGoal, .carryOverCalories, .appRating,
             .processWelcome, .referralReward, .featuresUnlock,
             .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks,
             .personalizedWelcome, .processResultsDurability:
            EmptyView()
                .onAppear { skipTransientStep() }
        case .faceAnalysis:
            FaceScanStepView(
                viewModel: viewModel,
                onComplete: nextStep,
                onBack: previousStep
            )
        case .firstNameInput:
            FirstNameInputStepView(
                firstName: $viewModel.firstName,
                onComplete: nextStep,
                onValidationChanged: { isValid in
                    viewModel.isFirstNameEntered = isValid
                }
            )
        case .idealWeight:
            IdealWeightStepView(
                idealWeight: $viewModel.idealWeightValue,
                currentWeight: viewModel.selectedWeight,
                recommendedIdealWeight: viewModel.recommendedIdealWeight(),
                onValidationChanged: { isValid in
                    viewModel.isIdealWeightEntered = isValid
                    if isValid {
                        viewModel.applyHasWeightGoal(true)
                        viewModel.syncInferredWeightGoal()
                        viewModel.saveProgress()
                    }
                },
                onContinue: nextStep,
                onPersistAnswers: {
                    viewModel.saveProgress()
                }
            )
        case .weightGoalIncompatible:
            WeightGoalIncompatibleStepView(
                firstName: viewModel.firstName,
                currentWeight: viewModel.selectedWeight,
                height: viewModel.selectedHeight,
                selectedGoal: viewModel.selectedWeightGoal ?? .lose,
                onBack: previousStep,
                onValidationChanged: { _ in }
            )
        case .weightMotivation:
            OnboardingProfileChatView(
                onboardingViewModel: viewModel,
                onComplete: nextStep
            )
        case .weightEstimation:
            OnboardingEstimationStepView(
                context: .make(
                    viewModel: viewModel,
                    selectedSports: OnboardingDataModel.shared.selectedSports
                ),
                onValidationChanged: { isValid in
                    viewModel.isWeightEstimationCompleted = isValid
                    viewModel.isGoalProjectionCompleted = isValid
                }
            )
        case .healthKitPermissions:
            EmptyView()
                .onAppear { skipTransientStep() }
        case .sleepDataRecovery:
            EmptyView()
                .onAppear { skipTransientStep() }
        case .biometricAuth:
            BiometricAuthStepView(
                onComplete: nextStep,
                onBack: previousStep,
                onAuthenticationComplete: { completed in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        biometricAuthCompleted = completed
                    }
                }
            )
            .onAppear {
                // Réinitialiser l'état quand on arrive sur cette page
                biometricAuthCompleted = false
            }
        case .notificationPermission:
            NotificationPermissionStepView(onComplete: nextStep, onBack: previousStep)
                .environmentObject(permissionsManager)
        case .transformationPreview:
            TransformationPreviewStepView(onComplete: nextStep, onBack: previousStep)
        case .programCreation:
            EmptyView()
                .onAppear { skipTransientStep() }
        case .payment:
            PaywallView(
                onComplete: {
                    Task { await completeOnboarding() }
                },
                onBack: previousStep
            )
        case .complete:
            Color.clear
                .task { await completeOnboarding() }
        @unknown default:
            EmptyView()
                .onAppear {
                    nextStep()
                }
        }

    }
}
