import CoreGraphics
import Foundation
import ImageIO
import UIKit

enum BodyScanImageStore {

    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("BodyScans", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    static func save(image: UIImage, scanId: String, pose: ScanPoseKind, suffix: String? = nil) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        let name = suffix.map { "\(scanId)_\(pose.rawValue)_\($0).jpg" } ?? "\(scanId)_\(pose.rawValue).jpg"
        let url = directoryURL.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(filename: String) -> UIImage? {
        guard let data = loadData(filename: filename) else { return nil }
        return UIImage(data: data)
    }

    static func loadData(filename: String) -> Data? {
        let url = directoryURL.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    /// Miniature légère pour texture baking (évite OOM).
    static func loadRGBAThumbnail(filename: String, maxPixel: Int = 256) -> RGBAImage? {
        guard let data = loadData(filename: filename) else { return nil }
        return RGBAImage.decodeThumbnail(data: data, maxPixel: maxPixel)
    }
}

/// Buffer RGBA décodé une seule fois — sampling direct sans UIImage.
struct RGBAImage {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    static func decodeThumbnail(data: Data, maxPixel: Int) -> RGBAImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return RGBAImage(cgImage: cg)
    }

    init?(cgImage: CGImage) {
        width = cgImage.width
        height = cgImage.height
        let count = width * height * 4
        var buffer = [UInt8](repeating: 0, count: count)
        guard let ctx = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = buffer
    }

    func sample(u: Float, v: Float) -> (CGFloat, CGFloat, CGFloat)? {
        guard width > 0, height > 0 else { return nil }
        let x = min(width - 1, max(0, Int(u * Float(width - 1))))
        let y = min(height - 1, max(0, Int((1 - v) * Float(height - 1))))
        let i = (y * width + x) * 4
        guard i + 2 < bytes.count else { return nil }
        return (
            CGFloat(bytes[i]) / 255,
            CGFloat(bytes[i + 1]) / 255,
            CGFloat(bytes[i + 2]) / 255
        )
    }
}
