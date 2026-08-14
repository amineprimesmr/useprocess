import AVFoundation
import SwiftUI

struct BodyScanCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var mirrorFrontCamera: Bool = true
    var isSessionRunning: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(mirrorFrontCamera: mirrorFrontCamera)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.configureConnection(mirror: mirrorFrontCamera)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.mirrorFrontCamera = mirrorFrontCamera
        uiView.previewLayer.session = session
        uiView.configureConnection(mirror: mirrorFrontCamera)
        if isSessionRunning {
            uiView.setNeedsLayout()
        }
    }

    final class Coordinator {
        var mirrorFrontCamera: Bool

        init(mirrorFrontCamera: Bool) {
            self.mirrorFrontCamera = mirrorFrontCamera
        }
    }

    final class PreviewView: UIView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
            backgroundColor = .black
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { nil }

        override func layoutSubviews() {
            super.layoutSubviews()
            ProcessScanCamera.layoutPreviewLayer(
                previewLayer,
                in: bounds,
                zoom: ProcessScanCamera.frontPreviewLayoutZoom
            )
        }

        func configureConnection(mirror: Bool) {
            guard let connection = previewLayer.connection else { return }
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirror
            }
            connection.isEnabled = true
        }
    }
}
