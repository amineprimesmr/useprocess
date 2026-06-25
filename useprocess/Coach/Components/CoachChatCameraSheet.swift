import AVFoundation
import SwiftUI
import UIKit

/// Caméra intégrée au bas du chat — reste sur la même page, preview pleine largeur.
struct CoachInlineBottomCameraPanel: View {
    let panelHeight: CGFloat
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    @State private var showOptions = false
    @State private var flashMode: CoachCameraFlashMode = .off

    private var camera: CoachSharedCameraSession { .shared }

    private let topCornerRadius: CGFloat = 26

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: topCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: topCornerRadius,
            style: .continuous
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CoachCameraPreview(session: camera.session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            cameraControls
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: panelHeight)
        .background(Color.black)
        .clipShape(panelShape)
        .overlay {
            panelShape
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
        }
        .task {
            await camera.activate(flashMode: flashMode)
        }
        .onDisappear {
            camera.deactivate()
        }
        .onChange(of: flashMode) { _, mode in
            camera.setFlash(mode)
        }
    }

    private var cameraControls: some View {
        HStack(alignment: .bottom) {
            circleControl(icon: "chevron.down", size: 44) {
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

/// Photo capturée → rétrécit vers la vignette du composer.
struct CoachPhotoShrinkToInputAnimation: View {
    let image: UIImage
    let cameraPanelHeight: CGFloat
    let onComplete: () -> Void

    @State private var landed = false

    private let thumbnailSize: CGFloat = 68
    private let cameraHorizontalInset: CGFloat = 10
    private let cameraBottomInset: CGFloat = 14
    private let composerHorizontalInset: CGFloat = 30
    private let composerBottomLift: CGFloat = 118

    var body: some View {
        GeometryReader { geo in
            let safeBottom = geo.safeAreaInsets.bottom
            let panelWidth = geo.size.width - cameraHorizontalInset * 2

            let startWidth = panelWidth
            let startHeight = cameraPanelHeight
            let startCenter = CGPoint(
                x: geo.size.width * 0.5,
                y: geo.size.height - safeBottom - cameraBottomInset - startHeight * 0.5
            )

            let endWidth = thumbnailSize
            let endHeight = thumbnailSize
            let endCenter = CGPoint(
                x: composerHorizontalInset + endWidth * 0.5,
                y: geo.size.height - safeBottom - composerBottomLift + endWidth * 0.5
            )

            let width = landed ? endWidth : startWidth
            let height = landed ? endHeight : startHeight
            let center = landed ? endCenter : startCenter
            let cornerRadius = landed ? 12.0 : 26.0

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .position(x: center.x, y: center.y)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                landed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                onComplete()
            }
        }
    }
}

struct CoachChatCameraSheet: View {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showOptions = false
    @State private var flashMode: CoachCameraFlashMode = .off

    private var camera: CoachSharedCameraSession { .shared }

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
        .task {
            await camera.activate(flashMode: flashMode)
        }
        .onDisappear {
            camera.deactivate()
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

private final class CoachSharedCameraSession: NSObject, @unchecked Sendable {
    static let shared = CoachSharedCameraSession()

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "coach.camera.session", qos: .userInitiated)
    private var isConfigured = false
    private var activeClients = 0
    private var isCapturing = false
    private var pendingCompletion: ((UIImage?) -> Void)?
    private var currentFlashMode: CoachCameraFlashMode = .off

    func activate(flashMode: CoachCameraFlashMode) async {
        await MainActor.run {
            activeClients += 1
        }

        guard await requestAccessIfNeeded() else {
            await MainActor.run {
                activeClients = max(0, activeClients - 1)
            }
            return
        }

        await runOnSessionQueue {
            self.configureIfNeeded(flashMode: flashMode)
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func deactivate() {
        Task { @MainActor in
            activeClients = max(0, activeClients - 1)
            scheduleStopIfIdle()
        }
    }

    @MainActor
    private func scheduleStopIfIdle() {
        let clients = activeClients
        sessionQueue.async { [weak self] in
            guard let self, clients == 0, !self.isCapturing, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func setFlash(_ mode: CoachCameraFlashMode) {
        currentFlashMode = mode
    }

    func flipCamera() {
        sessionQueue.async { [weak self] in
            self?.flipCameraOnQueue()
        }
    }

    func capturePhoto(flashMode: CoachCameraFlashMode, completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, self.session.isRunning else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.currentFlashMode = flashMode
            self.pendingCompletion = completion
            self.isCapturing = true

            let settings = AVCapturePhotoSettings()
            if self.output.supportedFlashModes.contains(flashMode.avFlashMode) {
                settings.flashMode = flashMode.avFlashMode
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    private func requestAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func runOnSessionQueue(_ block: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                block()
                continuation.resume()
            }
        }
    }

    private func configureIfNeeded(flashMode: CoachCameraFlashMode) {
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
        isConfigured = true
        session.commitConfiguration()
        currentFlashMode = flashMode
    }

    private func flipCameraOnQueue() {
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        let nextPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: nextPosition),
            let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            session.addInput(currentInput)
        }
        session.commitConfiguration()
    }
}

extension CoachSharedCameraSession: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            sessionQueue.async { [weak self] in
                self?.isCapturing = false
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingCompletion?(nil)
                self.pendingCompletion = nil
                Task { @MainActor in
                    self.scheduleStopIfIdle()
                }
            }
            return
        }

        sessionQueue.async { [weak self] in
            self?.isCapturing = false
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                let normalized = CoachAttachmentImageNormalizer.normalize(image)
                self.pendingCompletion?(normalized)
                self.pendingCompletion = nil
                self.scheduleStopIfIdle()
            }
        }
    }
}

private enum CoachAttachmentImageNormalizer {
    static func normalize(_ image: UIImage, maxPixel: CGFloat = 1200) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxPixel, maxSide > 0 else { return image }

        let scale = maxPixel / maxSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
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
