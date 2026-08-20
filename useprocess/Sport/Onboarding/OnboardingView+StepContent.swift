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
            EmptyView()
                .onAppear { skipTransientStep() }
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
                    if isValid {
                        viewModel.refreshBodyCompositionRouting()
                    }
                },
                onContinue: nextStep // ✅ NOUVEAU: Passer à l'étape suivante depuis le clavier
            )
        case .heightWeight, .bodyScan, .primaryGoal, .weightGoal, .idealWeight, .weightGoalIncompatible,
             .sportClub, .experienceLevel, .hardestMeal,
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
             .caloriesGoal, .carryOverCalories, .appRating,
             .processWelcome, .referralReward, .featuresUnlock,
             .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks,
             .processResultsDurability, .personalizedWelcome:
            EmptyView()
                .onAppear { skipTransientStep() }
        case .faceLeverageIntro:
            FaceLeverageIntroStepView(
                viewModel: viewModel,
                onContinue: nextStep,
                onValidationChanged: { isValid in
                    viewModel.isFaceLeverageIntroCompleted = isValid
                }
            )
        case .referralCode:
            OnboardingCreatorCodeStepView(
                draftCode: $viewModel.creatorCodeDraft,
                isVerified: $viewModel.creatorCodeIsVerified,
                continueAttempt: viewModel.creatorCodeContinueAttempt,
                keyboardOverlap: keyboardHeight.height,
                onAutoContinue: advanceFromVerifiedCreatorCode
            )
            .onAppear {
                viewModel.bootstrapCreatorCodeDraftIfNeeded()
            }
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
                isAlreadyCompleted: viewModel.isWeightEstimationCompleted,
                onValidationChanged: { isValid in
                    viewModel.isWeightEstimationCompleted = isValid
                    viewModel.isGoalProjectionCompleted = isValid
                    if isValid {
                        viewModel.saveProgress()
                    }
                },
                onContinueUnlockProgressChanged: { progress in
                    viewModel.estimationContinueUnlockProgress = progress
                }
            )
        case .healthKitPermissions:
            EmptyView()
                .onAppear { skipTransientStep() }
        case .sleepDataRecovery:
            EmptyView()
                .onAppear { skipTransientStep() }
        case .biometricAuth:
            BiometricAuthStepView(onComplete: nextStep)
        case .transformationPreview:
            TransformationPreviewStepView(
                gender: viewModel.selectedGender,
                onComplete: nextStep
            )
        case .dashboardPreview:
            DashboardPreviewStepView(
                hasCompletedFirstScan: viewModel.isFaceAnalysisCompleted,
                onFirstScanResult: { viewModel.recordDashboardFaceScanResult($0) },
                onFirstScanContinue: { advanceFromEarlyDashboardFaceScan() },
                onBeginFirstScan: { viewModel.dismissOnboardingFaceScan() },
                onFirstScanSkipLater: {
                    viewModel.skipDashboardFaceScanForLater()
                    advanceFromEarlyDashboardFaceScan()
                },
                initialScanPersistedState: viewModel.dashboardScanPersistedState,
                pendingScanResult: pendingDashboardScanResultForRestore,
                onScanPersistedStateChange: { state in
                    if let state {
                        viewModel.persistDashboardScanState(state)
                    } else {
                        viewModel.clearDashboardScanPersistedState()
                    }
                }
            )
            .onAppear {
                viewModel.onOnboardingFaceScanContinueFromDashboard = {
                    advanceFromEarlyDashboardFaceScan()
                }
            }
        case .dreamFaceCommit:
            DreamFaceCommitStepView(onComplete: nextStep)
        case .programCreation:
            OnboardingProgramCreationStepView(
                viewModel: viewModel,
                onComplete: nextStep
            )
        case .notificationPermission:
            EmptyView()
                .onAppear { skipTransientStep() }
        case .payment:
            PaywallView(
                onComplete: {
                    advanceFromPaymentToPostPaymentWelcome()
                },
                onBack: previousStep
            )
        case .appleSignIn:
            OnboardingPostPaymentThankYouView(
                viewModel: viewModel,
                onComplete: {
                    Task { await completeOnboarding() }
                }
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
