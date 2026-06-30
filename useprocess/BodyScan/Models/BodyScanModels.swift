import Foundation
import CoreGraphics

// MARK: - Protocole scan 360°

nonisolated enum ScanPoseKind: String, Codable, CaseIterable, Identifiable {
    case turntable
    case faceMesh
    // Legacy (lecture rapports existants)
    case frontStanding, leftProfile, rightProfile, backStanding, frontArmsRaised
    case faceFront, faceLeft, faceRight

    var id: String { rawValue }

    var isFacePose: Bool {
        switch self {
        case .faceMesh, .faceFront, .faceLeft, .faceRight: return true
        default: return false
        }
    }

    var title: String {
        switch self {
        case .turntable: return "Scan 360°"
        case .faceMesh: return "Scan visage (legacy)"
        case .frontStanding: return "Face"
        case .leftProfile: return "Profil gauche"
        case .rightProfile: return "Profil droit"
        case .backStanding: return "Dos"
        case .frontArmsRaised: return "Bras en T"
        case .faceFront: return "Visage"
        case .faceLeft, .faceRight: return "Profil visage"
        }
    }

    var instruction: String {
        switch self {
        case .turntable:
            return "Tourne lentement sur toi-même"
        case .faceMesh:
            return "Approche ton visage — tourne lentement la tête"
        case .frontStanding:
            return "Debout face caméra, bras le long du corps"
        case .leftProfile:
            return "Tourne-toi vers la gauche — profil complet"
        case .rightProfile:
            return "Tourne-toi vers la droite — profil complet"
        case .backStanding:
            return "Dos à la caméra — bras le long du corps"
        case .frontArmsRaised:
            return "Face caméra — bras tendus en T"
        case .faceFront:
            return "Centre ton visage dans le cadre"
        case .faceLeft:
            return "Tourne la tête vers la gauche"
        case .faceRight:
            return "Tourne la tête vers la droite"
        }
    }

    var icon: String {
        switch self {
        case .turntable: return "rotate.3d"
        case .faceMesh: return "faceid"
        case .frontStanding: return "person.fill"
        case .leftProfile: return "person.fill.turn.left"
        case .rightProfile: return "person.fill.turn.right"
        case .backStanding: return "person.fill.turn.down"
        case .frontArmsRaised: return "figure.arms.open"
        case .faceFront: return "face.smiling"
        case .faceLeft: return "person.crop.circle"
        case .faceRight: return "person.crop.circle.fill"
        }
    }
}

enum BodyArmStyle: String, Codable {
    case atSides
    case raised
}

enum BodyTurntablePass: Int, Equatable, Codable {
    case standard = 1
    case armsRaised = 2 // legacy

    static let scanDuration: TimeInterval = 30

    var duration: TimeInterval { Self.scanDuration }

    var instruction: String { "TOURNE SUR TOI" }

    var armStyle: BodyArmStyle { .atSides }
}

// MARK: - Landmarks

struct BodyLandmark: Codable, Hashable {
    let name: String
    let x: Double
    let y: Double
    let confidence: Double
}

struct BodyScanCaptureRecord: Codable, Identifiable, Hashable {
    let id: String
    let poseKind: ScanPoseKind
    let capturedAt: Date
    let qualityScore: Double
    let landmarks: [BodyLandmark]
    let imagePath: String?
    var yawDegrees: Double?
    var armStyle: BodyArmStyle?

    enum CodingKeys: String, CodingKey {
        case id, poseKind, capturedAt, qualityScore, landmarks, imagePath
        case yawDegrees, armStyle
    }

    init(
        id: String,
        poseKind: ScanPoseKind,
        capturedAt: Date,
        qualityScore: Double,
        landmarks: [BodyLandmark],
        imagePath: String?,
        yawDegrees: Double? = nil,
        armStyle: BodyArmStyle? = nil
    ) {
        self.id = id
        self.poseKind = poseKind
        self.capturedAt = capturedAt
        self.qualityScore = qualityScore
        self.landmarks = landmarks
        self.imagePath = imagePath
        self.yawDegrees = yawDegrees
        self.armStyle = armStyle
    }
}

// MARK: - Métriques

struct PostureMetrics: Codable, Hashable {
    var overallScore: Int
    var shoulderAlignmentScore: Int
    var hipAlignmentScore: Int
    var spineAlignmentScore: Int
    var kneeAlignmentScore: Int
    var leftRightSymmetryScore: Int
    var shoulderTiltDegrees: Double?
    var hipTiltDegrees: Double?
    var forwardHeadDegrees: Double?
    var kneeValgusIndicator: Double?
}

struct FaceWellnessMarkers: Codable, Hashable {
    var puffinessScore: Int
    var underEyeFatigueScore: Int
    var jawTensionScore: Int
    var facialSymmetryScore: Int
    var skinClarityScore: Int
    /// Score 0–100 — plus haut = visage plus défini (mâchoire / pommettes vs rétention).
    var faceDefinitionScore: Int? = nil
    var notes: [String]
}

struct MusclePriority: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let reason: String
    let priority: Int
}

struct BodyZoneStatus: Codable, Hashable, Identifiable {
    var id: String { zoneName }
    let zoneName: String
    let status: ZoneHealthStatus
    let detail: String
}

enum ZoneHealthStatus: String, Codable {
    case strong
    case neutral
    case weak
}

// MARK: - Résultat

struct BodyScanResult: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let createdAt: Date
    let postureScore: Int
    let confidence: Double
    let captures: [BodyScanCaptureRecord]
    let metrics: PostureMetrics
    let faceMarkers: FaceWellnessMarkers?
    let asymmetries: [String]
    let musclePriorities: [MusclePriority]
    var bodyZones: [BodyZoneStatus]
    let lifestyleInsights: [String]
    let narrativeReport: String
    let aiEnhanced: Bool
    let disclaimer: String

    static let wellnessDisclaimer =
        "Estimation bien-être uniquement — ne remplace pas un avis médical, kinésithérapeutique ou dermatologique. Voir les sources dans l'onglet Santé."

    enum CodingKeys: String, CodingKey {
        case id, userId, createdAt, postureScore, confidence, captures, metrics
        case faceMarkers, asymmetries, musclePriorities, bodyZones
        case lifestyleInsights, narrativeReport, aiEnhanced, disclaimer
    }
}

enum BodyScanPhase: Equatable {
    case intro
    case permissions
    case bodyTurntable(BodyTurntablePass)
    case analyzing
    case report(BodyScanResult)
    case error(String)
}

struct ScanQualityFeedback: Equatable {
    let isReady: Bool
    let message: String
    let score: Double
}
