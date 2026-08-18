import AVFoundation
import UIKit

/// Caméra des scans Process — selfie standard (TrueDepth), pas l’ultra grand-angle front.
enum ProcessScanCamera {
    /// Crop visuel UIKit / conteneur ARKit preview.
    nonisolated static let frontPreviewLayoutZoom: CGFloat = 1.28
    /// Zoom capteur AVCapture — ≥ 1 force l’optique « standard » sur iPhone dual-front.
    nonisolated static let frontPortraitZoom: CGFloat = 1.28

    static func device(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .front {
            return preferredFrontPortraitDevice()
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// Selfie Face ID / TrueDepth en priorité — évite l’ultra-wide front quand un 2e capteur existe.
    static func preferredFrontPortraitDevice() -> AVCaptureDevice? {
        if let trueDepth = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) {
            return trueDepth
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        if let trueDepth = discovery.devices.first(where: { $0.deviceType == .builtInTrueDepthCamera }) {
            return trueDepth
        }

        // Dual-front : préférer un capteur qui peut rester à zoom ≥ 1 (pas ultra grand-angle).
        if let standard = discovery.devices.first(where: { $0.minAvailableVideoZoomFactor >= 0.99 }) {
            return standard
        }
        return discovery.devices.first
    }

    /// À appeler **avant** `ARSession.run` / `startRunning`.
    nonisolated static func prepareForFrontPortraitScan() {
        disableCenterStageSafely()
    }

    /// Center Stage ne peut pas être coupé tant que le mode est `.user` (crash).
    nonisolated static func disableCenterStageSafely() {
        guard #available(iOS 14.5, *) else { return }
        if AVCaptureDevice.centerStageControlMode == .user {
            AVCaptureDevice.centerStageControlMode = .app
        }
        guard AVCaptureDevice.centerStageControlMode != .user else { return }
        if AVCaptureDevice.isCenterStageEnabled {
            AVCaptureDevice.isCenterStageEnabled = false
        }
    }

    nonisolated static func lockFrontCameraOutOfUltraWide(_ device: AVCaptureDevice) {
        guard device.position == .front else { return }

        do {
            try device.lockForConfiguration()
            let maxZoom = device.maxAvailableVideoZoomFactor
            let minZoom = device.minAvailableVideoZoomFactor
            // minZoom < 1 ⇒ caméra virtuelle dual-front ; forcer ≥ 1 = optique standard.
            let standardFloor = max(1.0, minZoom)
            let target = min(max(standardFloor, frontPortraitZoom), maxZoom)
            if abs(device.videoZoomFactor - target) > 0.02 {
                device.videoZoomFactor = target
            }
            device.unlockForConfiguration()
        } catch {
            // Session déjà verrouillée (ARKit, etc.).
        }
    }

    nonisolated static func lockActiveFrontCamerasIfPossible() {
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
