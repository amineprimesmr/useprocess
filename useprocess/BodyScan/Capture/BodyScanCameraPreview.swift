import AVFoundation
import SwiftUI

struct BodyScanCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var mirrorFrontCamera: Bool = true

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.configureConnection(mirror: mirrorFrontCamera)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
        uiView.configureConnection(mirror: mirrorFrontCamera)
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
            configureConnection(mirror: true)
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
        }
    }
}
