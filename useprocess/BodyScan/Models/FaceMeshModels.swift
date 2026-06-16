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

    var resolvedFaceDayScore: Int {
        faceDayScore ?? FaceWellnessScore.dayScore(from: markers)
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
        faceDayScore: Int? = nil
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

struct FaceScanTrend: Hashable {
    let puffiness: Int
    let underEyeFatigue: Int
    let jawTension: Int
    let skinClarity: Int
    let facialSymmetry: Int
}
