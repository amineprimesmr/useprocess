//
//  OnboardingViewChrome.swift
//  Process
//
//  Header onboarding (retour, progression, langue).
//

import SwiftUI

// MARK: - Header (retour, progression, langue)

struct OnboardingHeaderChrome: View {
    let currentStep: Int
    var shouldShowBackButton: Bool
    var flowProgress: Double
    var chatSegmentedProgress: OnboardingProfileChatCoachHeaderProgress.Snapshot? = nil
    var onPreviousStep: () -> Void

    var body: some View {
        headerContent
    }

    @ViewBuilder
    private var headerContent: some View {
        let showsProgressAndLanguage = OnboardingHeaderLayout.showsProgressAndLanguage(
            currentStep: currentStep
        )
        let showsBack = OnboardingHeaderLayout.showsBackOnly(
            currentStep: currentStep,
            shouldShowBackButton: shouldShowBackButton
        )

        if showsProgressAndLanguage || showsBack {
            onboardingHeaderBar(showsProgressAndLanguage: showsProgressAndLanguage)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func onboardingHeaderBar(showsProgressAndLanguage: Bool) -> some View {
        HStack(spacing: 16) {
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
                    .frame(height: 5)

                LanguageSelectorView()
            } else if let chatSegmentedProgress {
                OnboardingSegmentedProgressBar(
                    segmentCount: chatSegmentedProgress.segmentCount,
                    completedSegments: chatSegmentedProgress.completedSegments,
                    activeSegmentProgress: chatSegmentedProgress.activeProgress,
                    height: 5
                )
                .frame(maxWidth: .infinity)
                .frame(height: 5)
            } else {
                Spacer(minLength: 0)
                if OnboardingStep(rawValue: currentStep) == .faceLeverageIntro {
                    LanguageSelectorView()
                }
            }
        }
        .padding(.horizontal, OnboardingConstants.headerHorizontalPadding)
        .frame(height: OnboardingConstants.backButtonSize, alignment: .center)
        .padding(.top, OnboardingConstants.headerBackButtonTopPadding)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
