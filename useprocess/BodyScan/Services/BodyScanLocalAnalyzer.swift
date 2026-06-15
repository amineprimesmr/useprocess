import Foundation
import UIKit

enum BodyScanLocalAnalyzer {

    static func analyze(
        captures: [BodyScanCaptureRecord],
        userId: String,
        profile: UnifiedUserProfile?
    ) -> BodyScanResult {
        let metrics = PostureBiomechanics.computeMetrics(from: captures)
        let asymmetries = PostureBiomechanics.detectAsymmetries(metrics: metrics)

        let faceMarkers = mergedFaceMarkers(from: captures)

        let priorities = PostureBiomechanics.musclePriorities(
            metrics: metrics,
            asymmetries: asymmetries,
            face: faceMarkers
        )

        let bodyZones = buildBodyZones(metrics: metrics, priorities: priorities)

        let scanId = UUID().uuidString

        let avgQuality = captures.map(\.qualityScore).reduce(0, +) / Double(max(captures.count, 1))
        let landmarkConfidence = captures.flatMap(\.landmarks).map(\.confidence).reduce(0, +)
            / Double(max(captures.flatMap(\.landmarks).count, 1))
        let turntableBonus = captures.filter { $0.poseKind == .turntable }.count >= 8 ? 0.08 : 0
        let confidence = min(0.97, max(0.45, (avgQuality / 100) * 0.5 + landmarkConfidence * 0.42 + turntableBonus))

        let lifestyle = BodyScanReportBuilder.lifestyleInsights(face: faceMarkers, profile: profile)
        let narrative = BodyScanReportBuilder.build(
            metrics: metrics,
            asymmetries: asymmetries,
            priorities: priorities,
            face: faceMarkers,
            lifestyleInsights: lifestyle,
            confidence: confidence
        )

        return BodyScanResult(
            id: scanId,
            userId: userId,
            createdAt: Date(),
            postureScore: metrics.overallScore,
            confidence: confidence,
            captures: captures,
            metrics: metrics,
            faceMarkers: faceMarkers,
            asymmetries: asymmetries,
            musclePriorities: priorities,
            bodyZones: bodyZones,
            lifestyleInsights: lifestyle,
            narrativeReport: narrative,
            aiEnhanced: false,
            disclaimer: BodyScanResult.wellnessDisclaimer
        )
    }

    static func buildBodyZones(metrics: PostureMetrics, priorities: [MusclePriority]) -> [BodyZoneStatus] {
        let weakNames = Set(priorities.prefix(3).map(\.name))

        func zone(_ name: String, score: Int, weakHint: String) -> BodyZoneStatus {
            let status: ZoneHealthStatus = score >= 75 ? .strong : (score < 58 || weakNames.contains(where: { weakHint.localizedCaseInsensitiveContains($0.prefix(8)) }) ? .weak : .neutral)
            let detail = switch status {
            case .strong: "Zone solide — bon alignement"
            case .neutral: "Zone correcte — à maintenir"
            case .weak: "Zone à renforcer en priorité"
            }
            return BodyZoneStatus(zoneName: name, status: status, detail: detail)
        }

        return [
            zone("Épaules", score: metrics.shoulderAlignmentScore, weakHint: "épaule"),
            zone("Dos / colonne", score: metrics.spineAlignmentScore, weakHint: "dos"),
            zone("Bassin", score: metrics.hipAlignmentScore, weakHint: "bassin"),
            zone("Genoux", score: metrics.kneeAlignmentScore, weakHint: "genou"),
            zone("Symétrie", score: metrics.leftRightSymmetryScore, weakHint: "symétrie"),
            zone("Cou / nuque", score: metrics.spineAlignmentScore, weakHint: "cervical")
        ]
    }

    private static func mergedFaceMarkers(from captures: [BodyScanCaptureRecord]) -> FaceWellnessMarkers? {
        let legacyFace = captures.filter { capture in
            capture.poseKind.isFacePose
                && capture.poseKind != .faceMesh
                && capture.imagePath != nil
        }

        let turntableFace = captures
            .filter { $0.poseKind == .turntable && $0.imagePath != nil }
            .sorted { abs($0.yawDegrees ?? 999) < abs($1.yawDegrees ?? 999) }
            .prefix(6)

        let candidates = legacyFace.isEmpty ? Array(turntableFace) : legacyFace
        guard !candidates.isEmpty else { return nil }

        var puffiness = 0
        var fatigue = 0
        var jaw = 0
        var symmetry = 0
        var clarity = 0
        var notes: [String] = []
        var count = 0

        for capture in candidates {
            guard let path = capture.imagePath,
                  let image = BodyScanImageStore.load(filename: path) else { continue }
            let marker = FaceWellnessAnalyzer.analyze(from: image, pose: capture.poseKind)
            puffiness += marker.puffinessScore
            fatigue += marker.underEyeFatigueScore
            jaw += marker.jawTensionScore
            symmetry += marker.facialSymmetryScore
            clarity += marker.skinClarityScore
            notes.append(contentsOf: marker.notes)
            count += 1
        }

        guard count > 0 else { return nil }
        return FaceWellnessMarkers(
            puffinessScore: puffiness / count,
            underEyeFatigueScore: fatigue / count,
            jawTensionScore: jaw / count,
            facialSymmetryScore: symmetry / count,
            skinClarityScore: clarity / count,
            notes: Array(Set(notes))
        )
    }
}
