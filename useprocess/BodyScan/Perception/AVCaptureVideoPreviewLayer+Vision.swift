import AVFoundation
import CoreGraphics

extension AVCaptureVideoPreviewLayer {

    /// Point Vision (origine bas-gauche, normalisé 0…1, orientation `.left`) → couche preview miroir.
    /// `layerPointConverted` applique le miroir selfie une seule fois.
    func pointFromVisionNormalized(x: CGFloat, y: CGFloat) -> CGPoint {
        let devicePoint = CGPoint(x: x, y: 1.0 - y)
        return layerPointConverted(fromCaptureDevicePoint: devicePoint)
    }
}
