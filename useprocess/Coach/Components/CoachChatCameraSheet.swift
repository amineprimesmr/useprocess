import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

/// Caméra intégrée au bas du chat — preview pleine largeur jusqu’au bord inférieur.
struct CoachInlineBottomCameraPanel: View {
    let panelHeight: CGFloat
    var onCapture: (UIImage) -> Void
    var onPickFromGallery: (UIImage) -> Void
    var onCancel: () -> Void

    @State private var showGalleryPicker = false
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
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                CoachCameraPreview(session: camera.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        HapticManager.shared.impact(.light)
                        camera.flipCamera()
                    }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                CoachCameraControlsBar(
                    dismissIcon: "chevron.down",
                    onDismiss: onCancel,
                    onCapture: capturePhoto,
                    onOpenGallery: { showGalleryPicker = true }
                )
                .padding(.horizontal, 22)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 10) + 6)
            }
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
        .sheet(isPresented: $showGalleryPicker) {
            CoachChatSingleImagePicker(
                onSelect: { image in
                    showGalleryPicker = false
                    onPickFromGallery(image)
                },
                onCancel: { showGalleryPicker = false }
            )
        }
    }

    private func capturePhoto() {
        HapticManager.shared.impact(.medium)
        camera.capturePhoto(flashMode: flashMode) { image in
            if let image {
                onCapture(image)
            }
        }
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
    var onPickFromGallery: ((UIImage) -> Void)? = nil
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showGalleryPicker = false
    @State private var flashMode: CoachCameraFlashMode = .off

    private var camera: CoachSharedCameraSession { .shared }

    private let previewCornerRadius: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            ZStack {
                (colorScheme == .dark ? Color.black : Color(white: 0.08))
                    .ignoresSafeArea()

                ZStack(alignment: .bottom) {
                    CoachCameraPreview(session: camera.session)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
                        .padding(.horizontal, 8)
                        .padding(.top, geo.safeAreaInsets.top + 6)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 4)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            HapticManager.shared.impact(.light)
                            camera.flipCamera()
                        }

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 4)
                    .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
                    .allowsHitTesting(false)

                    CoachCameraControlsBar(
                        dismissIcon: "chevron.left",
                        onDismiss: onCancel,
                        onCapture: capturePhoto,
                        onOpenGallery: { showGalleryPicker = true }
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 18)
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await camera.activate(flashMode: flashMode)
        }
        .onDisappear {
            camera.deactivate()
        }
        .onChange(of: flashMode) { _, mode in
            camera.setFlash(mode)
        }
        .sheet(isPresented: $showGalleryPicker) {
            CoachChatSingleImagePicker(
                onSelect: { image in
                    showGalleryPicker = false
                    if let onPickFromGallery {
                        onPickFromGallery(image)
                    } else {
                        onCapture(image)
                    }
                },
                onCancel: { showGalleryPicker = false }
            )
        }
    }

    private func capturePhoto() {
        HapticManager.shared.impact(.medium)
        camera.capturePhoto(flashMode: flashMode) { image in
            if let image {
                onCapture(image)
            }
        }
    }
}

// MARK: - Contrôles partagés

private struct CoachCameraControlsBar: View {
    let dismissIcon: String
    var onDismiss: () -> Void
    var onCapture: () -> Void
    var onOpenGallery: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            CoachCameraGlassButton(systemName: dismissIcon, action: onDismiss)

            Spacer(minLength: 0)

            Button(action: onCapture) {
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

            Spacer(minLength: 0)

            CoachCameraGlassButton(systemName: "photo.on.rectangle", action: onOpenGallery)
        }
    }
}

private struct CoachCameraGlassButton: View {
    let systemName: String
    let action: () -> Void

    private let size: CGFloat = 44

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .modifier(CoachCameraGlassButtonStyle())
        .accessibilityLabel(systemName == "photo.on.rectangle" ? "Galerie" : "Retour")
    }
}

private struct CoachCameraGlassButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.plain)
                .glassEffect(ProcessGlass.tinted(.white, opacity: 0.24), in: Circle())
        } else {
            content
                .buttonStyle(.plain)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
                }
                .buttonStyle(ProcessGlassPressStyle())
        }
    }
}

// MARK: - Galerie (une image)

struct CoachChatSingleImagePicker: UIViewControllerRepresentable {
    var onSelect: (UIImage) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (UIImage) -> Void
        let onCancel: () -> Void

        init(onSelect: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onSelect = onSelect
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                onCancel()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else {
                    DispatchQueue.main.async { self.onCancel() }
                    return
                }
                DispatchQueue.main.async {
                    self.onSelect(CoachAttachmentImageNormalizer.normalize(image))
                }
            }
        }
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
            ProcessAudioSession.configureForMixingWithOthers()
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

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
