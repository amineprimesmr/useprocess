//
//  OnboardingViewChrome.swift
//  Process
//
//  Header onboarding (retour, progression, langue).
//

import SwiftUI

// MARK: - Header (retour, progression, langue)

struct OnboardingHeaderChrome: View {
    @ObservedObject var viewModel: OnboardingViewModel
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
