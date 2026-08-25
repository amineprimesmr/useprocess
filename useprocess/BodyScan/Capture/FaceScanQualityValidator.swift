import CoreGraphics
import simd
import UIKit

enum FaceScanQualityValidator {

    /// Seuil ARKit : en dessous → environnement sombre (lux approximatif).
    /// Assoupli : 650 bloquait trop souvent des pièces correctement éclairées.
    static let lowLightAmbientThreshold: CGFloat = 280

    static func isLowLight(ambientIntensity: CGFloat) -> Bool {
        ambientIntensity > 0 && ambientIntensity < lowLightAmbientThreshold
    }

    /// Luminance moyenne 0…1 sur le snapshot (visage visible).
    static func averageLuminance(of image: UIImage) -> CGFloat {
        guard let cg = image.cgImage else { return 0 }
        let width = min(64, cg.width)
        let height = min(64, cg.height)
        guard width > 0, height > 0 else { return 0 }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }

        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total: CGFloat = 0
        let count = width * height
        for i in 0..<count {
            let offset = i * 4
            let r = CGFloat(pixels[offset]) / 255
            let g = CGFloat(pixels[offset + 1]) / 255
            let b = CGFloat(pixels[offset + 2]) / 255
            total += 0.2126 * r + 0.7152 * g + 0.0722 * b
        }
        return total / CGFloat(count)
    }

    static func snapshotIsUsable(
        _ image: UIImage?,
        minimumLuminance: CGFloat = 0.08,
        screenFlashActive: Bool = false
    ) -> Bool {
        if screenFlashActive { return true }
        guard let image else { return false }
        return averageLuminance(of: image) >= minimumLuminance
    }

    static func meshIsSolid(_ mesh: FaceMesh3DData) -> Bool {
        mesh.isValid && mesh.vertices.count >= 360
    }

    static func headSpreadIsSufficient(_ samples: [SIMD2<Float>], minimum: Float = 0.22) -> Bool {
        guard samples.count >= 10 else { return false }
        let pitches = samples.map(\.x)
        let yaws = samples.map(\.y)
        guard let pMin = pitches.min(), let pMax = pitches.max(),
              let yMin = yaws.min(), let yMax = yaws.max() else { return false }
        return (pMax - pMin) + (yMax - yMin) >= minimum
    }

    enum FaceDistanceFeedback: Equatable {
        case ok
        case tooFar
        case tooClose
    }

    /// Distance caméra (mètres) + fill dans le viewport visible.
    /// Le fill est déjà dans le cadre (ovale) — ne pas le diviser par zoom²
    /// (un visage bien cadré passait pour « trop loin »).
    static func distanceFeedback(
        distanceMeters: Float?,
        screenFillRatio: CGFloat?,
        cameraZoom: CGFloat = 1
    ) -> FaceDistanceFeedback {
        _ = cameraZoom
        if let distance = distanceMeters {
            if distance < 0.07 { return .tooClose }
            if distance > 0.90 { return .tooFar }
        }

        if let ratio = screenFillRatio {
            if ratio < 0.028 { return .tooFar }
            if ratio > 0.82 { return .tooClose }
        }

        return .ok
    }

    static func distanceHint(for feedback: FaceDistanceFeedback) -> String? {
        switch feedback {
        case .ok:
            return nil
        case .tooFar:
            return AppCopy.tSync(
                "Ton visage doit bien remplir le cadre.",
                en: "Your face needs to fill the frame."
            )
        case .tooClose:
            return AppCopy.tSync(
                "Recule d'un tout petit peu.",
                en: "Move back just a little."
            )
        }
    }

    static func distanceInstruction(for feedback: FaceDistanceFeedback) -> String {
        switch feedback {
        case .ok:
            return AppCopy.tSync("Parfait. Garde cette distance.", en: "Perfect. Hold this distance.")
        case .tooFar:
            return AppCopy.tSync("Rapproche-toi de l'iPhone.", en: "Move closer to the iPhone.")
        case .tooClose:
            return AppCopy.tSync("Éloigne un peu l'iPhone.", en: "Move the iPhone a bit farther.")
        }
    }
}
