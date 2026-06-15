import AVFoundation
import Foundation

/// Route les frames caméra vers Vision hors du MainActor (Swift 6).
nonisolated final class BodyScanLiveFrameRouter: @unchecked Sendable {

    static let shared = BodyScanLiveFrameRouter()

    private let tracker = BodyPoseTracker()

    private init() {}

    nonisolated func reset() {
        tracker.reset()
    }

    nonisolated func process(
        sampleBuffer: CMSampleBuffer,
        onResult: @escaping @Sendable (BodyPoseAnalysis) -> Void
    ) {
        tracker.processLiveFrame(sampleBuffer: sampleBuffer, cameraPosition: .front, onResult: onResult)
    }
}
