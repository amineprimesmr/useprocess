import ARKit
import AVFoundation
import CoreVideo

/// Enregistre la caméra AR (TrueDepth) pendant le scan — stockage local uniquement.
final class FaceScanVideoRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var sessionStarted = false
    private var firstTimestamp: TimeInterval?
    private var lastAppendedFrameIndex = -1
    private let queue = DispatchQueue(label: "process.facescan.video", qos: .userInitiated)
    private let targetFPS: Double = 15

    var isRecording: Bool { assetWriter != nil }

    func prepareOutputURL(scanId: String) -> URL {
        FaceScanImageStore.videoURL(for: scanId)
    }

    func start(at url: URL) {
        cancel()
        outputURL = url
        try? FileManager.default.removeItem(at: url)
    }

    func append(frame: ARFrame) {
        queue.async { [weak self] in
            self?.appendLocked(frame: frame)
        }
    }

    func finish() async -> URL? {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                continuation.resume(returning: self?.finishLocked())
            }
        }
    }

    func cancel() {
        queue.sync {
            assetWriter?.cancelWriting()
            if let url = outputURL {
                try? FileManager.default.removeItem(at: url)
            }
            cleanup()
        }
    }

    // MARK: - Private

    private func appendLocked(frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        if assetWriter == nil {
            guard let url = outputURL else { return }
            guard startWriter(at: url, pixelBuffer: pixelBuffer) else { return }
        }

        guard let writer = assetWriter, let input = videoInput, let adaptor else { return }
        guard writer.status == .writing else { return }
        guard input.isReadyForMoreMediaData else { return }

        if firstTimestamp == nil {
            firstTimestamp = frame.timestamp
            writer.startSession(atSourceTime: .zero)
            sessionStarted = true
        }

        guard sessionStarted else { return }

        let elapsed = frame.timestamp - (firstTimestamp ?? frame.timestamp)
        let frameIndex = Int(elapsed * targetFPS)
        guard frameIndex > lastAppendedFrameIndex else { return }
        lastAppendedFrameIndex = frameIndex

        let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(targetFPS))
        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }

    private func startWriter(at url: URL, pixelBuffer: CVPixelBuffer) -> Bool {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 1_200_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            input.transform = CGAffineTransform(rotationAngle: .pi / 2)

            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
            let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: attributes
            )

            guard writer.canAdd(input) else { return false }
            writer.add(input)
            guard writer.startWriting() else { return false }

            assetWriter = writer
            videoInput = input
            adaptor = pixelAdaptor
            return true
        } catch {
            return false
        }
    }

    private func finishLocked() -> URL? {
        defer { cleanup() }
        guard let writer = assetWriter, let input = videoInput, let url = outputURL else { return nil }
        guard sessionStarted else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        input.markAsFinished()
        let group = DispatchGroup()
        group.enter()
        writer.finishWriting {
            group.leave()
        }
        group.wait()

        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return url
    }

    private func cleanup() {
        assetWriter = nil
        videoInput = nil
        adaptor = nil
        outputURL = nil
        sessionStarted = false
        firstTimestamp = nil
        lastAppendedFrameIndex = -1
    }
}
