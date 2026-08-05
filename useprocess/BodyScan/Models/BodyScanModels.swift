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
        case .turntable: return AppCopy.tSync("Scan 360°", en: "360° scan")
        case .faceMesh: return AppCopy.tSync("Scan visage (legacy)", en: "Face scan (legacy)")
        case .frontStanding: return AppCopy.tSync("Face", en: "Front")
        case .leftProfile: return AppCopy.tSync("Profil gauche", en: "Left profile")
        case .rightProfile: return AppCopy.tSync("Profil droit", en: "Right profile")
        case .backStanding: return AppCopy.tSync("Dos", en: "Back")
        case .frontArmsRaised: return AppCopy.tSync("Bras en T", en: "T-pose arms")
        case .faceFront: return AppCopy.tSync("Visage", en: "Face")
        case .faceLeft, .faceRight: return AppCopy.tSync("Profil visage", en: "Face profile")
        }
    }

    var instruction: String {
        switch self {
        case .turntable:
            return AppCopy.tSync("Tourne lentement sur toi-même", en: "Turn slowly in place")
        case .faceMesh:
            return AppCopy.tSync(
                "Approche ton visage — tourne lentement la tête",
                en: "Move your face closer — slowly turn your head"
            )
        case .frontStanding:
            return AppCopy.tSync(
                "Debout face caméra, bras le long du corps",
                en: "Stand facing the camera, arms at your sides"
            )
        case .leftProfile:
            return AppCopy.tSync(
                "Tourne-toi vers la gauche — profil complet",
                en: "Turn left — full profile"
            )
        case .rightProfile:
            return AppCopy.tSync(
                "Tourne-toi vers la droite — profil complet",
                en: "Turn right — full profile"
            )
        case .backStanding:
            return AppCopy.tSync(
                "Dos à la caméra — bras le long du corps",
                en: "Back to the camera — arms at your sides"
            )
        case .frontArmsRaised:
            return AppCopy.tSync(
                "Face caméra — bras tendus en T",
                en: "Face the camera — arms out in a T"
            )
        case .faceFront:
            return AppCopy.tSync("Centre ton visage dans le cadre", en: "Center your face in the frame")
        case .faceLeft:
            return AppCopy.tSync("Tourne la tête vers la gauche", en: "Turn your head to the left")
        case .faceRight:
            return AppCopy.tSync("Tourne la tête vers la droite", en: "Turn your head to the right")
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

    var instruction: String { AppCopy.tSync("TOURNE SUR TOI", en: "TURN AROUND") }

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

struct FaceWellnessMarkers: nonisolated Codable, Hashable, Sendable {
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
