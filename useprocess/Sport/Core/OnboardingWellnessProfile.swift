import Foundation

enum OnboardingPrimaryFocus: String, Codable, CaseIterable {
    case face
    case weight
    case health
    case energy
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
