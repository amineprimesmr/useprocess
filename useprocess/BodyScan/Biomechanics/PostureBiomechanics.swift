import Foundation

enum PostureBiomechanics {

    static func computeMetrics(from captures: [BodyScanCaptureRecord]) -> PostureMetrics {
        let turntable = captures.filter { $0.poseKind == .turntable }

        let front = captures.first { $0.poseKind == .frontStanding }
            ?? turntable.min(by: { abs($0.yawDegrees ?? 999) < abs($1.yawDegrees ?? 999) })
        let left = captures.first { $0.poseKind == .leftProfile }
            ?? turntable.filter { ($0.yawDegrees ?? 0) < -35 }
                .max(by: { abs($0.yawDegrees ?? 0) < abs($1.yawDegrees ?? 0) })
        let right = captures.first { $0.poseKind == .rightProfile }
            ?? turntable.filter { ($0.yawDegrees ?? 0) > 35 }
                .max(by: { abs($0.yawDegrees ?? 0) < abs($1.yawDegrees ?? 0) })
        let armsT = captures.first { $0.poseKind == .frontArmsRaised }
            ?? turntable.first { $0.armStyle == .raised }

        let shoulderTilt = shoulderTiltDegrees(from: front?.landmarks ?? armsT?.landmarks ?? [])
        let hipTilt = hipTiltDegrees(from: front?.landmarks ?? [])
        let forwardHead = forwardHeadDegrees(from: left?.landmarks ?? right?.landmarks ?? front?.landmarks ?? [])
        let kneeValgus = kneeAlignmentIndicator(from: front?.landmarks ?? [])

        let shoulderScore = scoreFromTilt(shoulderTilt, ideal: 0, tolerance: 4)
        let hipScore = scoreFromTilt(hipTilt, ideal: 0, tolerance: 5)
        let spineScore = scoreFromAngle(forwardHead, ideal: 8, tolerance: 12)
        let kneeScore = scoreFromDeviation(kneeValgus, tolerance: 0.08)
        let symmetryScore = symmetryFrom(left: left?.landmarks ?? [], right: right?.landmarks ?? [])

        let overall = weightedAverage([
            (shoulderScore, 0.22),
            (hipScore, 0.18),
            (spineScore, 0.25),
            (kneeScore, 0.15),
            (symmetryScore, 0.20)
        ])

        return PostureMetrics(
            overallScore: overall,
            shoulderAlignmentScore: shoulderScore,
            hipAlignmentScore: hipScore,
            spineAlignmentScore: spineScore,
            kneeAlignmentScore: kneeScore,
            leftRightSymmetryScore: symmetryScore,
            shoulderTiltDegrees: shoulderTilt,
            hipTiltDegrees: hipTilt,
            forwardHeadDegrees: forwardHead,
            kneeValgusIndicator: kneeValgus
        )
    }

    static func detectAsymmetries(metrics: PostureMetrics) -> [String] {
        var items: [String] = []

        if let tilt = metrics.shoulderTiltDegrees, abs(tilt) > 3 {
            let side = tilt > 0
                ? AppCopy.tSync("droite", en: "right")
                : AppCopy.tSync("gauche", en: "left")
            items.append(AppCopy.tSync(
                "Épaule \(side) légèrement plus haute (\(String(format: "%.1f", abs(tilt)))°)",
                en: "\(side.capitalized) shoulder slightly higher (\(String(format: "%.1f", abs(tilt)))°)"
            ))
        }
        if let tilt = metrics.hipTiltDegrees, abs(tilt) > 4 {
            let side = tilt > 0
                ? AppCopy.tSync("droite", en: "right")
                : AppCopy.tSync("gauche", en: "left")
            items.append(AppCopy.tSync(
                "Bassin incliné vers la \(side)",
                en: "Hips tilting toward the \(side)"
            ))
        }
        if let head = metrics.forwardHeadDegrees, head > 14 {
            items.append(AppCopy.tSync(
                "Tête en avant — posture défensive fréquente (écrans, stress)",
                en: "Forward head — common defensive posture (screens, stress)"
            ))
        }
        if let knee = metrics.kneeValgusIndicator, knee > 0.07 {
            items.append(AppCopy.tSync(
                "Genoux légèrement vers l'intérieur en appui",
                en: "Knees slightly inward when standing"
            ))
        }
        if metrics.leftRightSymmetryScore < 62 {
            items.append(AppCopy.tSync(
                "Asymétrie gauche/droite notable sur les profils",
                en: "Notable left/right asymmetry on the profiles"
            ))
        }

        return items
    }

