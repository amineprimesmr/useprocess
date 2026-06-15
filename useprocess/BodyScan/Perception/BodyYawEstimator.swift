import Foundation

enum BodyYawEstimator {

    /// Coordonnées Vision `.left` + aperçu miroir = repère affiché selfie.
    static func estimateYawDegrees(from landmarks: [BodyLandmark]) -> Double {
        func p(_ name: String) -> BodyLandmark? {
            landmarks.first { $0.name == name && $0.confidence >= 0.2 }
        }

        guard let ls = p("left_shoulder"), let rs = p("right_shoulder") else { return 0 }

        let span = abs(ls.x - rs.x)

        if span > 0.13 {
            guard let nose = p("nose") else { return 0 }
            let midX = (ls.x + rs.x) / 2
            let offset = nose.x - midX
            return max(-35, min(35, offset / max(span * 0.5, 0.04) * 30))
        }

        if span < 0.065 {
            return 175
        }

        return 55
    }

    static func facingLabel(yaw: Double) -> String {
        let a = abs(yaw)
        if a < 25 { return "FACE" }
        if a < 80 { return yaw > 0 ? "DROITE" : "GAUCHE" }
        return "DOS"
    }

    static func shouldCapture(
        currentYaw: Double,
        lastCapturedYaw: Double?,
        minSeparation: Double = 22
    ) -> Bool {
        guard let last = lastCapturedYaw else { return true }
        return abs(normalizedDelta(currentYaw - last)) >= minSeparation
    }

    static func normalizedDelta(_ delta: Double) -> Double {
        var d = delta
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return abs(d)
    }
}
