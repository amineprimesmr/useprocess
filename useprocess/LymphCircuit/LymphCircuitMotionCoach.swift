import Foundation

/// Coach mouvement temps réel à partir des landmarks Vision.
struct LymphCircuitMotionCoach {
    struct Snapshot: Equatable {
        var intensity: Double
        var isMoving: Bool
        var bodyVisible: Bool
        var cue: String
    }

    private var hipYHistory: [Double] = []
    private var leftKneePeaks = 0
    private var rightKneePeaks = 0
    private var leftArmPeaks = 0
    private var rightArmPeaks = 0
    private var lastLeftKneeHigh = false
    private var lastRightKneeHigh = false
    private var lastLeftArmHigh = false
    private var lastRightArmHigh = false
    private var lastIntensity: Double = 0

    mutating func reset() {
        hipYHistory = []
        leftKneePeaks = 0
        rightKneePeaks = 0
        leftArmPeaks = 0
        rightArmPeaks = 0
        lastLeftKneeHigh = false
        lastRightKneeHigh = false
        lastLeftArmHigh = false
        lastRightArmHigh = false
        lastIntensity = 0
    }

    mutating func analyze(
        step: FaceMorningRoutineCatalog.Step,
        landmarks: [BodyLandmark]
    ) -> Snapshot {
        let map = Dictionary(uniqueKeysWithValues: landmarks.map { ($0.name, $0) })
        let bodyVisible = landmarks.filter { $0.confidence >= 0.25 }.count >= 6

        guard bodyVisible else {
            lastIntensity = max(0, lastIntensity - 0.08)
            return Snapshot(
                intensity: lastIntensity,
                isMoving: false,
                bodyVisible: false,
                cue: AppCopy.tSync(
                    "Place-toi face à la caméra, corps entier visible.",
                    en: "Face the camera with your full body visible."
                )
            )
        }

        switch step {
        case .sautsSurPlace, .rebondsPointes:
            return analyzeVerticalBounce(map: map, cueMoving: step.coachingCueSync, cueIdle: step.coachingCueSync)
        case .brasAuCiel:
            return analyzeArms(map: map)
        case .brasEnCroix:
            return analyzeArmsOut(map: map)
        case .ouvertureThorax:
            return analyzeChestHands(map: map)
        case .monteesGenoux:
            return analyzeKnees(map: map)
        }
    }

    // MARK: - Exercises

    private mutating func analyzeVerticalBounce(
        map: [String: BodyLandmark],
        cueMoving: String,
        cueIdle: String
    ) -> Snapshot {
        let hipY = map["root"]?.y ?? map["left_hip"]?.y ?? map["right_hip"]?.y
        guard let hipY else {
            return Snapshot(
                intensity: lastIntensity,
                isMoving: false,
                bodyVisible: true,
                cue: AppCopy.tSync("Recule un peu pour voir le corps entier.", en: "Step back so your full body is visible.")
            )
        }

        hipYHistory.append(hipY)
        if hipYHistory.count > 18 {
            hipYHistory.removeFirst(hipYHistory.count - 18)
        }

        let amplitude: Double
        if let minY = hipYHistory.min(), let maxY = hipYHistory.max() {
            amplitude = maxY - minY
        } else {
            amplitude = 0
        }

        let intensity = min(1, max(0, (amplitude - 0.012) / 0.05))
        lastIntensity = lastIntensity * 0.65 + intensity * 0.35
        let moving = lastIntensity > 0.22

        return Snapshot(
            intensity: lastIntensity,
            isMoving: moving,
            bodyVisible: true,
            cue: moving ? cueMoving : cueIdle
        )
    }

    private mutating func analyzeKnees(map: [String: BodyLandmark]) -> Snapshot {
        guard
            let leftHip = map["left_hip"],
            let rightHip = map["right_hip"],
            let leftKnee = map["left_knee"],
            let rightKnee = map["right_knee"]
        else {
            return Snapshot(
                intensity: lastIntensity,
                isMoving: false,
                bodyVisible: true,
                cue: AppCopy.tSync("Montre tes genoux à la caméra.", en: "Show your knees to the camera.")
            )
        }

        let leftHigh = leftKnee.y > leftHip.y + 0.04
        let rightHigh = rightKnee.y > rightHip.y + 0.04

        if leftHigh && !lastLeftKneeHigh { leftKneePeaks += 1 }
        if rightHigh && !lastRightKneeHigh { rightKneePeaks += 1 }
        lastLeftKneeHigh = leftHigh
        lastRightKneeHigh = rightHigh

        if leftHigh || rightHigh {
            lastIntensity = min(1, lastIntensity + 0.12)
        } else {
            lastIntensity = max(0, lastIntensity - 0.04)
        }

        let moving = lastIntensity > 0.2
        return Snapshot(
            intensity: lastIntensity,
            isMoving: moving,
            bodyVisible: true,
            cue: moving
                ? AppCopy.tSync("Rythme — alterne bien les genoux.", en: "Keep the rhythm — alternate knees.")
                : AppCopy.tSync("Monte un genou, puis l’autre.", en: "Raise one knee, then the other.")
        )
    }

