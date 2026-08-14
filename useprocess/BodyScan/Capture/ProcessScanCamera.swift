import AVFoundation
import UIKit

/// Caméra des scans Process — la frontale ne passe jamais en ultra grand-angle.
enum ProcessScanCamera {
    /// Crop visuel UIKit. ARKit ignore `videoZoomFactor` et SwiftUI `scaleEffect`.
    static let frontPreviewLayoutZoom: CGFloat = 2.32
    /// Zoom capteur quand on possède la session (pas ARKit).
    static let frontPortraitZoom: CGFloat = 2.0

    static func device(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .front {
            return AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// À appeler **avant** `ARSession.run` / `startRunning`.
    static func prepareForFrontPortraitScan() {
        disableCenterStageSafely()
    }

    /// Center Stage ne peut pas être coupé tant que le mode est `.user` (crash).
    static func disableCenterStageSafely() {
        guard #available(iOS 14.5, *) else { return }
        if AVCaptureDevice.centerStageControlMode == .user {
            AVCaptureDevice.centerStageControlMode = .app
        }
        guard AVCaptureDevice.centerStageControlMode != .user else { return }
        if AVCaptureDevice.isCenterStageEnabled {
            AVCaptureDevice.isCenterStageEnabled = false
        }
    }

    static func lockFrontCameraOutOfUltraWide(_ device: AVCaptureDevice) {
        guard device.position == .front else { return }

        do {
            try device.lockForConfiguration()
            let maxZoom = device.maxAvailableVideoZoomFactor
            let minZoom = device.minAvailableVideoZoomFactor
            let floor = max(1.0, minZoom)
            let target = min(max(floor, frontPortraitZoom), maxZoom)
            if abs(device.videoZoomFactor - target) > 0.02 {
                device.videoZoomFactor = target
            }
            device.unlockForConfiguration()
        } catch {
            // Session déjà verrouillée (ARKit, etc.).
        }
    }

    static func lockActiveFrontCamerasIfPossible() {
        disableCenterStageSafely()
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera,
                .builtInUltraWideCamera
            ],
            mediaType: .video,
            position: .front
        )
        discovery.devices.forEach(lockFrontCameraOutOfUltraWide)
    }

    /// Agrandit le layer dans un parent `clipsToBounds` — seul crop fiable sur ARKit / preview.
    static func layoutPreviewLayer(_ layer: CALayer, in bounds: CGRect, zoom: CGFloat) {
        let factor = max(1, zoom)
        let width = bounds.width * factor
        let height = bounds.height * factor
        layer.frame = CGRect(
            x: (bounds.width - width) / 2,
            y: (bounds.height - height) / 2,
            width: width,
            height: height
        )
    }
}
