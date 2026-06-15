import CoreGraphics
import UIKit

enum FaceScanQualityValidator {

    /// Seuil ARKit : en dessous → environnement sombre (lux approximatif).
    static let lowLightAmbientThreshold: CGFloat = 650

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

    static func snapshotIsUsable(_ image: UIImage?, minimumLuminance: CGFloat = 0.12) -> Bool {
        guard let image else { return false }
        return averageLuminance(of: image) >= minimumLuminance
    }

    static func meshIsSolid(_ mesh: FaceMesh3DData) -> Bool {
        mesh.isValid && mesh.vertices.count >= 450
    }

    static func headSpreadIsSufficient(_ samples: [SIMD2<Float>], minimum: Float = 0.38) -> Bool {
        guard samples.count >= 20 else { return false }
        let pitches = samples.map(\.x)
        let yaws = samples.map(\.y)
        guard let pMin = pitches.min(), let pMax = pitches.max(),
              let yMin = yaws.min(), let yMax = yaws.max() else { return false }
        return (pMax - pMin) + (yMax - yMin) >= minimum
    }
}
