import Foundation

enum ReadinessScorer {

    struct Result {
        let score: Int
        let label: String
        let factors: [String]
        let faceScore: Int?
        let faceLabel: String?
    }

    static func score(
        snapshot: DailyHealthSnapshot,
        baselines: UserHealthBaselines,
        faceMarkers: FaceWellnessMarkers? = nil
    ) -> Result {
        var points = 50.0
        var factors: [String] = []

        // Sommeil
        if snapshot.sleep.sleepDuration > 0, baselines.sleepNeedHours > 0 {
            let sleepRatio = snapshot.sleep.sleepDuration / baselines.sleepNeedHours
            if sleepRatio >= 0.9 && sleepRatio <= 1.15 {
                points += 18
                factors.append("Sommeil dans ta norme")
            } else if sleepRatio >= 0.75 {
                points += 8
                factors.append("Sommeil un peu court")
            } else {
                points -= 12
                factors.append("Manque de sommeil")
            }
        }

        // HRV vs baseline
        if snapshot.vitals.hrv > 0, baselines.hrv > 0 {
            let hrvDelta = (snapshot.vitals.hrv - baselines.hrv) / baselines.hrv
            if hrvDelta >= 0.05 {
                points += 15
                factors.append("HRV au-dessus de ta moyenne")
            } else if hrvDelta >= -0.1 {
                points += 5
            } else {
                points -= 10
                factors.append("HRV en baisse — récupération fragile")
            }
        }

        // FC repos
        if snapshot.vitals.restingHeartRate > 0, baselines.restingHeartRate > 0 {
            let rhrDelta = snapshot.vitals.restingHeartRate - baselines.restingHeartRate
            if rhrDelta <= 2 {
                points += 10
            } else if rhrDelta > 5 {
                points -= 8
                factors.append("FC repos élevée")
            }
        }

        // Charge récente (effort)
        let effort = snapshot.effort.effortScore
        if effort > 75 {
            points -= 8
            factors.append("Forte charge hier — prudence")
        } else if effort < 35 {
            points += 5
        }

        // Visage du jour (gonflement + cernes)
        var faceScore: Int?
        var faceLabel: String?
        if let faceMarkers {
            faceScore = FaceWellnessScore.dayScore(from: faceMarkers)
            faceLabel = FaceWellnessScore.label(for: faceScore!)
            let contribution = (Double(faceScore!) - 50) * 0.28
            points += contribution

            switch faceScore! {
            case 80...:
                factors.append("Visage reposé — bon signal de récupération")
            case 60..<80:
                factors.append("Fatigue visuelle légère")
            case 40..<60:
                factors.append("Gonflement ou cernes visibles")
            default:
                factors.append("Fatigue visuelle marquée — priorité récupération")
            }
        }

        let final = Int(min(100, max(0, points)).rounded())
        let label: String = switch final {
        case 80...: "Prêt à performer"
        case 60..<80: "Bonne forme"
        case 40..<60: "Récupération modérée"
        default: "Priorité récupération"
        }

        if factors.isEmpty {
            factors.append("Données limitées — complète ton profil santé")
        }

        return Result(
            score: final,
            label: label,
            factors: factors,
            faceScore: faceScore,
            faceLabel: faceLabel
        )
    }
}
