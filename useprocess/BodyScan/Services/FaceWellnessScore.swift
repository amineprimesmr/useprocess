import Foundation

/// Score « visage du jour » (0–100) — plus haut = meilleur état perçu.
enum FaceWellnessScore {

    static func dayScore(from markers: FaceWellnessMarkers) -> Int {
        let stressLoad = Double(markers.puffinessScore) * 0.45
            + Double(markers.underEyeFatigueScore) * 0.55
        let jawPenalty = Double(markers.jawTensionScore) * 0.12
        let raw = stressLoad + jawPenalty
        return Int(max(0, min(100, (100 - raw).rounded())))
    }

    static func label(for score: Int) -> String {
        switch score {
        case 80...: return "Visage reposé"
        case 60..<80: return "Visage correct"
        case 40..<60: return "Fatigue visible"
        default: return "Récupération visuelle faible"
        }
    }
}
