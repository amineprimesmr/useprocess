import AVFoundation
import UIKit

// MARK: - Caméra live + squelette (conversion Apple officielle)

final class BodyScanLiveCameraView: UIView {

    let previewLayer = AVCaptureVideoPreviewLayer()
    private let skeletonLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)

        skeletonLayer.fillColor = UIColor.clear.cgColor
        skeletonLayer.lineCap = .round
        skeletonLayer.lineJoin = .round
        previewLayer.addSublayer(skeletonLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    func attachSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        skeletonLayer.frame = previewLayer.bounds
        configurePreviewConnection()
    }

    private func configurePreviewConnection() {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }

    private func layerPoint(for landmark: BodyLandmark) -> CGPoint {
        previewLayer.pointFromVisionNormalized(
            x: CGFloat(landmark.x),
            y: CGFloat(landmark.y)
        )
    }

    func updateSkeleton(landmarks: [BodyLandmark], isReady: Bool) {
        skeletonLayer.frame = previewLayer.bounds

        let visible = landmarks.filter { $0.confidence >= 0.2 }
        guard visible.count >= 3, previewLayer.bounds.width > 1 else {
            skeletonLayer.path = nil
            return
        }

        var points: [String: CGPoint] = [:]
        for lm in visible {
            points[lm.name] = layerPoint(for: lm)
        }

        let path = UIBezierPath()
        let bones: [(String, String)] = [
            ("nose", "neck"),
            ("neck", "left_shoulder"), ("neck", "right_shoulder"),
            ("left_shoulder", "left_elbow"), ("left_elbow", "left_wrist"),
            ("right_shoulder", "right_elbow"), ("right_elbow", "right_wrist"),
            ("neck", "root"),
            ("root", "left_hip"), ("root", "right_hip"),
            ("left_hip", "left_knee"), ("left_knee", "left_ankle"),
            ("right_hip", "right_knee"), ("right_knee", "right_ankle")
        ]

        let maxLen = min(previewLayer.bounds.width, previewLayer.bounds.height) * 0.55
        for (a, b) in bones {
            guard let p1 = points[a], let p2 = points[b] else { continue }
            guard hypot(p1.x - p2.x, p1.y - p2.y) < maxLen else { continue }
            path.move(to: p1)
            path.addLine(to: p2)
        }

        let r: CGFloat = isReady ? 9 : 7
        for pt in points.values {
            path.move(to: pt)
            path.addArc(withCenter: pt, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        skeletonLayer.path = path.cgPath
        skeletonLayer.strokeColor = (isReady ? UIColor.systemGreen : UIColor.white).cgColor
        skeletonLayer.lineWidth = isReady ? 5 : 4
        CATransaction.commit()
    }
}

import SwiftUI

struct BodyScanLiveCameraRepresentable: UIViewRepresentable {
    let session: AVCaptureSession
    let landmarks: [BodyLandmark]
    let isReady: Bool

    func makeUIView(context: Context) -> BodyScanLiveCameraView {
        let view = BodyScanLiveCameraView()
        view.attachSession(session)
        return view
    }

    func updateUIView(_ uiView: BodyScanLiveCameraView, context: Context) {
        uiView.attachSession(session)
        uiView.updateSkeleton(landmarks: landmarks, isReady: isReady)
    }
}
