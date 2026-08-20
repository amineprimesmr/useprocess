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

    enum DisplayMode: Equatable {
        case loading
        case success
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var displayMode: DisplayMode = .loading
    @Published private(set) var progressPanelVisible = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var displayedPercentage = 0
    @Published private(set) var barProgresses: [Double] = [0, 0, 0]
    @Published private(set) var visibleBarCount: Int = 1
    @Published var activePopup: OnboardingProgramCreationPopupModel?
    @Published private(set) var continueUnlocked = false
    @Published private(set) var successContentRevealed = false

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
        continueUnlocked && displayMode == .success
    }

    func bind(
        _ viewModel: OnboardingViewModel,
        healthManager: HealthManager,
        permissionsManager: PermissionsManager
    ) {
        onboardingViewModel = viewModel
        self.healthManager = healthManager
        self.permissionsManager = permissionsManager
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        beginProgressPanel()
        startProgressAnimation()
    }

    /// Reprise après kill — ne pas relancer l'animation si déjà terminée.
    func restoreCompletedPresentationIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        phase = .complete
        displayMode = .success
        progressPanelVisible = true
        progress = 1
        displayedPercentage = 100
        barProgresses = Array(repeating: 1, count: progressBarLabels.count)
        visibleBarCount = progressBarLabels.count
        continueUnlocked = true
        successContentRevealed = true
    }

    func handlePopupAnswer(_ answer: Bool) {
        guard popupPhaseIndex >= 0, let popupKind = activePopup?.kind else { return }

        let page = ProcessAnalytics.MossPage.programCreationPopup(kind: popupKind)
        ProcessAnalytics.trackMossAction(
            page: page,
            action: answer ? "accepted" : "declined",
            answerID: answer ? "yes" : "no",
            answerDisplay: answer ? activePopup?.affirmativeTitle : activePopup?.negativeTitle,
            extra: ["popup_kind": popupKind == .healthKit ? "healthkit" : "yes_no", "phase_index": popupPhaseIndex]
        )

        activePopup = nil

        // HealthKit: keep progress paused until the system sheet finishes.
        // Otherwise bar 2 starts while the permission dialog is still open.
        if popupKind == .healthKit {
            Task { @MainActor in
                await handleHealthKitPopupAnswer(answer)
                isPaused = false
                popupPhaseIndex = -1
            }
            return
        }

        isPaused = false
        popupPhaseIndex = -1
    }

    func submitContinue() {
        guard continueUnlocked else { return }
        ProcessAnalytics.trackMossAction(page: .programCreationSuccess, action: "continued")
        onboardingViewModel?.isProgramCreationCompleted = true
    }

    func cancel() {
        if phase == .running || activePopup != nil {
            ProcessAnalytics.trackMossAction(
                page: .programCreationPhaseHealth,
                action: "abandoned",
                extra: [
                    "progress_pct": displayedPercentage,
                    "had_popup": activePopup != nil
                ]
            )
        }
        progressTask?.cancel()
        progressTask = nil
        isPaused = false
        activePopup = nil
        popupPhaseIndex = -1
    }

    private func beginProgressPanel() {
        phase = .running
        displayMode = .loading
        progress = 0
        displayedPercentage = 0
        barProgresses = Array(repeating: 0, count: phaseCount)
        visibleBarCount = 1
        progressPanelVisible = true
        isPaused = false
        activePopup = nil
        popupPhaseIndex = -1
        continueUnlocked = false
        successContentRevealed = false
    }

    private func startProgressAnimation() {
        progressTask?.cancel()

        let phases = OnboardingAnalysisProgressConfig.phases

        progressTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: OnboardingAnalysisProgressConfig.programCreationStartDelayNs)
            guard !Task.isCancelled else { return }

            for index in 0..<phases.count {
                guard !Task.isCancelled else { return }

                if let page = ProcessAnalytics.MossPage.programCreationPhase(index: index) {
                    ProcessAnalytics.trackMossPageViewed(page)
                }

                await animatePhaseIrregularly(index: index, phasesCount: phases.count)

                if index == phases.count - 1 {
                    guard !Task.isCancelled else { return }
                    await revealSuccessScreen()
                    return
                }

                await presentPhaseEndPopupIfNeeded(phaseIndex: index)
                try? await waitWhilePaused()
                guard !Task.isCancelled else { return }
            }
        }
    }

    private func animatePhaseIrregularly(index: Int, phasesCount: Int) async {
        visibleBarCount = index + 1
        HapticManager.shared.impact(.medium)
        let milestones = Self.irregularMilestones(forPhase: index)

        for (stepIndex, milestone) in milestones.enumerated() {
            try? await waitWhilePaused()
            guard !Task.isCancelled else { return }

            try? await Task.sleep(nanoseconds: milestone.delayNs)

            withAnimation(.easeInOut(duration: milestone.animationDuration)) {
                applyProgress(
                    phaseIndex: index,
                    segmentProgress: milestone.value,
                    phasesCount: phasesCount
                )
            }

            fireProgressHaptic(stepIndex: stepIndex, value: milestone.value)
        }
    }

    private func revealSuccessScreen() async {
        HapticManager.shared.impact(.heavy)
        HapticManager.shared.notification(.success)
        progress = 1
        displayedPercentage = 100
        barProgresses = Array(repeating: 1, count: phaseCount)
        visibleBarCount = phaseCount
        phase = .complete
        ProcessAnalytics.trackMossPageViewed(.programCreationSuccess)

        try? await Task.sleep(nanoseconds: 200_000_000)
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
            progressPanelVisible = false
            displayMode = .success
        }

        try? await Task.sleep(nanoseconds: 100_000_000)
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
            successContentRevealed = true
            continueUnlocked = true
        }

        HapticManager.shared.impact(.medium)
    }

    private func waitWhilePaused() async throws {
        while isPaused {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled { return }
        }
    }

    private func presentPhaseEndPopupIfNeeded(phaseIndex: Int) async {
        guard let popup = OnboardingAnalysisProgressConfig.phaseEndPopup(for: phaseIndex) else { return }
        await presentPopup(popup, phaseIndex: phaseIndex)
    }

    private func presentPopup(_ popup: OnboardingAnalysisProgressConfig.Popup, phaseIndex: Int) async {
        if popup.kind == .healthKit, healthManager?.isAuthorized == true {
            return
        }

        popupPhaseIndex = phaseIndex
        isPaused = true

        let mossPage = ProcessAnalytics.MossPage.programCreationPopup(kind: popup.kind)
        ProcessAnalytics.trackMossPageViewed(
            mossPage,
            extra: [
                "popup_kind": popup.kind == .healthKit ? "healthkit" : "yes_no",
                "phase_index": phaseIndex
            ]
        )

        if popup.kind == .healthKit {
            ProcessAnalytics.trackHealthKitPromptShown(source: "onboarding_program_creation")
        }

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

    private func fireProgressHaptic(stepIndex: Int, value: Double) {
        if value >= 0.999 {
            HapticManager.shared.impact(.heavy)
            return
        }
        if stepIndex % 3 == 0 {
            HapticManager.shared.impact(.medium)
            return
        }
        HapticManager.shared.impact(.light)
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
        guard let healthManager else { return }

        if answer {
            // Wait for the system sheets only — sync runs after progress resumes
            // so bar 2 isn't blocked behind a long HealthKit import.
            await healthManager.requestAuthorizationAsync(
                syncAfterwards: false,
                analyticsSource: "onboarding_program_creation"
            )
            if let permissionsManager {
                _ = await permissionsManager.requestMotionPermission()
            }
            HapticManager.shared.notification(.success)
            Task { await healthManager.performFullSync() }
        } else {
            ProcessAnalytics.trackHealthKitSkipped(source: "onboarding_program_creation")
        }
    }
}

