//
//  OnboardingNavigationEngine.swift
//  Process
//

import Foundation

@MainActor
class OnboardingNavigationEngine {
    let viewModel: OnboardingViewModel
    let profileService: UnifiedProfileService

    /// Étape simulée pour `buildActiveFlowPath` sans toucher au `currentStep` publié.
    private var stepForNavigation: Int?

    private var resolvedCurrentStep: Int {
        stepForNavigation ?? viewModel.currentStep
    }

    init(viewModel: OnboardingViewModel, profileService: UnifiedProfileService) {
        self.viewModel = viewModel
        self.profileService = profileService
    }

    /// Parcours linéaire attendu (étapes affichées) selon l'état actuel du ViewModel.
    func buildActiveFlowPath() -> [Int] {
        defer { stepForNavigation = nil }

        var path: [Int] = []
        var step = OnboardingStep.genderSelection.rawValue
        var visitCounts: [Int: Int] = [:]

        for _ in 0..<40 {
            let visits = visitCounts[step, default: 0]
            guard visits == 0 else { break }

            visitCounts[step, default: 0] += 1
            path.append(step)
            stepForNavigation = step
            guard let next = getNextStep() else { break }
            step = next
        }

        return path
    }

    func nextStep(after step: Int) -> Int? {
        stepForNavigation = step
        defer { stepForNavigation = nil }
        return getNextStep()
    }

    func resolveNextVisibleStep(from step: Int, maxHops: Int = 40) -> Int? {
        var cursor = step
        for _ in 0..<maxHops {
            guard let rawNext = nextStep(after: cursor) else { return nil }
            cursor = rawNext
            if !OnboardingStep.resolved(from: rawNext).isTransientSkippedStep {
                return rawNext
            }
        }
        return nil
    }

    func getNextStep() -> Int? {
        let current = OnboardingStep.resolved(from: resolvedCurrentStep)

        switch current {
        case .genderSelection:
            return OnboardingStep.ageSelection.rawValue
        case .ageSelection:
            return OnboardingStep.height.rawValue
        case .height:
            return OnboardingStep.weight.rawValue
        case .weight:
            if stepForNavigation == nil {
                viewModel.refreshBodyCompositionRouting()
            }
            return OnboardingStep.firstNameInput.rawValue
        case .firstNameInput:
            return OnboardingStep.faceLeverageIntro.rawValue
        case .faceLeverageIntro:
            return OnboardingStep.weightMotivation.rawValue
        case .weightMotivation:
            return OnboardingStep.dashboardPreview.rawValue
        case .dashboardPreview:
            return OnboardingStep.programCreation.rawValue
        case .programCreation:
            return OnboardingStep.weightEstimation.rawValue
        case .weightEstimation:
            return OnboardingStep.biometricAuth.rawValue
        case .biometricAuth:
            return OnboardingStep.transformationPreview.rawValue
        case .transformationPreview:
            return OnboardingConstants.showsReferralCodeStepInOnboarding
                ? OnboardingStep.referralCode.rawValue
                : OnboardingStep.dreamFaceCommit.rawValue
        case .referralCode:
            return OnboardingStep.dreamFaceCommit.rawValue
        case .dreamFaceCommit:
            return OnboardingStep.payment.rawValue
        case .payment:
            return OnboardingStep.appleSignIn.rawValue
        case .appleSignIn, .complete:
            return nil
        }
    }
}
