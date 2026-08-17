import AVFoundation
import Foundation
import SwiftUI

enum LymphCircuitPhase: Equatable {
    case intro
    case permissions
    case active
    case finished
    case error(String)
}

@MainActor
@Observable
final class LymphCircuitSessionModel {
    var phase: LymphCircuitPhase = .intro
    var steps: [FaceMorningRoutineCatalog.Step] = FaceMorningRoutineCatalog.Step.allCases
    var stepIndex: Int = 0
    var secondsRemaining: Int = 0
    var stepDuration: Int = 0
    var countdownValue: Int? = nil
    var isPaused = false
    var isRunning = false
    var liveLandmarks: [BodyLandmark] = []
    var motion = LymphCircuitMotionCoach.Snapshot(
        intensity: 0,
        isMoving: false,
        bodyVisible: false,
        cue: ""
    )
    var coachingMessage: String = ""
    var completedCarouselIds: Set<String> = []

    private var motionCoach = LymphCircuitMotionCoach()
    private var timerTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var dayId: String = ""
    private var startStep: FaceMorningRoutineCatalog.Step?

    var currentStep: FaceMorningRoutineCatalog.Step? {
        guard steps.indices.contains(stepIndex) else { return nil }
        return steps[stepIndex]
    }

    var progressFraction: Double {
        guard !steps.isEmpty else { return 0 }
        let done = Double(stepIndex) + (1 - stepProgressFraction)
        return min(1, max(0, done / Double(steps.count)))
    }

    var stepProgressFraction: Double {
        guard stepDuration > 0 else { return 0 }
        return Double(secondsRemaining) / Double(stepDuration)
    }

    var stepLabel: String {
        guard !steps.isEmpty else { return "" }
        return "\(min(stepIndex + 1, steps.count)) / \(steps.count)"
    }

    func configure(dayId: String, startAt step: FaceMorningRoutineCatalog.Step? = nil) {
        self.dayId = dayId
        self.startStep = step
        if let step, let index = FaceMorningRoutineCatalog.Step.allCases.firstIndex(of: step) {
            steps = Array(FaceMorningRoutineCatalog.Step.allCases[index...])
        } else {
            steps = FaceMorningRoutineCatalog.Step.allCases
        }
        stepIndex = 0
        completedCarouselIds = []
        phase = .intro
        resetLiveState()
    }

    func beginSession(cameraAuthorized: Bool) {
        guard cameraAuthorized || !needsCameraForRemainingSteps else {
            phase = .permissions
            return
        }
        startActiveFlow()
    }

    var needsCameraForRemainingSteps: Bool {
        steps.contains(where: \.usesLiveCamera)
    }

    func startActiveFlow() {
        BodyScanLiveFrameRouter.shared.reset()
        motionCoach.reset()
        phase = .active
        stepIndex = 0
        beginCurrentStep()
    }

    func togglePause() {
        guard phase == .active, countdownValue == nil else { return }
        isPaused.toggle()
        if isPaused {
            cancelTimers()
        } else if isRunning {
            startExerciseTimer()
        }
    }

    /// Passe à l’étape suivante sans valider.
    func skipStep() {
        guard phase == .active else { return }
        completeCurrentStep(markDone: false)
    }

    /// Valide l’étape courante puis avance.
    func markStepDone() {
        guard phase == .active else { return }
        completeCurrentStep(markDone: true)
    }

    func finishEarly() {
        cancelTimers()
        isRunning = false
        isPaused = false
        phase = completedCarouselIds.isEmpty ? .intro : .finished
    }

    func resetToIntro() {
        cancelTimers()
        resetLiveState()
        stepIndex = 0
        completedCarouselIds = []
        phase = .intro
    }

    nonisolated func enqueueFrame(_ sampleBuffer: CMSampleBuffer) {
        let frame = SendableSampleBuffer(sampleBuffer)
        BodyScanLiveFrameRouter.shared.process(sampleBuffer: frame.buffer) { analysis in
            Task { @MainActor [weak self] in
                self?.applyLiveAnalysis(analysis)
            }
        }
    }

    // MARK: - Step flow

    private func beginCurrentStep() {
        cancelTimers()
        guard let step = currentStep else {
            phase = .finished
            return
        }

        BodyScanLiveFrameRouter.shared.reset()
        motionCoach.reset()
        liveLandmarks = []
        motion = LymphCircuitMotionCoach.Snapshot(
            intensity: 0,
            isMoving: false,
            bodyVisible: false,
            cue: ""
        )
        stepDuration = step.durationSeconds
        secondsRemaining = step.durationSeconds
        isPaused = false
        isRunning = false
        coachingMessage = step.coachingCue

        if step.usesLiveCamera {
            runCountdownThenStart()
        } else {
            isRunning = true
            startExerciseTimer()
        }
    }

    private func runCountdownThenStart() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            for value in [3, 2, 1] {
                guard !Task.isCancelled, phase == .active else { return }
                countdownValue = value
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            guard !Task.isCancelled, phase == .active else { return }
            countdownValue = nil
            isRunning = true
            startExerciseTimer()
        }
    }

    private func startExerciseTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled, phase == .active, isRunning, !isPaused {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, phase == .active, isRunning, !isPaused else { return }
                if secondsRemaining > 1 {
                    secondsRemaining -= 1
                } else {
                    secondsRemaining = 0
                    completeCurrentStep(markDone: true)
                    return
                }
            }
        }
    }

    private func completeCurrentStep(markDone: Bool) {
        cancelTimers()
        isRunning = false
        countdownValue = nil

        if markDone, let step = currentStep {
            completedCarouselIds.insert(step.carouselId)
            WelcomePlanStore.shared.completeDailyRoutineItem(
                carouselItemId: step.carouselId,
                dayId: dayId
            )
        }

        let next = stepIndex + 1
        if next < steps.count {
            stepIndex = next
            beginCurrentStep()
        } else {
            phase = .finished
        }
    }

    private func applyLiveAnalysis(_ analysis: BodyPoseAnalysis) {
        guard phase == .active, let step = currentStep, step.usesLiveCamera else { return }
        if !analysis.landmarks.isEmpty {
            liveLandmarks = analysis.landmarks
        }
        let snapshot = motionCoach.analyze(step: step, landmarks: analysis.landmarks)
        motion = snapshot
        if isRunning, !isPaused {
            coachingMessage = snapshot.cue
        }
    }

    private func cancelTimers() {
        timerTask?.cancel()
        timerTask = nil
        countdownTask?.cancel()
        countdownTask = nil
        countdownValue = nil
    }

    private func resetLiveState() {
        cancelTimers()
        liveLandmarks = []
        motionCoach.reset()
        motion = LymphCircuitMotionCoach.Snapshot(
            intensity: 0,
            isMoving: false,
            bodyVisible: false,
            cue: ""
        )
        coachingMessage = ""
        secondsRemaining = 0
        stepDuration = 0
        isPaused = false
        isRunning = false
    }
}

nonisolated private struct SendableSampleBuffer: @unchecked Sendable {
    let buffer: CMSampleBuffer
    init(_ buffer: CMSampleBuffer) { self.buffer = buffer }
}
