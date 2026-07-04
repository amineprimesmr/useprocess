//
//  OnboardingProgramCreationViewModel.swift
//  useprocess
//

import Combine
import Foundation
import SwiftUI

struct OnboardingProgramCreationPopupModel: Equatable {
    let question: String
    let affirmativeTitle: String
    let negativeTitle: String
    let kind: OnboardingAnalysisProgressConfig.PopupKind
    let phaseIndex: Int
}

@MainActor
final class OnboardingProgramCreationViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case running
        case complete
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var progressPanelVisible = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var displayedPercentage = 0
    @Published private(set) var barProgresses: [Double] = [0, 0, 0]
    @Published var activePopup: OnboardingProgramCreationPopupModel?
    @Published private(set) var continueUnlocked = false
    @Published private(set) var detailMessage = ""

    private var popupPhaseIndex = -1
    private var isPaused = false
    private var hasStarted = false

    private var onboardingViewModel: OnboardingViewModel?
    private var healthManager: HealthManager?
    private var permissionsManager: PermissionsManager?
    private var progressTask: Task<Void, Never>?

    private var phaseCount: Int {
        OnboardingAnalysisProgressConfig.phases.count
    }

    var progressBarLabels: [String] {
        OnboardingAnalysisProgressConfig.progressBarLabels
    }

    var badgeStyle: OnboardingProgramCreationBadge.Style {
        if displayedPercentage >= 72 {
            return .download
        }
        if displayedPercentage >= 58 {
            return .programsGenerated
        }
        return .scienceApproved
    }

    var showsContinueButton: Bool {
        continueUnlocked
    }

    func bind(
        _ viewModel: OnboardingViewModel,
        healthManager: HealthManager,
        permissionsManager: PermissionsManager
    ) {
        onboardingViewModel = viewModel
        self.healthManager = healthManager
        self.permissionsManager = permissionsManager

        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            detailMessage = "\(trimmed), tout est prêt. On prépare ton plan sur mesure."
        } else {
            detailMessage = "Tout est prêt. On prépare ton plan sur mesure."
        }
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        beginProgressPanel()
        startProgressAnimation()
    }

    func handlePopupAnswer(_ answer: Bool) {
        guard popupPhaseIndex >= 0 else { return }

        let kind = OnboardingAnalysisProgressConfig.popups[popupPhaseIndex].kind
        let popupIndex = popupPhaseIndex

        isPaused = false
        activePopup = nil
        popupPhaseIndex = -1

        Task { @MainActor in
            if kind == .healthKit {
                await handleHealthKitPopupAnswer(answer)
            }

            guard popupIndex < phaseCount else { return }

            let nextProgress = Double(popupIndex + 1) / Double(phaseCount)
            let percentagePerPhase = 100.0 / Double(phaseCount)
            let nextPercentage = min(Int((Double(popupIndex + 1) * percentagePerPhase).rounded()), 100)

            withAnimation(.easeInOut(duration: 0.45)) {
                progress = nextProgress
                displayedPercentage = nextPercentage
                syncBarProgresses(phaseIndex: popupIndex, segmentProgress: 0, phasesCount: phaseCount)
            }
        }
    }

    func submitContinue() {
        guard continueUnlocked else { return }
        onboardingViewModel?.isProgramCreationCompleted = true
    }

    func cancel() {
        progressTask?.cancel()
        progressTask = nil
        isPaused = false
        activePopup = nil
        popupPhaseIndex = -1
    }

    private func beginProgressPanel() {
        phase = .running
        progress = 0
        displayedPercentage = 0
        barProgresses = Array(repeating: 0, count: phaseCount)
        progressPanelVisible = true
        isPaused = false
        activePopup = nil
        popupPhaseIndex = -1
        continueUnlocked = false
    }

    private func startProgressAnimation() {
        progressTask?.cancel()

        let phases = OnboardingAnalysisProgressConfig.phases
        let popups = OnboardingAnalysisProgressConfig.popups
        let tickInterval = OnboardingAnalysisProgressConfig.programCreationTickIntervalNs
        let segmentStep = OnboardingAnalysisProgressConfig.programCreationSegmentStep

        progressTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: OnboardingAnalysisProgressConfig.programCreationStartDelayNs)
            guard !Task.isCancelled else { return }

            for index in 0..<phases.count {
                guard !Task.isCancelled else { return }

                applyProgress(phaseIndex: index, segmentProgress: 0, phasesCount: phases.count)
                await presentPopup(popups[index], phaseIndex: index)

                try? await waitWhilePaused()
                guard !Task.isCancelled else { return }

                var segmentProgress = 0.0
                while segmentProgress < 1.0 {
                    try? await waitWhilePaused()
                    guard !Task.isCancelled else { return }

                    try? await Task.sleep(nanoseconds: tickInterval)
                    segmentProgress += segmentStep
                    applyProgress(phaseIndex: index, segmentProgress: segmentProgress, phasesCount: phases.count)
                }
            }

            guard !Task.isCancelled else { return }
            HapticManager.shared.notification(.success)
            progress = 1
            displayedPercentage = 100
            barProgresses = Array(repeating: 1, count: phaseCount)
            phase = .complete

            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                continueUnlocked = true
            }
        }
    }

    private func waitWhilePaused() async throws {
        while isPaused {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled { return }
        }
    }

    private func presentPopup(_ popup: OnboardingAnalysisProgressConfig.Popup, phaseIndex: Int) async {
        if popup.kind == .healthKit, healthManager?.isAuthorized == true {
            popupPhaseIndex = phaseIndex
            onboardingViewModel?.healthKitGranted = true
            return
        }

        popupPhaseIndex = phaseIndex
        isPaused = true

        withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) {
            activePopup = OnboardingProgramCreationPopupModel(
                question: popup.question,
                affirmativeTitle: popup.affirmativeTitle,
                negativeTitle: popup.negativeTitle,
                kind: popup.kind,
                phaseIndex: phaseIndex
            )
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    private func applyProgress(phaseIndex: Int, segmentProgress: Double, phasesCount: Int) {
        let total = (Double(phaseIndex) + segmentProgress) / Double(phasesCount)
        let percentagePerPhase = 100.0 / Double(phasesCount)
        let rawPercentage = Int((Double(phaseIndex) * percentagePerPhase + segmentProgress * percentagePerPhase).rounded())

        progress = total
        if phaseIndex == phasesCount - 1 && segmentProgress >= 1.0 {
            displayedPercentage = 100
            progress = 1
            barProgresses = Array(repeating: 1, count: phasesCount)
        } else {
            displayedPercentage = min(rawPercentage, 99)
            syncBarProgresses(phaseIndex: phaseIndex, segmentProgress: segmentProgress, phasesCount: phasesCount)
        }
    }

    private func syncBarProgresses(phaseIndex: Int, segmentProgress: Double, phasesCount: Int) {
        var bars = Array(repeating: 0.0, count: phasesCount)
        for index in 0..<phaseIndex {
            bars[index] = 1
        }
        if phaseIndex < phasesCount {
            bars[phaseIndex] = min(1, segmentProgress)
        }
        barProgresses = bars
    }

    private func handleHealthKitPopupAnswer(_ answer: Bool) async {
        guard let healthManager, let onboardingViewModel else { return }

        onboardingViewModel.isRequestingHealthKit = true

        if answer {
            await healthManager.requestAuthorizationAsync()
            if let permissionsManager {
                _ = await permissionsManager.requestMotionPermission()
            }
            HapticManager.shared.notification(.success)
        }

        onboardingViewModel.healthKitGranted = healthManager.isAuthorized
        onboardingViewModel.isRequestingHealthKit = false
    }
}