// MARK: - Irregular progress curves

private extension OnboardingProgramCreationViewModel {
    struct ProgressMilestone {
        let value: Double
        let delayNs: UInt64
        let animationDuration: Double
    }

    static func irregularMilestones(forPhase phase: Int) -> [ProgressMilestone] {
        let stepCount = 13 + phase
        var milestones: [ProgressMilestone] = []

        for step in 1...stepCount {
            let normalized = Double(step) / Double(stepCount)
            let eased = easeInOutIrregular(normalized, phaseSeed: phase)
            let previous = milestones.last?.value ?? 0
            let value = max(previous, min(1, eased))

            let baseDelay = UInt64.random(in: 88_000_000...150_000_000)
            let stallMultiplier: UInt64 = (step % 7 == 0) ? 2 : 1
            let delayNs = baseDelay * stallMultiplier
            let animationDuration = Double.random(in: 0.34...0.54)

            milestones.append(
                ProgressMilestone(
                    value: value,
                    delayNs: delayNs,
                    animationDuration: animationDuration
                )
            )
        }

        milestones.append(
            ProgressMilestone(
                value: 1,
                delayNs: 200_000_000,
                animationDuration: 0.40
            )
        )

        return milestones
    }

    static func easeInOutIrregular(_ t: Double, phaseSeed: Int) -> Double {
        let seed = Double(phaseSeed + 1)
        let base = t < 0.5
            ? 2 * t * t
            : 1 - pow(-2 * t + 2, 2) / 2
        let wave = sin(t * .pi * (1.8 + seed * 0.2)) * 0.018
        return min(1, max(0, base + wave))
    }
}