    static func musclePriorities(
        metrics: PostureMetrics,
        asymmetries: [String],
        face: FaceWellnessMarkers?
    ) -> [MusclePriority] {
        var priorities: [MusclePriority] = []

        if (metrics.forwardHeadDegrees ?? 0) > 12 {
            priorities.append(MusclePriority(
                name: AppCopy.tSync("Fléchisseurs cervicaux profonds", en: "Deep cervical flexors"),
                reason: AppCopy.tSync("Réduire la tête en avant et soulager la nuque", en: "Reduce forward head and ease the neck"),
                priority: 1
            ))
            priorities.append(MusclePriority(
                name: AppCopy.tSync("Trapèzes inférieurs / rhomboïdes", en: "Lower traps / rhomboids"),
                reason: AppCopy.tSync("Ouvrir la poitrine et stabiliser les omoplates", en: "Open the chest and stabilize the shoulder blades"),
                priority: 2
            ))
        }

        if abs(metrics.shoulderTiltDegrees ?? 0) > 3 || metrics.shoulderAlignmentScore < 70 {
            priorities.append(MusclePriority(
                name: AppCopy.tSync("Deltoïde postérieur & milieu du dos", en: "Rear deltoid & mid-back"),
                reason: AppCopy.tSync("Rééquilibrer les épaules", en: "Rebalance the shoulders"),
                priority: priorities.count + 1
            ))
        }

        if (metrics.hipTiltDegrees ?? 0).magnitude > 4 || metrics.hipAlignmentScore < 68 {
            priorities.append(MusclePriority(
                name: AppCopy.tSync("Fessiers & abdominaux profonds", en: "Glutes & deep core"),
                reason: AppCopy.tSync("Stabiliser le bassin", en: "Stabilize the hips"),
                priority: priorities.count + 1
            ))
        }

        if (metrics.kneeValgusIndicator ?? 0) > 0.06 {
            priorities.append(MusclePriority(
                name: AppCopy.tSync("Moyen fessier & rotateurs externes de hanche", en: "Glute medius & hip external rotators"),
                reason: AppCopy.tSync("Aligner genoux et chevilles", en: "Align knees and ankles"),
                priority: priorities.count + 1
            ))
        }

        if metrics.leftRightSymmetryScore < 65 {
            priorities.append(MusclePriority(
                name: AppCopy.tSync("Chaîne postérieure (ischio-jambiers, lombaires)", en: "Posterior chain (hamstrings, lower back)"),
                reason: AppCopy.tSync("Harmoniser gauche/droite", en: "Balance left and right"),
                priority: priorities.count + 1
            ))
        }

        if let face, face.jawTensionScore > 60 {
            priorities.append(MusclePriority(
                name: AppCopy.tSync("Respiration diaphragmatique & relâchement mâchoire", en: "Diaphragmatic breathing & jaw release"),
                reason: AppCopy.tSync("Réduire la tension liée au stress", en: "Reduce stress-related tension"),
                priority: priorities.count + 1
            ))
        }

        if priorities.isEmpty {
            priorities.append(MusclePriority(
                name: AppCopy.tSync("Maintien global & mobilité", en: "Overall support & mobility"),
                reason: AppCopy.tSync("Posture déjà équilibrée — consolider et progresser", en: "Posture already balanced — consolidate and progress"),
                priority: 1
            ))
        }

        return Array(priorities.prefix(6))
    }

    // MARK: - Géométrie

    private static func landmark(_ name: String, in landmarks: [BodyLandmark]) -> BodyLandmark? {
        landmarks.first { $0.name == name }
    }

    private static func shoulderTiltDegrees(from landmarks: [BodyLandmark]) -> Double? {
        guard let left = landmark("left_shoulder", in: landmarks),
              let right = landmark("right_shoulder", in: landmarks) else { return nil }
        let dy = (left.y - right.y)
        let dx = max(0.001, abs(left.x - right.x))
        return atan2(dy, dx) * 180 / .pi
    }

