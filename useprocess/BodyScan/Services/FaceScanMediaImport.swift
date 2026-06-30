import AVFoundation
import Foundation
import UIKit
import Vision

/// Import galerie — analyse Vision d'une photo ou d'une vidéo (frame centrale).
enum FaceScanMediaImport {

    enum ImportError: LocalizedError {
        case unreadableMedia
        case noFaceDetected
        case videoProcessingFailed

        var errorDescription: String? {
            switch self {
            case .unreadableMedia:
                return "Impossible de lire ce fichier."
            case .noFaceDetected:
                return "Aucun visage détecté — choisis une photo ou vidéo où ton visage est bien visible."
            case .videoProcessingFailed:
                return "Impossible d'analyser cette vidéo."
            }
        }
    }

    @MainActor
    static func process(image: UIImage) throws -> (FaceScanCapturePayload, FaceWellnessMarkers) {
        let normalized = normalize(image)
        guard containsFace(in: normalized) else {
            throw ImportError.noFaceDetected
        }

        let scanId = UUID().uuidString
        var markers = FaceWellnessAnalyzer.analyze(from: normalized, pose: .faceFront)
        markers.notes.insert("Scan importé depuis une photo.", at: 0)

        let payload = FaceScanCapturePayload(
            scanId: scanId,
            mesh: .empty,
            snapshot: normalized,
            videoFilename: nil,
            averageBlendShapes: [:],
            yawCoverage: 0
        )
        return (payload, markers)
    }

    @MainActor
    static func process(videoSourceURL: URL) async throws -> (FaceScanCapturePayload, FaceWellnessMarkers) {
        let scanId = UUID().uuidString
        let tempVideo = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(scanId)-import.mp4")

        defer {
            try? FileManager.default.removeItem(at: tempVideo)
        }

        do {
            if FileManager.default.fileExists(atPath: tempVideo.path) {
                try FileManager.default.removeItem(at: tempVideo)
            }
            try FileManager.default.copyItem(at: videoSourceURL, to: tempVideo)
        } catch {
            throw ImportError.unreadableMedia
        }

        guard let snapshot = await snapshot(from: tempVideo) else {
            throw ImportError.videoProcessingFailed
        }

        let normalized = normalize(snapshot)
        guard containsFace(in: normalized) else {
            throw ImportError.noFaceDetected
        }

        guard let videoFilename = FaceScanImageStore.saveVideo(from: tempVideo, scanId: scanId) else {
            throw ImportError.videoProcessingFailed
        }

        var markers = FaceWellnessAnalyzer.analyze(from: normalized, pose: .faceFront)
        markers.notes.insert("Scan importé depuis une vidéo.", at: 0)

        let payload = FaceScanCapturePayload(
            scanId: scanId,
            mesh: .empty,
            snapshot: normalized,
            videoFilename: videoFilename,
            averageBlendShapes: [:],
            yawCoverage: 0
        )
        return (payload, markers)
    }

    // MARK: - Helpers

    private static func containsFace(in image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil else { return false }
        return !(request.results?.isEmpty ?? true)
    }

    private static func snapshot(from videoURL: URL) async -> UIImage? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1600, height: 1600)

        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            return nil
        }

        let totalSeconds = max(CMTimeGetSeconds(duration), 0)
        let sampleSeconds = min(max(totalSeconds * 0.35, 0), max(totalSeconds - 0.05, 0))
        let time = CMTime(seconds: sampleSeconds, preferredTimescale: 600)

        return await withCheckedContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, _ in
                if result == .succeeded, let cgImage {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func normalize(_ image: UIImage, maxPixel: CGFloat = 1400) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxPixel, maxSide > 0 else { return image }

        let scale = maxPixel / maxSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
