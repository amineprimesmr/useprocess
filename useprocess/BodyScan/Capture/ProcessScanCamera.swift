import AVFoundation
import UIKit

/// Profil caméra — visage serré vs corps entier (circuit lymphatique, scan 360°).
enum ProcessScanCameraProfile: Sendable {
    case facePortrait
    case fullBody

    nonisolated var isFullBody: Bool {
        if case .fullBody = self { return true }
        return false
    }
}

/// Verrouillage zoom capteur front — onboarding plus serré que le hub scan du jour.
enum ProcessScanPortraitLockProfile: Sendable {
    case standard
    case hub
    case onboarding
}

/// Caméra des scans Process — selfie standard (TrueDepth), pas l’ultra grand-angle front.
enum ProcessScanCamera {
    /// Crop visuel UIKit / conteneur ARKit preview — selfie serré, pas ultra grand-angle.
    nonisolated static let frontPreviewLayoutZoom: CGFloat = 1.58
    /// Circuit lymphatique / scan corps — pas de crop preview supplémentaire.
    nonisolated static let fullBodyPreviewLayoutZoom: CGFloat = 1.0
    /// Hub scan du jour (ovale compact) — crop portrait serré, effet selfie standard.
    nonisolated static let scanDayHubPreviewZoom: CGFloat = 1.68
    /// Zoom capteur front hub — pousse un peu plus que le plein écran.
    nonisolated static let scanDayHubPortraitZoom: CGFloat = 1.42
    /// Zoom capteur onboarding — force l’optique standard dual-front (≥ 1) + léger crop capteur.
    nonisolated static let onboardingPortraitSensorZoom: CGFloat = 1.58
    /// Crop UIKit scan onboarding ovale (dashboard + premier scan).
    nonisolated static let onboardingPortraitPreviewZoom: CGFloat = 1.82
    /// Zoom capteur AVCapture — ≥ 1 force l’optique « standard » sur iPhone dual-front.
    nonisolated static let frontPortraitZoom: CGFloat = 1.38

    nonisolated static func portraitSensorZoom(for profile: ProcessScanPortraitLockProfile) -> CGFloat {
        switch profile {
        case .standard:
            return frontPortraitZoom
        case .hub:
            return scanDayHubPortraitZoom
        case .onboarding:
            return onboardingPortraitSensorZoom
        }
    }

    nonisolated static func portraitPreviewZoom(for profile: ProcessScanPortraitLockProfile) -> CGFloat {
        switch profile {
        case .standard:
            return frontPreviewLayoutZoom
        case .hub:
            return scanDayHubPreviewZoom
        case .onboarding:
            return onboardingPortraitPreviewZoom
        }
    }

    static func device(
        position: AVCaptureDevice.Position,
        profile: ProcessScanCameraProfile = .facePortrait
    ) -> AVCaptureDevice? {
        if position == .front {
            switch profile {
            case .facePortrait:
                return preferredFrontPortraitDevice()
            case .fullBody:
                return preferredFrontFullBodyDevice()
            }
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    static func previewLayoutZoom(for profile: ProcessScanCameraProfile) -> CGFloat {
        switch profile {
        case .facePortrait:
            return frontPreviewLayoutZoom
        case .fullBody:
            return fullBodyPreviewLayoutZoom
        }
    }

    /// Selfie Face ID / TrueDepth en priorité — évite l’ultra-wide front quand un 2e capteur existe.
    nonisolated static func preferredFrontPortraitDevice() -> AVCaptureDevice? {
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

    /// Grand-angle front max — circuit lymphatique / tracking corps entier.
    nonisolated static func preferredFrontFullBodyDevice() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTrueDepthCamera
            ],
            mediaType: .video,
            position: .front
        )

        if let widest = discovery.devices.min(by: {
            if $0.minAvailableVideoZoomFactor != $1.minAvailableVideoZoomFactor {
                return $0.minAvailableVideoZoomFactor < $1.minAvailableVideoZoomFactor
            }
            let rank: (AVCaptureDevice.DeviceType) -> Int = { type in
                switch type {
                case .builtInUltraWideCamera: return 0
                case .builtInWideAngleCamera: return 1
                default: return 2
                }
            }
            return rank($0.deviceType) < rank($1.deviceType)
        }) {
            return widest
        }

        return preferredFrontPortraitDevice()
    }

    nonisolated static func applyZoomProfile(
        to device: AVCaptureDevice,
        profile: ProcessScanCameraProfile
    ) {
        switch profile {
        case .facePortrait:
            lockFrontCameraOutOfUltraWide(device)
        case .fullBody:
            lockFrontCameraForFullBody(device)
        }
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

    nonisolated static func lockActiveFrontCamerasIfPossible(
        profile: ProcessScanPortraitLockProfile = .standard
    ) {
        disableCenterStageSafely()
        let preferredZoom = portraitSensorZoom(for: profile)

        if let primary = preferredFrontPortraitDevice() {
            lockFrontCameraOutOfUltraWide(primary, preferredPortraitZoom: preferredZoom)
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera,
                .builtInUltraWideCamera
            ],
            mediaType: .video,
            position: .front
        )
        discovery.devices.forEach {
            lockFrontCameraOutOfUltraWide($0, preferredPortraitZoom: preferredZoom)
        }
    }

    /// Verrouillage synchrone avant `ARSession.run` — ARKit ne tient pas encore le capteur.
    nonisolated static func lockFrontCamerasBeforeARSession(
        profile: ProcessScanPortraitLockProfile = .standard
    ) {
        prepareForFrontPortraitScan()
        lockActiveFrontCamerasIfPossible(profile: profile)
    }

    nonisolated static func lockFrontCameraOutOfUltraWide(
        _ device: AVCaptureDevice,
        preferredPortraitZoom: CGFloat = frontPortraitZoom
    ) {
        guard device.position == .front else { return }

        do {
            try device.lockForConfiguration()
            let maxZoom = device.maxAvailableVideoZoomFactor
            let minZoom = device.minAvailableVideoZoomFactor
            // minZoom < 1 ⇒ caméra virtuelle dual-front ; forcer ≥ 1 = optique standard.
            let standardFloor = max(1.0, minZoom)
            let target = min(max(standardFloor, preferredPortraitZoom), maxZoom)
            if abs(device.videoZoomFactor - target) > 0.02 {
                device.videoZoomFactor = target
            }
            device.unlockForConfiguration()
        } catch {
            // Session déjà verrouillée (ARKit, etc.).
        }
    }

    /// Zoom capteur minimal — champ le plus large pour voir genoux / bras levés.
    nonisolated static func lockFrontCameraForFullBody(_ device: AVCaptureDevice) {
        guard device.position == .front else { return }

        do {
            try device.lockForConfiguration()
            let target = device.minAvailableVideoZoomFactor
            if abs(device.videoZoomFactor - target) > 0.02 {
                device.videoZoomFactor = target
            }
            device.unlockForConfiguration()
        } catch {
            // Session déjà verrouillée (ARKit, etc.).
        }
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