    private static func hipTiltDegrees(from landmarks: [BodyLandmark]) -> Double? {
        guard let left = landmark("left_hip", in: landmarks),
              let right = landmark("right_hip", in: landmarks) else { return nil }
        let dy = left.y - right.y
        let dx = max(0.001, abs(left.x - right.x))
        return atan2(dy, dx) * 180 / .pi
    }

    private static func forwardHeadDegrees(from landmarks: [BodyLandmark]) -> Double? {
        guard let nose = landmark("nose", in: landmarks),
              let neck = landmark("neck", in: landmarks),
              let root = landmark("root", in: landmarks) ?? landmark("left_hip", in: landmarks) else { return nil }
        let headVector = (x: nose.x - neck.x, y: nose.y - neck.y)
        let torsoVector = (x: root.x - neck.x, y: root.y - neck.y)
        let dot = headVector.x * torsoVector.x + headVector.y * torsoVector.y
        let mag1 = hypot(headVector.x, headVector.y)
        let mag2 = hypot(torsoVector.x, torsoVector.y)
        guard mag1 > 0, mag2 > 0 else { return nil }
        let angle = acos(min(1, max(-1, dot / (mag1 * mag2)))) * 180 / .pi
        return max(0, 90 - angle)
    }

    private static func kneeAlignmentIndicator(from landmarks: [BodyLandmark]) -> Double? {
        guard let leftKnee = landmark("left_knee", in: landmarks),
              let leftAnkle = landmark("left_ankle", in: landmarks),
              let leftHip = landmark("left_hip", in: landmarks),
              let rightKnee = landmark("right_knee", in: landmarks),
              let rightAnkle = landmark("right_ankle", in: landmarks),
              let rightHip = landmark("right_hip", in: landmarks) else { return nil }

        let leftOffset = abs(leftKnee.x - lineX(at: leftKnee.y, from: leftHip, to: leftAnkle))
        let rightOffset = abs(rightKnee.x - lineX(at: rightKnee.y, from: rightHip, to: rightAnkle))
        return (leftOffset + rightOffset) / 2
    }

    private static func lineX(at y: Double, from a: BodyLandmark, to b: BodyLandmark) -> Double {
        guard abs(b.y - a.y) > 0.0001 else { return a.x }
        let t = (y - a.y) / (b.y - a.y)
        return a.x + t * (b.x - a.x)
    }

    private static func symmetryFrom(left: [BodyLandmark], right: [BodyLandmark]) -> Int {
        guard !left.isEmpty, !right.isEmpty else { return 70 }
        let leftShoulder = landmark("left_shoulder", in: left)
        let rightShoulder = landmark("right_shoulder", in: right)
        guard let ls = leftShoulder, let rs = rightShoulder else { return 68 }
        let delta = abs(ls.y - rs.y)
        return Int(max(40, min(95, 92 - delta * 120)))
    }

    private static func scoreFromTilt(_ tilt: Double?, ideal: Double, tolerance: Double) -> Int {
        guard let tilt else { return 65 }
        let deviation = abs(tilt - ideal)
        return Int(max(35, min(98, 100 - (deviation / tolerance) * 22)))
    }

    private static func scoreFromAngle(_ angle: Double?, ideal: Double, tolerance: Double) -> Int {
        guard let angle else { return 65 }
        let deviation = abs(angle - ideal)
        return Int(max(35, min(98, 100 - (deviation / tolerance) * 20)))
    }

    private static func scoreFromDeviation(_ value: Double?, tolerance: Double) -> Int {
        guard let value else { return 65 }
        return Int(max(35, min(98, 100 - (value / tolerance) * 18)))
    }

    private static func weightedAverage(_ items: [(Int, Double)]) -> Int {
        let total = items.map(\.1).reduce(0, +)
        guard total > 0 else { return 50 }
        let sum = items.reduce(0.0) { $0 + Double($1.0) * $1.1 }
        return Int(round(sum / total))
    }
}

private extension Double {
    var magnitude: Double { abs(self) }
}
