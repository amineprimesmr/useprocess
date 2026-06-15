import Foundation
import Vision

/// Résultat d'analyse d'une frame caméra (Vision + segmentation Apple).
struct BodyPoseAnalysis: Equatable {
    let landmarks: [BodyLandmark]
    let segmentationCoverage: Double
    let humanDetected: Bool
    let poseMatchScore: Double
    let feedback: ScanQualityFeedback

    static let empty = BodyPoseAnalysis(
        landmarks: [],
        segmentationCoverage: 0,
        humanDetected: false,
        poseMatchScore: 0,
        feedback: ScanQualityFeedback(isReady: false, message: "Initialisation…", score: 0)
    )
}

/// Connexions du squelette Apple (VNHumanBodyPoseObservation).
nonisolated enum BodySkeletonTopology {
    static let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.nose, .neck),
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.leftShoulder, .rightShoulder),
        (.leftHip, .rightHip)
    ]

    static let jointNames: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .neck,
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .root, .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle
    ]
}
