//
//  OnboardingView+StepContent.swift
//  Process
//

import SwiftUI

extension SportOnboardingView {
    @ViewBuilder
    func onboardingStepContent(for step: OnboardingStep) -> some View {
        switch step {
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
                onContinue: nextStep
            )
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
                onAutoContinue: advanceFromVerifiedCreatorCode,
                onSkip: skipCreatorCodeStep
            )
            .onAppear {
                viewModel.bootstrapCreatorCodeDraftIfNeeded()
            }
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
        case .payment:
            PaywallView(
                onComplete: {
                    advanceFromPaymentToPostPaymentWelcome()
                },
                onBack: previousStep
            )
        case .postPaymentWelcome:
            OnboardingPostPaymentWelcomeStepView(onComplete: nextStep)
        case .explainerBodyFat:
            OnboardingExplainerBodyFatStepView(onComplete: nextStep)
        case .explainerWaterRetention:
            OnboardingExplainerWaterRetentionStepView(onComplete: nextStep)
        case .explainerLymphDrainage:
            OnboardingExplainerLymphDrainageStepView(onComplete: nextStep)
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
        }
    }
}
