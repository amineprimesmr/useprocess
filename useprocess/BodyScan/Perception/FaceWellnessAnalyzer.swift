import ARKit
import Foundation
import UIKit
import Vision

enum FaceWellnessAnalyzer {

    // MARK: - Capture complète (mesh + photo + blend shapes)

    static func analyze(from capture: FaceScanCapturePayload, pose: ScanPoseKind = .faceMesh) -> FaceWellnessMarkers {
        guard capture.mesh.isValid else {
            return markers(
                puffiness: 50, fatigue: 50, jaw: 50, symmetry: 50, clarity: 50,
                notes: ["Scan 3D incomplet — approche ton visage et réessaie."]
            )
        }

        let mesh = capture.mesh
        let shapes = capture.averageBlendShapes

        var symmetry = estimateMeshSymmetry(mesh)
        var clarity = estimateSkinClarity(from: capture.snapshot) ?? 72
        var puffiness = estimateMeshPuffiness(mesh, shapes: shapes)
        var fatigue = estimateUnderEyeFatigue(mesh, shapes: shapes, clarity: clarity)
        var jaw = estimateJawProjection(mesh, shapes: shapes, symmetry: symmetry)

        if let image = capture.snapshot {
            let imageMarkers = analyze(from: image, pose: pose)
            clarity = (clarity + imageMarkers.skinClarityScore) / 2
            fatigue = (fatigue + imageMarkers.underEyeFatigueScore) / 2
            puffiness = (puffiness + imageMarkers.puffinessScore) / 2
            symmetry = (symmetry + imageMarkers.facialSymmetryScore) / 2
            jaw = (jaw + imageMarkers.jawTensionScore) / 2
        }

        var notes: [String] = []
        if capture.yawCoverage >= 0.7 {
            notes.append("Scan 3D multi-angles capturé (\(Int(capture.yawCoverage * 100)) % du cercle).")
        } else {
            notes.append("Scan 3D capturé — couverture angulaire partielle.")
        }

        appendWellnessNotes(fatigue: fatigue, puffiness: puffiness, jaw: jaw, into: &notes)
        appendAdvancedNotes(
            fatigue: fatigue, puffiness: puffiness, jaw: jaw,
            symmetry: symmetry, clarity: clarity, mesh: mesh, into: &notes
        )

        return markers(
            puffiness: puffiness,
            fatigue: fatigue,
            jaw: jaw,
            symmetry: symmetry,
            clarity: clarity,
            notes: notes
        )
    }

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
            return markers(puffiness: 50, fatigue: 50, jaw: 50, symmetry: 50, clarity: 50, notes: notes)
        }

        if let quality = faceRequest.results?.first?.faceCaptureQuality {
            qualityScore = Double(quality)
        }

        if let face = landmarksRequest.results?.first {
            symmetryScore = estimateSymmetry(face: face)
        }

        let clarity = clampedInt(qualityScore * 100, min: 35, max: 95)
        let fatigue = estimateFatigue(clarity: clarity, symmetry: symmetryScore)
        let puffiness = estimatePuffiness(pose: pose, clarity: clarity)
        let jaw = estimateJawTension(symmetry: symmetryScore)

        return markers(puffiness: puffiness, fatigue: fatigue, jaw: jaw, symmetry: symmetryScore, clarity: clarity, notes: notes)
    }

    static func analyze(from mesh: FaceMesh3DData, pose: ScanPoseKind = .faceMesh) -> FaceWellnessMarkers {
        analyze(from: FaceScanCapturePayload(
            scanId: UUID().uuidString,
            mesh: mesh,
            snapshot: nil,
            videoFilename: nil,
            averageBlendShapes: [:],
            yawCoverage: 0.5
        ), pose: pose)
    }

    // MARK: - Mesh heuristics

    private static func estimateMeshPuffiness(_ mesh: FaceMesh3DData, shapes: [String: Float]) -> Int {
        let cheekPuff = Double(shapes[ARFaceAnchor.BlendShapeLocation.cheekPuff.rawValue] ?? 0)
        let widthRatio = meshWidthRatio(mesh, atY: -0.02)
        let score = 42.0 + widthRatio * 55.0 + cheekPuff * 35.0
        return Int(max(28, min(88, score)))
    }

    private static func estimateUnderEyeFatigue(_ mesh: FaceMesh3DData, shapes: [String: Float], clarity: Int) -> Int {
        let squint = Double(shapes[ARFaceAnchor.BlendShapeLocation.eyeSquintLeft.rawValue] ?? 0)
            + Double(shapes[ARFaceAnchor.BlendShapeLocation.eyeSquintRight.rawValue] ?? 0)
        let browDown = Double(shapes[ARFaceAnchor.BlendShapeLocation.browDownLeft.rawValue] ?? 0)
            + Double(shapes[ARFaceAnchor.BlendShapeLocation.browDownRight.rawValue] ?? 0)
        let underEyeDepth = meshUnderEyeDepthDelta(mesh)
        let score = 38.0 + underEyeDepth * 40.0 + squint * 25.0 + browDown * 20.0 + Double(70 - clarity) * 0.35
        return Int(max(25, min(92, score)))
    }

    private static func estimateJawProjection(_ mesh: FaceMesh3DData, shapes: [String: Float], symmetry: Int) -> Int {
        let jawOpen = Double(shapes[ARFaceAnchor.BlendShapeLocation.jawOpen.rawValue] ?? 0)
        let frown = Double(shapes[ARFaceAnchor.BlendShapeLocation.mouthFrownLeft.rawValue] ?? 0)
            + Double(shapes[ARFaceAnchor.BlendShapeLocation.mouthFrownRight.rawValue] ?? 0)
        let jawWidth = meshWidthRatio(mesh, atY: -0.08)
        let score = 48.0 + jawWidth * 30.0 + jawOpen * 15.0 + frown * 22.0 + Double(75 - symmetry) * 0.2
        return Int(max(30, min(85, score)))
    }

    private static func meshWidthRatio(_ mesh: FaceMesh3DData, atY yTarget: Float) -> Double {
        let count = mesh.vertices.count / 3
        guard count > 20 else { return 0.5 }
        var minX: Float = 1, maxX: Float = -1
        for i in 0..<count {
            let y = mesh.vertices[i * 3 + 1]
            guard abs(y - yTarget) < 0.025 else { continue }
            let x = mesh.vertices[i * 3]
            minX = min(minX, x)
            maxX = max(maxX, x)
        }
        guard maxX > minX else { return 0.5 }
        return Double(maxX - minX) / 0.14
    }

    private static func meshUnderEyeDepthDelta(_ mesh: FaceMesh3DData) -> Double {
        let count = mesh.vertices.count / 3
        guard count > 20 else { return 0.4 }
        var eyeZ: Float = 0, eyeN = 0
        var cheekZ: Float = 0, cheekN = 0
        for i in 0..<count {
            let x = mesh.vertices[i * 3]
            let y = mesh.vertices[i * 3 + 1]
            let z = mesh.vertices[i * 3 + 2]
            if y > 0.02 && y < 0.06 && abs(x) > 0.02 {
                eyeZ += z; eyeN += 1
            } else if y > -0.02 && y < 0.02 && abs(x) > 0.04 {
                cheekZ += z; cheekN += 1
            }
        }
        guard eyeN > 0, cheekN > 0 else { return 0.4 }
        return Double(abs((eyeZ / Float(eyeN)) - (cheekZ / Float(cheekN)))) * 8.0
    }

    private static func estimateSkinClarity(from image: UIImage?) -> Int? {
        guard let image, let cg = image.cgImage else { return nil }
        let request = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        guard (try? handler.perform([request])) != nil,
              let q = request.results?.first?.faceCaptureQuality else { return nil }
        return clampedInt(Double(q) * 100, min: 35, max: 96)
    }

    private static func appendAdvancedNotes(
        fatigue: Int, puffiness: Int, jaw: Int,
        symmetry: Int, clarity: Int, mesh: FaceMesh3DData,
        into notes: inout [String]
    ) {
        let cheekHollow = meshCheekHollowness(mesh)
        if cheekHollow > 0.55 {
            notes.append("Joues légèrement creusées — sommeil, nutrition ou hydratation à surveiller.")
        }
        if clarity < 55 {
            notes.append("Texture de peau en baisse — sommeil, stress (cortisol) ou routine skincare.")
        }
        if fatigue > 68 && puffiness > 62 {
            notes.append("Profil compatible rétention d'eau + fatigue (cernes / gonflement).")
        }
        if jaw > 65 && symmetry < 58 {
            notes.append("Tension mâchoire + alignement de scan irrégulier — bruxisme, posture ou stress chronique possibles.")
        }
    }

    private static func meshCheekHollowness(_ mesh: FaceMesh3DData) -> Double {
        let midDepth = meshAverageZ(mesh, yRange: -0.01...0.03, xRange: -0.02...0.02)
        let cheekDepth = meshAverageZ(mesh, yRange: -0.04...0.0, xRange: 0.05...0.12)
        guard let mid = midDepth, let cheek = cheekDepth else { return 0.4 }
        return Double(max(0, mid - cheek)) * 6.0
    }

    private static func meshAverageZ(_ mesh: FaceMesh3DData, yRange: ClosedRange<Float>, xRange: ClosedRange<Float>) -> Float? {
        let count = mesh.vertices.count / 3
        var sum: Float = 0
        var n = 0
        for i in 0..<count {
            let x = mesh.vertices[i * 3]
            let y = mesh.vertices[i * 3 + 1]
            let z = mesh.vertices[i * 3 + 2]
            guard yRange.contains(y), xRange.contains(abs(x)) else { continue }
            sum += z; n += 1
        }
        return n > 0 ? sum / Float(n) : nil
    }

    // MARK: - Shared helpers

    private static func neutralMarkers() -> FaceWellnessMarkers {
        markers(puffiness: 50, fatigue: 50, jaw: 50, symmetry: 50, clarity: 50, notes: [])
    }

    private static func markers(
        puffiness: Int, fatigue: Int, jaw: Int, symmetry: Int, clarity: Int, notes: [String]
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

    private static func appendWellnessNotes(fatigue: Int, puffiness: Int, jaw: Int, into notes: inout [String]) {
        if fatigue > 65 { notes.append("Signaux compatibles avec une fatigue perçue (cernes / regard).") }
        if puffiness > 60 { notes.append("Léger gonflement perçu — hydratation, sel, sommeil et stress.") }
        if jaw > 62 { notes.append("Tension mandibulaire possible — stress ou mâchoire serrée.") }
    }

    private static func clampedInt(_ value: Double, min: Int, max: Int) -> Int {
        Int(Swift.min(Double(max), Swift.max(Double(min), value)))
    }

    private static func estimateSymmetry(face: VNFaceObservation) -> Int {
        guard let landmarks = face.landmarks,
              let leftEye = landmarks.leftEye?.normalizedPoints, !leftEye.isEmpty,
              let rightEye = landmarks.rightEye?.normalizedPoints, !rightEye.isEmpty else { return 65 }

        let leftY = leftEye.reduce(0) { $0 + $1.y } / CGFloat(leftEye.count)
        let rightY = rightEye.reduce(0) { $0 + $1.y } / CGFloat(rightEye.count)
        let score = 90.0 - abs(Double(leftY - rightY)) * 400.0
        return Int(max(40, min(95, score)))
    }

    private static func estimateFatigue(clarity: Int, symmetry: Int) -> Int {
        Int(max(25, min(90, 100.0 - Double(clarity) * 0.45 - Double(symmetry) * 0.15)))
    }

    private static func estimatePuffiness(pose: ScanPoseKind, clarity: Int) -> Int {
        Int(max(30, min(85, (pose == .faceFront ? 52.0 : 48.0) + Double(65 - clarity) * 0.35)))
    }

    private static func estimateJawTension(symmetry: Int) -> Int {
        Int(max(30, min(80, 75.0 - Double(symmetry) * 0.25)))
    }

    private static func estimateMeshSymmetry(_ mesh: FaceMesh3DData) -> Int {
        let count = mesh.vertices.count / 3
        guard count >= 30 else { return 65 }
        var leftY: Float = 0, rightY: Float = 0, leftN = 0, rightN = 0
        for i in 0..<count {
            let x = mesh.vertices[i * 3], y = mesh.vertices[i * 3 + 1]
            if x < -0.01 { leftY += y; leftN += 1 }
            else if x > 0.01 { rightY += y; rightN += 1 }
        }
        guard leftN > 0, rightN > 0 else { return 68 }
        let score = 90.0 - abs(Double((leftY / Float(leftN)) - (rightY / Float(rightN)))) * 120.0
        return Int(max(42, min(94, score)))
    }
}
