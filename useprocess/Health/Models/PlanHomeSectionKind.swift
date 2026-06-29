import Foundation

/// Sections réordonnables de la page Accueil Plan.
enum PlanHomeSectionKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case faceScan
    case nutrition
    case training
    case posture
    case faceRoutine
    case resources

    var id: String { rawValue }

    var title: String {
        switch self {
        case .faceScan: "Dernier scan"
        case .nutrition: "Repas debloat"
        case .training: "Entraînement du jour"
        case .posture: "Posture & circuit quotidien"
        case .faceRoutine: "Routine quotidienne"
        case .resources: "Aller plus loin"
        }
    }

    var icon: String {
        switch self {
        case .faceScan: "faceid"
        case .nutrition: "fork.knife"
        case .training: "figure.strengthtraining.traditional"
        case .posture: "figure.mind.and.body"
        case .faceRoutine: "sun.max.fill"
        case .resources: "square.grid.2x2.fill"
        }
    }

    static let defaultOrder: [PlanHomeSectionKind] = [
        .faceScan,
        .nutrition,
        .training,
        .faceRoutine
    ]
}
