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
                return AppCopy.tSync("Impossible de lire ce fichier.", en: "Couldn't read this file.")
            case .noFaceDetected:
                return AppCopy.tSync(
                    "Aucun visage détecté — choisis une photo ou vidéo où ton visage est bien visible.",
                    en: "No face detected — pick a photo or video where your face is clearly visible."
                )
            case .videoProcessingFailed:
                return AppCopy.tSync(
                    "Impossible d'analyser cette vidéo.",
                    en: "Couldn't analyze this video."
                )
            }
        }
    }

    /// Photo — resize/orientation hors MainActor, puis Vision.
    static func process(image: UIImage) async throws -> (FaceScanCapturePayload, FaceWellnessMarkers) {
        let normalized = await Task.detached(priority: .userInitiated) {
            normalize(image)
        }.value

        guard containsFace(in: normalized) else {
            throw ImportError.noFaceDetected
        }

        let scanId = UUID().uuidString
        var markers = FaceWellnessAnalyzer.analyze(from: normalized, pose: .faceFront)
        markers.notes.insert(
            AppCopy.tSync("Scan importé depuis une photo.", en: "Scan imported from a photo."),
            at: 0
        )

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

        let normalized = await Task.detached(priority: .userInitiated) {
            normalize(snapshot)
        }.value

        guard containsFace(in: normalized) else {
            throw ImportError.noFaceDetected
        }

        guard let videoFilename = FaceScanImageStore.saveVideo(from: tempVideo, scanId: scanId) else {
            throw ImportError.videoProcessingFailed
        }

        var markers = FaceWellnessAnalyzer.analyze(from: normalized, pose: .faceFront)
        markers.notes.insert(
            AppCopy.tSync("Scan importé depuis une vidéo.", en: "Scan imported from a video."),
            at: 0
        )

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

    /// Resize + orientation `.up` — appelé hors MainActor.
    nonisolated private static func normalize(_ image: UIImage, maxPixel: CGFloat = 1400) -> UIImage {
        let upright = image.normalizedUpOrientation()
        let maxSide = max(upright.size.width, upright.size.height)
        guard maxSide > maxPixel, maxSide > 0 else { return upright }

        let scale = maxPixel / maxSide
        let newSize = CGSize(width: upright.size.width * scale, height: upright.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            upright.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

private extension UIImage {
    nonisolated func normalizedUpOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
