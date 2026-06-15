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
    let mesh: FaceMesh3DData
    let snapshot: UIImage?
    let averageBlendShapes: [String: Float]
    let yawCoverage: Double
}
