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
    private var deliversFrames = true
    private var captureProfileIsFullBody = false

    @MainActor
    func refreshAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    @MainActor
    func requestAccess(analyticsSource: String = "face_scan") async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        refreshAuthorizationStatus()
        if granted {
            ProcessAnalytics.trackCameraAuthorized(source: analyticsSource)
        } else {
            ProcessAnalytics.trackCameraDenied(source: analyticsSource)
        }
        return granted
    }

    @MainActor
    func start(
        preferredPosition: AVCaptureDevice.Position = .front,
        deliversFrames: Bool = true,
        profile: ProcessScanCameraProfile = .facePortrait
    ) {
        ProcessAudioSession.configureForMixingWithOthersIfIdle()
        let wantsFullBody = profile.isFullBody
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let sameConfig = self.currentInput != nil
                && self.activePosition == preferredPosition
                && self.deliversFrames == deliversFrames
                && self.captureProfileIsFullBody == wantsFullBody

            if self.session.isRunning, sameConfig {
                DispatchQueue.main.async { self.isRunning = true }
                return
            }

            if self.session.isRunning {
                self.session.stopRunning()
            }

            self.deliversFrames = deliversFrames
            self.captureProfileIsFullBody = wantsFullBody
            self.configureSession(
                position: preferredPosition,
                deliversFrames: deliversFrames,
                profile: profile
            )
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    @MainActor
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    /// Stop propre puis redémarrage — évite les sessions figées après background / relance.
    @MainActor
    func restartPreviewIfNeeded(
        preferredPosition: AVCaptureDevice.Position = .front,
        profile: ProcessScanCameraProfile = .facePortrait
    ) async {
        let wantsFullBody = profile.isFullBody
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }

                if self.session.isRunning {
                    self.session.stopRunning()
                }

                self.deliversFrames = false
                self.captureProfileIsFullBody = wantsFullBody
                self.configureSession(
                    position: preferredPosition,
                    deliversFrames: false,
                    profile: profile
                )
                if !self.session.isRunning {
                    self.session.startRunning()
                }

                DispatchQueue.main.async {
                    self.isRunning = true
                    continuation.resume()
                }
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

    private func configureSession(
        position: AVCaptureDevice.Position,
        deliversFrames: Bool,
        profile: ProcessScanCameraProfile
    ) {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        if let currentInput {
            session.removeInput(currentInput)
            self.currentInput = nil
        }

        if session.outputs.contains(videoOutput) {
            session.removeOutput(videoOutput)
        }

        guard let device = ProcessScanCamera.device(position: position, profile: profile),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        currentInput = input
        ProcessScanCamera.prepareForFrontPortraitScan()
        ProcessScanCamera.applyZoomProfile(to: device, profile: profile)

        if deliversFrames {
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
            }
        }

        session.commitConfiguration()

        ProcessScanCamera.applyZoomProfile(to: device, profile: profile)

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
