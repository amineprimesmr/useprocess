import Foundation
import UIKit
import Vision

nonisolated enum VisionPoseExtractor {

    static func extractLandmarks(from image: UIImage) -> [BodyLandmark] {
        BodyPoseTracker().landmarksFromImage(image)
    }

    static func detectHumanPresence(in image: UIImage) -> Bool {
        !extractLandmarks(from: image).isEmpty
    }

    static func bodyFillRatio(landmarks: [BodyLandmark]) -> Double {
        let ys = landmarks.map(\.y)
        guard let minY = ys.min(), let maxY = ys.max() else { return 0 }
        return max(0, min(1, maxY - minY))
    }

    static func evaluateCaptureQuality(
        landmarks: [BodyLandmark],
        pose: ScanPoseKind,
        humanDetected: Bool,
        segmentationCoverage: Double = 0,
        poseMatchScore: Double = 0
    ) -> ScanQualityFeedback {
        if pose.isFacePose {
            let faceOK = humanDetected && (landmarks.count >= 2 || segmentationCoverage > 0.06)
            return ScanQualityFeedback(
                isReady: faceOK,
                message: faceOK
                    ? "Visage détecté — capture automatique…"
                    : "Centre ton visage dans le cadre.",
                score: faceOK ? 85 : 20
            )
        }

        if pose == .turntable {
            let count = landmarks.count
            let bodyOK = count >= 6 && (segmentationCoverage > 0.14 || humanDetected)
            return ScanQualityFeedback(
                isReady: bodyOK,
                message: bodyOK ? "Corps détecté — continue de tourner" : "Recule — corps entier visible",
                score: bodyOK ? 70 : 25
            )
        }

        let count = landmarks.count
        let hasHips = landmarks.contains { $0.name.contains("hip") || $0.name == "root" }
        let hasKnees = landmarks.contains { $0.name.contains("knee") }
        let hasAnkles = landmarks.contains { $0.name.contains("ankle") }
        let fill = bodyFillRatio(landmarks: landmarks)

        // Segmentation Apple — filet de sécurité si le squelette est partiel
        let bodyVisible = segmentationCoverage > 0.18 || (humanDetected && count >= 4)
        let fullBody = segmentationCoverage > 0.28 || (hasHips && hasAnkles) || (hasKnees && fill > 0.32)

        if !bodyVisible {
            return ScanQualityFeedback(
                isReady: false,
                message: "Recule — tout ton corps doit être visible.",
                score: segmentationCoverage * 100
            )
        }

        if !fullBody {
            return ScanQualityFeedback(
                isReady: false,
                message: "Encore un peu — on doit voir tête, buste et jambes.",
                score: 25 + segmentationCoverage * 80
            )
        }

        if poseMatchScore < 0.45 {
            return ScanQualityFeedback(
                isReady: false,
                message: pose.instruction,
                score: poseMatchScore * 70
            )
        }

        if fill > 0.97 {
            return ScanQualityFeedback(
                isReady: false,
                message: "Trop près — recule d'un pas.",
                score: 40
            )
        }

        let avgConfidence = landmarks.map(\.confidence).reduce(0, +) / Double(max(count, 1))
        let score = min(100, avgConfidence * 35 + fill * 30 + poseMatchScore * 25 + segmentationCoverage * 100 * 0.1 + Double(count) * 2)

        let skeletonReady = count >= 8 && hasHips && (hasKnees || hasAnkles)
        let visionReady = skeletonReady && poseMatchScore >= 0.55 && score >= 42

        if visionReady {
            return ScanQualityFeedback(
                isReady: true,
                message: "Corps détecté — reste immobile, capture auto…",
                score: score
            )
        }

        return ScanQualityFeedback(
            isReady: false,
            message: pose.instruction,
            score: score
        )
    }
}
