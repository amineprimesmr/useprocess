//
//  OnboardingProgramCreationStepView.swift
//  useprocess
//

import SwiftUI

struct OnboardingProgramCreationStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var permissionsManager: PermissionsManager

    var onComplete: () -> Void
    var onBack: (() -> Void)?

    @StateObject private var creationViewModel = OnboardingProgramCreationViewModel()

    init(
        viewModel: OnboardingViewModel,
        onComplete: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                OnboardingProgramCreationBackground(progress: creationViewModel.progress)

                if creationViewModel.displayMode == .success {
                    OnboardingProgramCreationConfettiView(isActive: creationViewModel.successContentRevealed)
                        .ignoresSafeArea()
                }

                if creationViewModel.displayMode == .loading {
                    loadingContent(geometry: geometry)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                if creationViewModel.displayMode == .success {
                    OnboardingProgramCreationSuccessView(
                        isRevealed: creationViewModel.successContentRevealed
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if creationViewModel.showsContinueButton {
                    VStack {
                        Spacer()
                        OnboardingProgramCreationSuccessFooter(
                            isRevealed: creationViewModel.successContentRevealed,
                            onContinue: handleContinue
                        )
                        .padding(.horizontal, 34)
                        .padding(.bottom, 34)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let popup = creationViewModel.activePopup {
                    OnboardingAnalysisYesNoPopup(
                        subtitle: popupSubtitle(for: popup.kind),
                        headerImageName: popup.kind == .healthKit ? "healthapple" : nil,
                        question: popup.question,
                        affirmativeTitle: popup.affirmativeTitle,
                        negativeTitle: popup.negativeTitle,
                        onAnswer: { creationViewModel.handlePopupAnswer($0) }
                    )
                    .zIndex(100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.62, dampingFraction: 0.84), value: creationViewModel.displayMode)
        .task {
            viewModel.isProgramCreationCompleted = false
            creationViewModel.bind(
                viewModel,
                healthManager: healthManager,
                permissionsManager: permissionsManager
            )
            creationViewModel.startIfNeeded()
        }
        .onDisappear {
            creationViewModel.cancel()
        }
    }

    @ViewBuilder
    private func loadingContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: OnboardingConstants.backOnlyContentTopInset + 4)

            OnboardingProgramCreationHeroPercentage(value: creationViewModel.displayedPercentage)

            Text("Création du programme")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(OnboardingProgramCreationPalette.subtitle)
                .padding(.top, 10)

            Spacer()
                .frame(height: max(28, geometry.size.height * 0.06))

            OnboardingProgramCreationBadge(style: creationViewModel.badgeStyle)
                .animation(.spring(response: 0.55, dampingFraction: 0.86), value: creationViewModel.badgeStyle)

            Spacer()
                .frame(height: max(32, geometry.size.height * 0.07))

            if creationViewModel.progressPanelVisible {
                OnboardingProgramCreationProgressBars(
                    labels: creationViewModel.progressBarLabels,
                    progresses: creationViewModel.barProgresses
                )
                .padding(.horizontal, 28)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer(minLength: creationViewModel.activePopup != nil ? 220 : 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func handleContinue() {
        HapticManager.shared.impact(.medium)
        creationViewModel.submitContinue()
        onComplete()
    }

    private func popupSubtitle(for kind: OnboardingAnalysisProgressConfig.PopupKind) -> String? {
        switch kind {
        case .healthKit:
            return "Pour calibrer ton plan personnalisé"
        case .yesNo:
            return "Pour pouvoir continuer, précise"
        }
    }
}
