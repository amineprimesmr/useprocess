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

    @MainActor
    var title: String {
        switch self {
        case .faceScan: AppCopy.t("Dernier scan", en: "Latest scan")
        case .nutrition: AppCopy.t("Alimentation debloat", en: "Debloat nutrition")
        case .training: AppCopy.t("Cardio et Circuit", en: "Cardio & Circuit")
        case .posture: AppCopy.t("Posture & circuit quotidien", en: "Daily posture & circuit")
        case .faceRoutine: AppCopy.t("Circuit lymphatique", en: "Lymphatic circuit")
        case .resources: AppCopy.t("Aller plus loin", en: "Go further")
        }
    }

    var icon: String {
        switch self {
        case .faceScan: "faceid"
        case .nutrition: "fork.knife"
        case .training: "figure.run"
        case .posture: "figure.mind.and.body"
        case .faceRoutine: "drop.fill"
        case .resources: "square.grid.2x2.fill"
        }
    }

    static let defaultOrder: [PlanHomeSectionKind] = [
        .faceScan,
        .nutrition,
        .faceRoutine
    ]
}
