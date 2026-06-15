import AVFoundation
import Combine
import UIKit

final class BodyScanCameraService: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var activePosition: AVCaptureDevice.Position = .front

    /// Callback sur la queue caméra — brancher le tracker Vision ici.
    nonisolated(unsafe) var onFrame: ((CMSampleBuffer, AVCaptureDevice.Position) -> Void)?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.useprocess.bodyscan.camera", qos: .userInteractive)
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentInput: AVCaptureDeviceInput?

    @MainActor
    func refreshAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    @MainActor
    func requestAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        refreshAuthorizationStatus()
        return granted
    }

    @MainActor
    func start(preferredPosition: AVCaptureDevice.Position = .front) {
        sessionQueue.async { [weak self] in
            self?.configureSession(position: preferredPosition)
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    @MainActor
    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
    }

    func capturePhoto(from sampleBuffer: CMSampleBuffer?) -> UIImage? {
        guard let sampleBuffer,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        let orientation: UIImage.Orientation = activePosition == .front ? .leftMirrored : .right
        return UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
    }

    private func configureSession(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        if let currentInput {
            session.removeInput(currentInput)
            self.currentInput = nil
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        currentInput = input

        if !session.outputs.contains(videoOutput) {
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
        }

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            // Buffer brut (non miroir) — Vision .leftMirrored + aperçu miroir = repère cohérent.
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        session.commitConfiguration()

        DispatchQueue.main.async {
            self.activePosition = position
        }
    }
}

extension BodyScanCameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer, .front)
    }
}
