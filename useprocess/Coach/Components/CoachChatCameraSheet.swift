import AVFoundation
import SwiftUI
import UIKit

struct CoachChatCameraSheet: View {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var camera = CoachCameraSessionModel()
    @State private var showOptions = false
    @State private var flashMode: CoachCameraFlashMode = .off

    private let previewCornerRadius: CGFloat = 44

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 56)

                ZStack(alignment: .bottom) {
                    CoachCameraPreview(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))

                    cameraControls
                        .padding(.horizontal, 22)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 18)
            }
        }
        .onAppear {
            Task {
                await camera.requestAccessIfNeeded()
                camera.configure(flashMode: flashMode)
                camera.start()
            }
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: flashMode) { _, mode in
            camera.setFlash(mode)
        }
    }

    private var cameraControls: some View {
        HStack(alignment: .bottom) {
            circleControl(icon: "chevron.left", size: 44) {
                onCancel()
            }

            Spacer()

            Button {
                HapticManager.shared.impact(.medium)
                camera.capturePhoto(flashMode: flashMode) { image in
                    if let image {
                        onCapture(image)
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.95), lineWidth: 4)
                        .frame(width: 74, height: 74)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 62, height: 62)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if showOptions {
                VStack(spacing: 14) {
                    circleControl(icon: flashMode.icon, size: 44) {
                        flashMode = flashMode.next
                    }
                    circleControl(icon: "arrow.triangle.2.circlepath.camera", size: 44) {
                        camera.flipCamera()
                    }
                    circleControl(icon: "xmark", size: 44) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            showOptions = false
                        }
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                circleControl(icon: "ellipsis", size: 44) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        showOptions = true
                    }
                }
            }
        }
    }

    private func circleControl(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private enum CoachCameraFlashMode {
    case off, on, auto

    var icon: String {
        switch self {
        case .off: "bolt.slash.fill"
        case .on: "bolt.fill"
        case .auto: "bolt.badge.automatic.fill"
        }
    }

    var next: CoachCameraFlashMode {
        switch self {
        case .off: .on
        case .on: .auto
        case .auto: .off
        }
    }

    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: .off
        case .on: .on
        case .auto: .auto
        }
    }
}

private final class CoachCameraSessionModel: NSObject {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "coach.camera.session")
    private var captureDevice: AVCaptureDevice?
    private var isConfigured = false
    private var pendingCompletion: ((UIImage?) -> Void)?
    private var currentFlashMode: CoachCameraFlashMode = .off

    func configure(flashMode: CoachCameraFlashMode) {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input),
            session.canAddOutput(output)
        else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        session.addOutput(output)
        captureDevice = device
        isConfigured = true
        session.commitConfiguration()
        setFlash(flashMode)
    }

    func requestAccessIfNeeded() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            _ = await AVCaptureDevice.requestAccess(for: .video)
        default:
            return
        }
    }

    func start() {
        sessionQueue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    func flipCamera() {
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        let nextPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: nextPosition),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)
        if session.canAddInput(input) {
            session.addInput(input)
            captureDevice = device
        } else {
            session.addInput(currentInput)
        }
        session.commitConfiguration()
    }

    func setFlash(_ mode: CoachCameraFlashMode) {
        currentFlashMode = mode
    }

    func capturePhoto(flashMode: CoachCameraFlashMode, completion: @escaping (UIImage?) -> Void) {
        currentFlashMode = flashMode
        pendingCompletion = completion
        let settings = AVCapturePhotoSettings()
        if output.supportedFlashModes.contains(flashMode.avFlashMode) {
            settings.flashMode = flashMode.avFlashMode
        }
        sessionQueue.async { [output, weak self] in
            guard let self else { return }
            output.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CoachCameraSessionModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            DispatchQueue.main.async { [weak self] in
                self?.pendingCompletion?(nil)
                self?.pendingCompletion = nil
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.pendingCompletion?(image)
            self?.pendingCompletion = nil
        }
    }
}

private struct CoachCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CoachCameraPreviewView {
        let view = CoachCameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CoachCameraPreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class CoachCameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
