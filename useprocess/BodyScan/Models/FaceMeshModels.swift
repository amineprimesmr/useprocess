import Foundation
import UIKit

struct FaceMesh3DData: Codable, Hashable {
    var vertices: [Float]
    var triangleIndices: [Int]
    var textureCoordinates: [Float]

    static let empty = FaceMesh3DData(vertices: [], triangleIndices: [], textureCoordinates: [])

    var isValid: Bool {
        vertices.count >= 9 && triangleIndices.count >= 3
    }
}

struct OnboardingFaceScanPayload: Codable, Hashable {
    var markers: FaceWellnessMarkers
    var mesh: FaceMesh3DData
}

/// Données brutes capturées à la fin du scan Face ID.
struct FaceScanCapturePayload: Sendable {
    let scanId: String
    let mesh: FaceMesh3DData
    let snapshot: UIImage?
    let videoFilename: String?
    let averageBlendShapes: [String: Float]
    let yawCoverage: Double
}

// MARK: - Historique scan visage (Santé)

enum FaceScanSource: String, Codable {
    case onboarding
    case daily
}

struct FaceScanResult: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let createdAt: Date
    let markers: FaceWellnessMarkers
    var snapshotFilename: String?
    var videoFilename: String?
    var claudeAnalysis: String?
    var aiEnhanced: Bool
    var source: FaceScanSource
    var sleepHoursAtScan: Double?
    var hrvAtScan: Double?
    var faceDayScore: Int?
    /// Version 2 : score relatif à la baseline personnelle, pas à la forme naturelle du visage.
    var relativeFaceDayScore: Int?
    var scanConfidence: Int?
    var baselineSampleCount: Int?
    var relativeSignals: FaceScanRelativeSignals?

    var resolvedFaceDayScore: Int {
        relativeFaceDayScore ?? faceDayScore ?? FaceWellnessScore.dayScore(from: markers)
    }

    /// Score global unique affiché dans l’UI (accueil, historique, anneau WHOOP).
    /// Moyenne pondérée des 5 indicateurs wellness — aligné sur l’écran d’analyse.
    var displayWellnessScore: Int {
        FaceScanIndicators.compositeWellnessScore(for: self)
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        createdAt: Date = Date(),
        markers: FaceWellnessMarkers,
        snapshotFilename: String? = nil,
        videoFilename: String? = nil,
        claudeAnalysis: String? = nil,
        aiEnhanced: Bool = false,
        source: FaceScanSource = .daily,
        sleepHoursAtScan: Double? = nil,
        hrvAtScan: Double? = nil,
        faceDayScore: Int? = nil,
        relativeFaceDayScore: Int? = nil,
        scanConfidence: Int? = nil,
        baselineSampleCount: Int? = nil,
        relativeSignals: FaceScanRelativeSignals? = nil
    ) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.markers = markers
        self.snapshotFilename = snapshotFilename
        self.videoFilename = videoFilename
        self.claudeAnalysis = claudeAnalysis
        self.aiEnhanced = aiEnhanced
        self.source = source
        self.sleepHoursAtScan = sleepHoursAtScan
        self.hrvAtScan = hrvAtScan
        self.faceDayScore = faceDayScore
        self.relativeFaceDayScore = relativeFaceDayScore
        self.scanConfidence = scanConfidence
        self.baselineSampleCount = baselineSampleCount
        self.relativeSignals = relativeSignals
    }

    func delta(from previous: FaceScanResult) -> FaceScanTrend {
        FaceScanTrend(
            puffiness: markers.puffinessScore - previous.markers.puffinessScore,
            underEyeFatigue: markers.underEyeFatigueScore - previous.markers.underEyeFatigueScore,
            jawTension: markers.jawTensionScore - previous.markers.jawTensionScore,
            skinClarity: markers.skinClarityScore - previous.markers.skinClarityScore,
            facialSymmetry: markers.facialSymmetryScore - previous.markers.facialSymmetryScore
        )
    }
}

struct FaceScanRelativeSignals: Codable, Hashable {
    var puffinessDelta: Int
    var underEyeFatigueDelta: Int
    var jawTensionDelta: Int
    var skinClarityDelta: Int
    var faceDefinitionDelta: Int? = nil
    var stressLoadDelta: Int? = nil
    var baselineLabel: String

    var hasMeaningfulChange: Bool {
        abs(puffinessDelta) >= 4
            || abs(underEyeFatigueDelta) >= 4
            || abs(jawTensionDelta) >= 4
            || abs(skinClarityDelta) >= 4
            || abs(faceDefinitionDelta ?? 0) >= 4
            || abs(stressLoadDelta ?? 0) >= 4
    }
}

struct FaceScanTrend: Hashable {
    let puffiness: Int
    let underEyeFatigue: Int
    let jawTension: Int
    let skinClarity: Int
    let facialSymmetry: Int
}
