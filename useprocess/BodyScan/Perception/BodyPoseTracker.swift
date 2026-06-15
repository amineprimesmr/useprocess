import AVFoundation
import Foundation
import UIKit
import Vision

/// Pipeline Vision temps réel — pose 2D alignée sur l'aperçu selfie.
nonisolated final class BodyPoseTracker: @unchecked Sendable {

    private let visionQueue = DispatchQueue(label: "com.useprocess.bodyscan.vision", qos: .userInteractive)
    private let liveSmoother = LandmarkSmoother(liveMode: true)
    private let captureSmoother = LandmarkSmoother(liveMode: false)
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let sequenceHandler = VNSequenceRequestHandler()
    private let faceRequest = VNDetectFaceRectanglesRequest()

    private var lastLiveProcessedAt: CFAbsoluteTime = 0
    private let liveFrameInterval: CFAbsoluteTime = 1.0 / 60.0
    private var lastSegmentationCoverage: Double = 0
    private var segmentationCounter = 0

    nonisolated func reset() {
        liveSmoother.reset()
        captureSmoother.reset()
        lastSegmentationCoverage = 0
        segmentationCounter = 0
    }

    /// Analyse live — callback sur le main thread. Pas de segmentation (latence minimale).
    nonisolated func processLiveFrame(
        sampleBuffer: CMSampleBuffer,
        cameraPosition: AVCaptureDevice.Position = .front,
        onResult: @escaping @Sendable (BodyPoseAnalysis) -> Void
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastLiveProcessedAt >= liveFrameInterval else { return }
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }
        lastLiveProcessedAt = now

        let orientation = visionOrientation(for: cameraPosition)
        let frame = SampleBufferBox(sampleBuffer)

        visionQueue.async { [weak self, orientation] in
            guard let self,
                  let rawBuffer = CMSampleBufferGetImageBuffer(frame.buffer) else { return }

            let result = self.performLiveAnalysis(
                pixelBuffer: rawBuffer,
                orientation: orientation
            )

            DispatchQueue.main.async {
                onResult(result)
            }
        }
    }

    /// Analyse complète (captures + segmentation) — async.
    nonisolated func analyze(
        sampleBuffer: CMSampleBuffer,
        cameraPosition: AVCaptureDevice.Position,
        targetPose: ScanPoseKind
    ) async -> BodyPoseAnalysis? {
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return nil }
        let orientation = visionOrientation(for: cameraPosition)
        let frame = SampleBufferBox(sampleBuffer)
        let pose = targetPose

        return await withCheckedContinuation { continuation in
            visionQueue.async { [weak self, orientation, pose] in
                guard let self,
                      let pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer) else {
                    continuation.resume(returning: nil)
                    return
                }
                let result = self.performFullAnalysis(
                    pixelBuffer: pixelBuffer,
                    orientation: orientation,
                    targetPose: pose
                )
                continuation.resume(returning: result)
            }
        }
    }

    nonisolated func landmarksFromImage(_ image: UIImage) -> [BodyLandmark] {
        guard let cgImage = image.visionReadyCGImage() else { return [] }
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.visionOrientation)
        try? handler.perform([request])
        guard let observation = request.results?.first else { return [] }
        return Self.landmarks(from: observation, minConfidence: 0.2)
    }

    // MARK: - Pipeline

    private func performLiveAnalysis(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> BodyPoseAnalysis {
        var landmarks: [BodyLandmark] = []
        var humanDetected = false

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try? handler.perform([request])

        if let observation = request.results?.first {
            landmarks = Self.landmarks(from: observation, minConfidence: 0.2)
            humanDetected = landmarks.count >= 3
        }

        let poseMatch = PoseAlignmentValidator.matchScore(landmarks: landmarks, pose: .turntable)
        let feedback = VisionPoseExtractor.evaluateCaptureQuality(
            landmarks: landmarks,
            pose: .turntable,
            humanDetected: humanDetected,
            segmentationCoverage: 0,
            poseMatchScore: poseMatch
        )

        return BodyPoseAnalysis(
            landmarks: landmarks,
            segmentationCoverage: 0,
            humanDetected: humanDetected,
            poseMatchScore: poseMatch,
            feedback: feedback
        )
    }

    private func performFullAnalysis(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        targetPose: ScanPoseKind
    ) -> BodyPoseAnalysis {
        var landmarks: [BodyLandmark] = []
        var humanDetected = false

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try? handler.perform([request])

        if let observation = request.results?.first {
            landmarks = Self.landmarks(from: observation, minConfidence: 0.25)
            landmarks = Self.sanitize(landmarks)
            landmarks = captureSmoother.apply(landmarks)
            humanDetected = landmarks.count >= 3
        }

        segmentationCounter += 1
        var coverage = lastSegmentationCoverage
        if segmentationCounter % 6 == 0 {
            coverage = segmentationCoverage(pixelBuffer: pixelBuffer, orientation: orientation)
            lastSegmentationCoverage = coverage
        }
        if coverage > 0.1 { humanDetected = true }

        if targetPose.isFacePose {
            humanDetected = humanDetected || detectFace(pixelBuffer: pixelBuffer, orientation: orientation)
        }

        let poseMatch = PoseAlignmentValidator.matchScore(landmarks: landmarks, pose: targetPose)
        let feedback = VisionPoseExtractor.evaluateCaptureQuality(
            landmarks: landmarks,
            pose: targetPose,
            humanDetected: humanDetected,
            segmentationCoverage: coverage,
            poseMatchScore: poseMatch
        )

        return BodyPoseAnalysis(
            landmarks: landmarks,
            segmentationCoverage: coverage,
            humanDetected: humanDetected,
            poseMatchScore: poseMatch,
            feedback: feedback
        )
    }

    private static func sanitize(_ landmarks: [BodyLandmark]) -> [BodyLandmark] {
        guard landmarks.count >= 2 else { return landmarks }

        func dist(_ a: BodyLandmark, _ b: BodyLandmark) -> Double {
            hypot(a.x - b.x, a.y - b.y)
        }

        var map = Dictionary(uniqueKeysWithValues: landmarks.map { ($0.name, $0) })
        let maxBone = 0.55

        let bonePairs: [(String, String)] = [
            ("nose", "neck"), ("neck", "root"),
            ("left_shoulder", "left_elbow"), ("left_elbow", "left_wrist"),
            ("right_shoulder", "right_elbow"), ("right_elbow", "right_wrist"),
            ("left_hip", "left_knee"), ("left_knee", "left_ankle"),
            ("right_hip", "right_knee"), ("right_knee", "right_ankle")
        ]

        for (a, b) in bonePairs {
            guard let pa = map[a], let pb = map[b] else { continue }
            if dist(pa, pb) > maxBone {
                if pa.confidence < pb.confidence {
                    map.removeValue(forKey: a)
                } else {
                    map.removeValue(forKey: b)
                }
            }
        }

        return Array(map.values)
    }

    private func segmentationCoverage(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> Double {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .fast
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        try? handler.perform([request])
        guard let mask = request.results?.first?.pixelBuffer else { return lastSegmentationCoverage }

        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(mask) else { return lastSegmentationCoverage }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        let step = 4
        var personPixels = 0
        var sampled = 0

        for y in stride(from: 0, to: height, by: step) {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in stride(from: 0, to: width, by: step) {
                sampled += 1
                if row[x] > 127 { personPixels += 1 }
            }
        }

        guard sampled > 0 else { return lastSegmentationCoverage }
        return Double(personPixels) / Double(sampled)
    }

    private func detectFace(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> Bool {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        try? handler.perform([faceRequest])
        return !(faceRequest.results?.isEmpty ?? true)
    }

    /// Buffer brut + rotation 90° ; l'aperçu preview applique le miroir selfie via `layerPointConverted`.
    private func visionOrientation(for position: AVCaptureDevice.Position) -> CGImagePropertyOrientation {
        position == .front ? .left : .right
    }

    static func landmarks(from observation: VNHumanBodyPoseObservation, minConfidence: Float) -> [BodyLandmark] {
        BodySkeletonTopology.jointNames.compactMap { joint in
            guard let point = try? observation.recognizedPoint(joint),
                  point.confidence >= minConfidence else { return nil }
            return BodyLandmark(
                name: jointKey(joint),
                x: Double(point.location.x),
                y: Double(point.location.y),
                confidence: Double(point.confidence)
            )
        }
    }

    static func jointKey(_ joint: VNHumanBodyPoseObservation.JointName) -> String {
        if joint == .nose { return "nose" }
        if joint == .neck { return "neck" }
        if joint == .leftEye { return "left_eye" }
        if joint == .rightEye { return "right_eye" }
        if joint == .leftEar { return "left_ear" }
        if joint == .rightEar { return "right_ear" }
        if joint == .leftShoulder { return "left_shoulder" }
        if joint == .rightShoulder { return "right_shoulder" }
        if joint == .leftElbow { return "left_elbow" }
        if joint == .rightElbow { return "right_elbow" }
        if joint == .leftWrist { return "left_wrist" }
        if joint == .rightWrist { return "right_wrist" }
        if joint == .root { return "root" }
        if joint == .leftHip { return "left_hip" }
        if joint == .rightHip { return "right_hip" }
        if joint == .leftKnee { return "left_knee" }
        if joint == .rightKnee { return "right_knee" }
        if joint == .leftAnkle { return "left_ankle" }
        if joint == .rightAnkle { return "right_ankle" }
        return String(describing: joint)
    }
}

/// Encapsule un buffer caméra pour le passage entre queues (Swift 6).
nonisolated private struct SampleBufferBox: @unchecked Sendable {
    let buffer: CMSampleBuffer
    init(_ buffer: CMSampleBuffer) { self.buffer = buffer }
}

// MARK: - Validation de pose

nonisolated enum PoseAlignmentValidator {

    static func matchScore(landmarks: [BodyLandmark], pose: ScanPoseKind) -> Double {
        guard landmarks.count >= 4 else { return 0 }

        func point(_ name: String) -> BodyLandmark? {
            landmarks.first { $0.name == name && $0.confidence >= 0.25 }
        }

        switch pose {
        case .frontStanding, .backStanding:
            return frontalScore(point: point)

        case .leftProfile:
            return profileScore(point: point, facingLeft: true)

        case .rightProfile:
            return profileScore(point: point, facingLeft: false)

        case .frontArmsRaised:
            let base = frontalScore(point: point)
            guard let lw = point("left_wrist"), let rw = point("right_wrist"),
                  let ls = point("left_shoulder"), let rs = point("right_shoulder") else { return base * 0.5 }
            let armsUp = lw.y > ls.y && rw.y > rs.y
            return armsUp ? min(1, base + 0.25) : base * 0.6

        case .faceFront, .faceLeft, .faceRight, .faceMesh:
            return point("nose") != nil ? 0.85 : 0.4

        case .turntable:
            return frontalScore(point: point)
        }
    }

    private static func frontalScore(point: (String) -> BodyLandmark?) -> Double {
        guard let ls = point("left_shoulder"), let rs = point("right_shoulder") else { return 0.3 }
        let shoulderLevel = abs(ls.y - rs.y) < 0.12
        let hasHips = point("left_hip") != nil || point("root") != nil
        let hasAnkles = point("left_ankle") != nil && point("right_ankle") != nil
        var score = shoulderLevel ? 0.4 : 0.2
        if hasHips { score += 0.25 }
        if hasAnkles { score += 0.25 }
        return min(1, score)
    }

    private static func profileScore(point: (String) -> BodyLandmark?, facingLeft: Bool) -> Double {
        guard let ls = point("left_shoulder"), let rs = point("right_shoulder") else { return 0.25 }
        let shoulderSpan = abs(ls.x - rs.x)
        let isProfile = shoulderSpan < 0.14
        let facingOK = facingLeft ? (ls.x < rs.x) : (rs.x < ls.x)
        if isProfile && facingOK { return 0.9 }
        if isProfile { return 0.7 }
        return 0.35
    }
}
