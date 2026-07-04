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
                    .foregroundStyle(OnboardingTheme.bodyText)
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
                    .foregroundStyle(OnboardingTheme.filledButtonText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(OnboardingTheme.filledButtonBackground(for: colorScheme))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
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
