import Foundation

enum OnboardingPrimaryFocus: String, Codable, CaseIterable {
    /// Gonflement / rétention faciale globale.
    case face
    /// Mâchoire, ovale, double menton (ex-« weight » — rawValue conservé pour la persistance).
    case weight
    /// Cernes / regard fatigué (ex-« health »).
    case health
    /// Rétention matinale / inflammation (ex-« energy »).
    case energy

    var faceConcernChoiceIds: [String] {
        switch self {
        case .face: return ["puffiness", "dull_skin"]
        case .weight: return ["double_chin", "weak_jaw"]
        case .health: return ["dark_circles"]
        case .energy: return ["puffiness", "dull_skin"]
        }
    }
}

enum OnboardingDebloatDriver: String, Codable, CaseIterable {
    case sleep
    case nutrition
    case stress
    case sedentary
    case unknown
}

enum OnboardingRoutineChallenge: String, Codable, CaseIterable {
    case nutrition
    case hydration
    case sleep
    case movement
    case consistency
}
