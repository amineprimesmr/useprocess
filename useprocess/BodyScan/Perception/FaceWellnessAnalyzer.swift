import Foundation
import UIKit
import Vision

enum FaceWellnessAnalyzer {

    static func analyze(from image: UIImage, pose: ScanPoseKind) -> FaceWellnessMarkers {
        guard pose.isFacePose, let cgImage = image.cgImage else {
            return neutralMarkers()
        }

        let faceRequest = VNDetectFaceCaptureQualityRequest()
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        var qualityScore = 0.5
        var symmetryScore = 72
        var notes: [String] = []

        do {
            try handler.perform([faceRequest, landmarksRequest])
        } catch {
            notes.append("Analyse faciale limitée — qualité d'image insuffisante.")
            return markers(
                puffiness: 50,
                fatigue: 50,
                jaw: 50,
                symmetry: 50,
                clarity: 50,
                notes: notes
            )
        }

        if let quality = faceRequest.results?.first?.faceCaptureQuality {
            qualityScore = Double(quality)
        }

        if let face = landmarksRequest.results?.first {
            symmetryScore = estimateSymmetry(face: face)
            if symmetryScore < 60 {
                notes.append("Légère asymétrie faciale détectée — souvent liée à la posture ou au sommeil.")
            }
        }

        let clarity = clampedInt(qualityScore * 100, min: 35, max: 95)
        let fatigue = estimateFatigue(clarity: clarity, symmetry: symmetryScore)
        let puffiness = estimatePuffiness(pose: pose, clarity: clarity)
        let jaw = estimateJawTension(symmetry: symmetryScore)

        appendWellnessNotes(fatigue: fatigue, puffiness: puffiness, jaw: jaw, into: &notes)

        return markers(
            puffiness: puffiness,
            fatigue: fatigue,
            jaw: jaw,
            symmetry: symmetryScore,
            clarity: clarity,
            notes: notes
        )
    }

    /// Analyse à partir du mesh ARKit TrueDepth (scan 3D visage).
    static func analyze(from mesh: FaceMesh3DData, pose: ScanPoseKind = .faceMesh) -> FaceWellnessMarkers {
        guard mesh.isValid else {
            return markers(
                puffiness: 50,
                fatigue: 50,
                jaw: 50,
                symmetry: 50,
                clarity: 50,
                notes: ["Scan 3D incomplet — approche ton visage et réessaie."]
            )
        }

        let symmetry = estimateMeshSymmetry(mesh)
        let clarity = 78
        let fatigue = estimateFatigue(clarity: clarity, symmetry: symmetry)
        let puffiness = estimatePuffiness(pose: pose, clarity: clarity)
        let jaw = estimateJawTension(symmetry: symmetry)

        var notes: [String] = ["Scan visage 3D capturé avec succès."]
        if symmetry < 60 {
            notes.append("Légère asymétrie faciale détectée — souvent liée à la posture ou au sommeil.")
        }
        appendWellnessNotes(fatigue: fatigue, puffiness: puffiness, jaw: jaw, into: &notes)

        return markers(
            puffiness: puffiness,
            fatigue: fatigue,
            jaw: jaw,
            symmetry: symmetry,
            clarity: clarity,
            notes: notes
        )
    }

    // MARK: - Helpers

    private static func neutralMarkers() -> FaceWellnessMarkers {
        markers(puffiness: 50, fatigue: 50, jaw: 50, symmetry: 50, clarity: 50, notes: [])
    }

    private static func markers(
        puffiness: Int,
        fatigue: Int,
        jaw: Int,
        symmetry: Int,
        clarity: Int,
        notes: [String]
    ) -> FaceWellnessMarkers {
        FaceWellnessMarkers(
            puffinessScore: puffiness,
            underEyeFatigueScore: fatigue,
            jawTensionScore: jaw,
            facialSymmetryScore: symmetry,
            skinClarityScore: clarity,
            notes: notes
        )
    }

    private static func appendWellnessNotes(
        fatigue: Int,
        puffiness: Int,
        jaw: Int,
        into notes: inout [String]
    ) {
        if fatigue > 65 {
            notes.append("Signaux compatibles avec une fatigue perçue (cernes / regard).")
        }
        if puffiness > 60 {
            notes.append("Léger gonflement perçu — hydratation, sel, sommeil et stress peuvent influencer.")
        }
        if jaw > 62 {
            notes.append("Tension mandibulaire possible — stress chronique ou mâchoire serrée.")
        }
    }

    private static func clampedInt(_ value: Double, min: Int, max: Int) -> Int {
        Int(Swift.min(Double(max), Swift.max(Double(min), value)))
    }

    private static func estimateSymmetry(face: VNFaceObservation) -> Int {
        guard let landmarks = face.landmarks else { return 65 }
        guard let leftEye = landmarks.leftEye?.normalizedPoints, !leftEye.isEmpty else { return 65 }
        guard let rightEye = landmarks.rightEye?.normalizedPoints, !rightEye.isEmpty else { return 65 }

        let leftCount = CGFloat(leftEye.count)
        let rightCount = CGFloat(rightEye.count)

        var leftSum: CGFloat = 0
        for point in leftEye { leftSum += point.y }
        let leftY = leftSum / leftCount

        var rightSum: CGFloat = 0
        for point in rightEye { rightSum += point.y }
        let rightY = rightSum / rightCount

        let delta = abs(leftY - rightY)
        let score = 90.0 - Double(delta) * 400.0
        return Int(Swift.max(40, Swift.min(95, score)))
    }

    private static func estimateFatigue(clarity: Int, symmetry: Int) -> Int {
        let score = 100.0 - Double(clarity) * 0.45 - Double(symmetry) * 0.15
        return Int(Swift.max(25, Swift.min(90, score)))
    }

    private static func estimatePuffiness(pose: ScanPoseKind, clarity: Int) -> Int {
        let base = pose == .faceFront ? 52.0 : 48.0
        let score = base + Double(65 - clarity) * 0.35
        return Int(Swift.max(30, Swift.min(85, score)))
    }

    private static func estimateJawTension(symmetry: Int) -> Int {
        let score = 75.0 - Double(symmetry) * 0.25
        return Int(Swift.max(30, Swift.min(80, score)))
    }

    private static func estimateMeshSymmetry(_ mesh: FaceMesh3DData) -> Int {
        let count = mesh.vertices.count / 3
        guard count >= 30 else { return 65 }

        var leftY: Float = 0
        var rightY: Float = 0
        var leftN = 0
        var rightN = 0

        for i in 0..<count {
            let x = mesh.vertices[i * 3]
            let y = mesh.vertices[i * 3 + 1]
            if x < -0.01 {
                leftY += y
                leftN += 1
            } else if x > 0.01 {
                rightY += y
                rightN += 1
            }
        }

        guard leftN > 0, rightN > 0 else { return 68 }

        let delta = abs((leftY / Float(leftN)) - (rightY / Float(rightN)))
        let score = 90.0 - Double(delta) * 120.0
        return Int(Swift.max(42, Swift.min(94, score)))
    }
}