    private mutating func analyzeArms(map: [String: BodyLandmark]) -> Snapshot {
        guard
            let leftShoulder = map["left_shoulder"],
            let rightShoulder = map["right_shoulder"],
            let leftWrist = map["left_wrist"],
            let rightWrist = map["right_wrist"]
        else {
            return Snapshot(
                intensity: lastIntensity,
                isMoving: false,
                bodyVisible: true,
                cue: AppCopy.tSync("Lève les bras pour que la caméra les voie.", en: "Raise your arms so the camera can see them.")
            )
        }

        let leftHigh = leftWrist.y > leftShoulder.y + 0.12
        let rightHigh = rightWrist.y > rightShoulder.y + 0.12

        if leftHigh && !lastLeftArmHigh { leftArmPeaks += 1 }
        if rightHigh && !lastRightArmHigh { rightArmPeaks += 1 }
        lastLeftArmHigh = leftHigh
        lastRightArmHigh = rightHigh

        if leftHigh || rightHigh {
            lastIntensity = min(1, lastIntensity + 0.14)
        } else {
            lastIntensity = max(0, lastIntensity - 0.05)
        }

        let moving = lastIntensity > 0.2
        return Snapshot(
            intensity: lastIntensity,
            isMoving: moving,
            bodyVisible: true,
            cue: moving
                ? AppCopy.tSync("Oui — bras hauts, sur la pointe.", en: "Yes — arms high, up on toes.")
                : AppCopy.tSync("Bras au-dessus de la tête.", en: "Arms above your head.")
        )
    }

    private mutating func analyzeArmsOut(map: [String: BodyLandmark]) -> Snapshot {
        guard
            let leftWrist = map["left_wrist"],
            let rightWrist = map["right_wrist"],
            let leftShoulder = map["left_shoulder"],
            let rightShoulder = map["right_shoulder"]
        else {
            return Snapshot(
                intensity: lastIntensity,
                isMoving: false,
                bodyVisible: true,
                cue: AppCopy.tSync("Écarte les bras à l’horizontale.", en: "Extend your arms out horizontally.")
            )
        }

        let armSpread = abs(leftWrist.x - rightWrist.x)
        let leftLevel = abs(leftWrist.y - leftShoulder.y) < 0.12
        let rightLevel = abs(rightWrist.y - rightShoulder.y) < 0.12
        let wideEnough = armSpread > 0.35

        if wideEnough && leftLevel && rightLevel {
            lastIntensity = min(1, lastIntensity + 0.12)
        } else {
            lastIntensity = max(0, lastIntensity - 0.05)
        }

        let moving = lastIntensity > 0.2
        return Snapshot(
            intensity: lastIntensity,
            isMoving: moving,
            bodyVisible: true,
            cue: moving
                ? AppCopy.tSync("Oui — garde les bras ouverts.", en: "Yes — keep the arms open.")
                : AppCopy.tSync("Bras à l’horizontale, poitrine ouverte.", en: "Arms horizontal, chest open.")
        )
    }

    private mutating func analyzeChestHands(map: [String: BodyLandmark]) -> Snapshot {
        guard
            let leftWrist = map["left_wrist"],
            let rightWrist = map["right_wrist"],
            let leftShoulder = map["left_shoulder"],
            let rightShoulder = map["right_shoulder"]
        else {
            return Snapshot(
                intensity: lastIntensity,
                isMoving: false,
                bodyVisible: true,
                cue: AppCopy.tSync("Mains vers le thorax, face caméra.", en: "Hands toward your chest, face the camera.")
            )
        }

        let midShoulderX = (leftShoulder.x + rightShoulder.x) / 2
        let midShoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let leftNear = hypot(leftWrist.x - midShoulderX, leftWrist.y - midShoulderY) < 0.22
        let rightNear = hypot(rightWrist.x - midShoulderX, rightWrist.y - midShoulderY) < 0.22

        if leftNear && rightNear {
            lastIntensity = min(1, lastIntensity + 0.1)
        } else {
            lastIntensity = max(0, lastIntensity - 0.04)
        }

        // Petite oscillation des poignets = stimulation.
        let wristY = (leftWrist.y + rightWrist.y) / 2
        hipYHistory.append(wristY)
        if hipYHistory.count > 14 {
            hipYHistory.removeFirst(hipYHistory.count - 14)
        }
        if let minY = hipYHistory.min(), let maxY = hipYHistory.max(), maxY - minY > 0.02 {
            lastIntensity = min(1, lastIntensity + 0.08)
        }

        let moving = lastIntensity > 0.18
        return Snapshot(
            intensity: lastIntensity,
            isMoving: moving,
            bodyVisible: true,
            cue: moving
                ? AppCopy.tSync("Oui — stimule bien la zone.", en: "Yes — keep stimulating the area.")
                : AppCopy.tSync("Mains sur le thorax, ouvre la zone.", en: "Hands on the chest, open the area.")
        )
    }
}

private extension FaceMorningRoutineCatalog.Step {
    var coachingCueSync: String {
        switch self {
        case .sautsSurPlace:
            return AppCopy.tSync(
                "Rebonds légers, rythme régulier — pompe la lymphe.",
                en: "Light bounces, steady rhythm — pump the lymph."
            )
        case .rebondsPointes:
            return AppCopy.tSync(
                "Sur la pointe des pieds, petits rebonds, bras écartés.",
                en: "On your toes, light bounces, arms out."
            )
        case .brasAuCiel:
            return AppCopy.tSync(
                "Lève les bras au ciel, monte sur la pointe des pieds.",
                en: "Reach arms to the sky, rise onto your toes."
            )
        case .brasEnCroix:
            return AppCopy.tSync(
                "Bras horizontaux, poitrine ouverte — respire large.",
                en: "Arms horizontal, open chest — breathe wide."
            )
        case .ouvertureThorax:
            return AppCopy.tSync(
                "Mains sur le thorax, ouvre et stimule la zone.",
                en: "Hands on the chest, open and stimulate the area."
            )
        case .monteesGenoux:
            return AppCopy.tSync(
                "Monte un genou puis l’autre, reste stable.",
                en: "Raise one knee then the other, stay balanced."
            )
        }
    }
}
