//
//  OnboardingProgramCreationStepView.swift
//  useprocess
//

import SwiftUI

struct OnboardingProgramCreationStepView: View {
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
                            progresses: creationViewModel.barProgresses,
                            showsSecondBar: creationViewModel.showsSecondProgressBar
                        )
                        .padding(.horizontal, 28)
                    }

                    Spacer(minLength: creationViewModel.activePopup != nil ? 220 : 80)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if creationViewModel.showsContinueButton {
                    VStack {
                        Spacer()
                        continueSection
                            .padding(.horizontal, 34)
                            .padding(.bottom, 50)
                    }
                }

                if let popup = creationViewModel.activePopup {
                    OnboardingAnalysisYesNoPopup(
                        subtitle: "Pour pouvoir continuer, précise",
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
        .preferredColorScheme(.dark)
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

    private var continueSection: some View {
        VStack(spacing: 18) {
            if !creationViewModel.detailMessage.isEmpty {
                Text(creationViewModel.detailMessage)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button {
                HapticManager.shared.impact(.medium)
                creationViewModel.submitContinue()
                onComplete()
            } label: {
                Text("C'est parti")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
