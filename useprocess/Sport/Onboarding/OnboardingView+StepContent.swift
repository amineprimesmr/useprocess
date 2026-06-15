//
//  OnboardingView+StepContent.swift
//  Process
//
//  Contenu des étapes d'onboarding (switch extrait de OnboardingView).
//

import SwiftUI
import AuthenticationServices
import HealthKit
import LocalAuthentication

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
        case .heightWeight, .bodyScan, .weightGoal, .sportClub, .experienceLevel, .hardestMeal,
             .appleSignIn,
             .yearsOfExperience, .deadlineSelection, .eventDetails,
             .potentialPace, .trainingFrequency, .nutritionScanFeature,
             .hasDietaryRestrictions, .whichRestrictions,
             .nutritionObstacles, .perfectNutritionBelief, .hasSufficientHydration, .hydrationLevel,
             .nutritionPotential,
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
        case .primaryGoal:
            HasWeightGoalStepView(
                viewModel: viewModel,
                onValidationChanged: { isValid in
                    viewModel.isPrimaryGoalSelected = isValid
                }
            )
        case .idealWeight:
            IdealWeightStepView(
                idealWeight: $viewModel.idealWeightValue,
                currentWeight: viewModel.selectedWeight,
                height: viewModel.selectedHeight,
                age: viewModel.selectedAge,
                gender: viewModel.selectedGender ?? .male,
                weightGoal: viewModel.selectedWeightGoal,
                firstName: viewModel.firstName,
                onValidationChanged: { isValid in
                    viewModel.isIdealWeightEntered = isValid
                    if isValid {
                        viewModel.syncInferredWeightGoal()
                        viewModel.saveProgress()
                    }
                },
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
            WeightMotivationStepView(
                viewModel: viewModel,
                currentWeight: viewModel.selectedWeight,
                idealWeight: viewModel.idealWeightValue,
                weightGoal: viewModel.selectedWeightGoal,
                onComplete: nextStep,
                onValidationChanged: { _ in
                    // Validation automatique
                }
            )
        case .hasSportActivity:
            HasSportActivityStepView(
                hasSportActivity: $viewModel.hasSportActivity,
                onValidationChanged: { _ in
                    // Validation automatique
                }
            )
        case .sportSelection:
            SportSelectionStepView(
                onComplete: nextStep,
                onValidationChanged: { isValid in
                    viewModel.isSportsSelected = isValid
                },
                onSearchStateChanged: { isSearching in
                    isSportSearchActive = isSearching
                }
            )
        case .goalProjection:
            OnboardingEstimationStepView(
                context: .make(
                    phase: .optimized,
                    viewModel: viewModel,
                    selectedSports: Set(profileService.currentProfile?.sports.map { $0.name } ?? [])
                ),
                onValidationChanged: { isValid in
                    viewModel.isGoalProjectionCompleted = isValid
                }
            )
        case .goalPace:
            GoalPaceStepView(
                selectedPace: $viewModel.selectedGoalPace,
                weightGoal: viewModel.selectedWeightGoal,
                onValidationChanged: { isValid in
                    viewModel.isGoalPaceSelected = isValid
                }
            )
        case .weightEstimation:
            OnboardingEstimationStepView(
                context: .make(
                    phase: .baseline,
                    viewModel: viewModel,
                    selectedSports: []
                ),
                onValidationChanged: { isValid in
                    viewModel.isWeightEstimationCompleted = isValid
                }
            )
        case .weightManagementExperience:
            WeightManagementExperienceStepView(
                selectedExperience: $viewModel.nutritionProfile.weightManagementExperience,
                weightGoal: viewModel.selectedWeightGoal,
                onValidationChanged: { isValid in
                    viewModel.isWeightManagementExperienceSelected = isValid
                }
            )
        case .weightFailureReasons:
            WeightFailureReasonsStepView(
                selectedReasons: $viewModel.nutritionProfile.nutritionObstacles,
                onValidationChanged: { _ in
                    // Validation automatique
                }
            )
        case .nutritionQuality:
            NutritionQualityStepView(
                selectedQuality: Binding(
                    get: { viewModel.nutritionProfile.nutritionQuality },
                    set: { viewModel.updateNutritionQuality($0) }
                ),
                onValidationChanged: { isValid in
                    viewModel.isNutritionQualitySelected = isValid
                }
            )
            .onAppear {
                DispatchQueue.main.async {
                    if viewModel.nutritionProfile.nutritionQuality == nil {
                        viewModel.updateNutritionQuality(.average)
                    }
                }
            }
        case .healthKitPermissions:
            PermissionStepView(kind: .healthKit, onComplete: nextStep)
                .environmentObject(permissionsManager)
                .environmentObject(healthManager)
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
        case .programCreation:
            ProgramCreationStepView(
                onComplete: nextStep,
                onBack: previousStep,
                onValidationChanged: { isValid in
                    viewModel.isProgramCreationCompleted = isValid
                }
            )
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
