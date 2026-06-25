import SwiftUI

enum ProcessMainSection: String, CaseIterable, Identifiable, Hashable {
    case coach
    case plan
    case profile

    var id: String { rawValue }

    static let tabOrder: [ProcessMainSection] = [.plan, .coach, .profile]

    var label: String {
        switch self {
        case .coach: "Coach"
        case .plan: "Accueil"
        case .profile: "Profil"
        }
    }

    var icon: String {
        switch self {
        case .coach: "sparkles"
        case .plan: "house.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}
