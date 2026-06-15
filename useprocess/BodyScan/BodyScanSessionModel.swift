import AVFoundation
import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class BodyScanSessionModel {
    var phase: BodyScanPhase = .intro
    var captures: [BodyScanCaptureRecord] = []
    var liveFeedback = ScanQualityFeedback(isReady: false, message: "RECULE", score: 0)
    var liveLandmarks: [BodyLandmark] = []
    var turntableProgress: Double = 0
    var turntableTimeRemaining: Int = Int(BodyTurntablePass.scanDuration)
    var mainInstruction: String = "RECULE"
    var capturedAnglesCount: Int = 0
    var isCountdownActive = false

    private var bodyDetectionStreak = 0
    private let scanId = UUID().uuidString
    private var turntableTask: Task<Void, Never>?
    private var turntableStart: Date?
    private var lastCaptureYaw: Double?
    private var lastAutoCaptureTime: Date?
    private var scanUserId: String = ""
    private var scanProfile: UnifiedUserProfile?

    func bindSession(userId: String, profile: UnifiedUserProfile?) {
        scanUserId = userId
        scanProfile = profile
    }

    func startBodyTurntable() {
        BodyScanLiveFrameRouter.shared.reset()
        liveLandmarks = []
        lastCaptureYaw = nil
        lastAutoCaptureTime = nil
        turntableProgress = 0
        turntableTimeRemaining = Int(BodyTurntablePass.scanDuration)
        isCountdownActive = false
        bodyDetectionStreak = 0
        capturedAnglesCount = captures.filter { $0.poseKind == .turntable }.count
        mainInstruction = "RECULE"
        phase = .bodyTurntable(.standard)
        liveFeedback = ScanQualityFeedback(isReady: false, message: "RECULE", score: 0)
    }

    nonisolated func enqueueFrame(_ sampleBuffer: CMSampleBuffer) {
        let frame = SendableSampleBuffer(sampleBuffer)
        BodyScanLiveFrameRouter.shared.process(sampleBuffer: frame.buffer) { analysis in
            Task { @MainActor in
                guard case .bodyTurntable = self.phase else { return }
                self.applyLiveAnalysis(analysis, sampleBuffer: frame.buffer)
            }
        }
    }

    private func applyLiveAnalysis(_ analysis: BodyPoseAnalysis, sampleBuffer: CMSampleBuffer) {
        if !analysis.landmarks.isEmpty {
            liveLandmarks = analysis.landmarks
        }

        let bodyOK = analysis.landmarks.count >= 6 && analysis.feedback.score >= 28

        if bodyOK {
            bodyDetectionStreak += 1
        } else {
            bodyDetectionStreak = 0
        }

        if !isCountdownActive {
            mainInstruction = bodyOK ? "PARFAIT" : "RECULE"
            liveFeedback = ScanQualityFeedback(
                isReady: bodyOK,
                message: bodyOK ? "PRÊT" : "RECULE",
                score: analysis.feedback.score
            )

            if bodyDetectionStreak >= 3 {
                beginCountdown()
            }
            return
        }

        let yaw = BodyYawEstimator.estimateYawDegrees(from: analysis.landmarks)
        mainInstruction = BodyYawEstimator.facingLabel(yaw: yaw)

        if bodyOK {
            tryTurntableCapture(
                sampleBuffer: sampleBuffer,
                landmarks: analysis.landmarks,
                yaw: yaw,
                quality: analysis.feedback.score
            )
            liveFeedback = ScanQualityFeedback(isReady: true, message: "TOURNE", score: analysis.feedback.score)
        } else {
            liveFeedback = ScanQualityFeedback(isReady: false, message: "RECULE", score: analysis.feedback.score)
        }
    }

    private func beginCountdown() {
        guard !isCountdownActive else { return }
        isCountdownActive = true
        turntableStart = Date()
        mainInstruction = "TOURNE"
        HapticManager.shared.impact(.medium)
        startTurntableTimer()
    }

    private func tryTurntableCapture(
        sampleBuffer: CMSampleBuffer,
        landmarks: [BodyLandmark],
        yaw: Double,
        quality: Double
    ) {
        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastAutoCaptureTime ?? .distantPast)
        let yawOK = BodyYawEstimator.shouldCapture(currentYaw: yaw, lastCapturedYaw: lastCaptureYaw, minSeparation: 18)

        guard yawOK || timeSinceLast >= 0.75 else { return }
        guard let image = sampleBufferToImage(sampleBuffer) else { return }

        let path = BodyScanImageStore.save(
            image: image,
            scanId: scanId,
            pose: .turntable,
            suffix: "yaw\(Int(yaw))_\(captures.count)"
        )

        let record = BodyScanCaptureRecord(
            id: UUID().uuidString,
            poseKind: .turntable,
            capturedAt: now,
            qualityScore: quality,
            landmarks: landmarks,
            imagePath: path,
            yawDegrees: yaw,
            armStyle: .atSides
        )

        captures.append(record)
        capturedAnglesCount += 1
        lastCaptureYaw = yaw
        lastAutoCaptureTime = now
        HapticManager.shared.impact(.light)
    }

    private func startTurntableTimer() {
        turntableTask?.cancel()
        turntableTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let start = turntableStart else { continue }
                let elapsed = Date().timeIntervalSince(start)
                let duration = BodyTurntablePass.scanDuration
                turntableProgress = min(1, elapsed / duration)
                turntableTimeRemaining = max(0, Int(ceil(duration - elapsed)))
                if elapsed >= duration {
                    finishTurntableScan()
                    break
                }
            }
        }
    }

    private func stopTurntableTimer() {
        turntableTask?.cancel()
        turntableTask = nil
    }

    private func finishTurntableScan() {
        stopTurntableTimer()
        liveLandmarks = []

        let totalCaptures = captures.filter { $0.poseKind == .turntable }.count
        if totalCaptures < 3 {
            phase = .error("Pas assez d'angles capturés (\(totalCaptures)). Recule à 3 m et réessaie.")
            return
        }

        phase = .analyzing
        Task { @MainActor in
            await analyze(userId: scanUserId, profile: scanProfile)
        }
    }

    func analyze(userId: String, profile: UnifiedUserProfile?) async {
        phase = .analyzing

        let snapshot = captures
        var result = BodyScanLocalAnalyzer.analyze(
            captures: snapshot,
            userId: userId,
            profile: profile
        )

        result = await CoachEngine.enhanceBodyScanReport(result)

        if AppConfiguration.firebaseConfigured, AuthUser.current != nil {
            try? await BodyScanFirestoreRepository.shared.save(result)
        }

        BodyScanHistoryStore.shared.push(result)
        phase = .report(result)
    }

    func reset() {
        stopTurntableTimer()
        captures = []
        liveLandmarks = []
        turntableProgress = 0
        capturedAnglesCount = 0
        isCountdownActive = false
        bodyDetectionStreak = 0
        mainInstruction = "RECULE"
        BodyScanLiveFrameRouter.shared.reset()
        phase = .intro
    }

    private func sampleBufferToImage(_ buffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .leftMirrored)
    }
}

nonisolated private struct SendableSampleBuffer: @unchecked Sendable {
    let buffer: CMSampleBuffer
    init(_ buffer: CMSampleBuffer) { self.buffer = buffer }
}
