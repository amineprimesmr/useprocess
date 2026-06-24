import Foundation

// MARK: - Identifiants stables (1 image par séance)

enum TrainingSessionID: String, CaseIterable, Identifiable {
    case pullGym = "pull_gym"
    case pushGym = "push_gym"
    case legsGym = "legs_gym"
    case pushHome = "push_home"
    case pullHome = "pull_home"
    case legsHome = "legs_home"
    case femaleGlutes = "female_glutes"
    case femaleUpper = "female_upper"
    case restDay = "rest_day"

    var id: String { rawValue }

    /// Nom du fichier PNG à déposer dans Assets.xcassets/<asset>.imageset/
    nonisolated var imageAssetName: String {
        switch self {
        case .pullGym: "dossport"
        case .pushGym: "session_push"
        case .legsGym: "session_legs"
        case .pushHome: "session_push_home"
        case .pullHome: "session_pull_home"
        case .legsHome: "session_legs_home"
        case .femaleGlutes: "session_glutes"
        case .femaleUpper: "session_upper_posture"
        case .restDay: "session_rest"
        }
    }
}

struct TrainingSessionCatalogEntry: Identifiable, Equatable {
    let id: TrainingSessionID
    let sessionName: String
    let headline: String
    let muscleTags: [String]
    let location: TrainingSessionLocation
    let gender: TrainingSessionGender

    nonisolated var imageAssetName: String { id.imageAssetName }

    nonisolated var muscleTagsLabel: String {
        muscleTags.map { $0.uppercased() }.joined(separator: " · ")
    }
}

enum TrainingSessionLocation: String {
    case gym
    case home
    case any
}

enum TrainingSessionGender: String {
    case male
    case female
    case any
}

// MARK: - Catalogue

enum TrainingSessionCatalog {

    nonisolated static let allEntries: [TrainingSessionCatalogEntry] = [
        .init(
            id: .pullGym,
            sessionName: "Pull — dos, rear delts",
            headline: "💥 Cibler le dos autrement — tirage & rowing",
            muscleTags: ["Dos", "Trapèzes", "Épaules arrière", "Biceps"],
            location: .gym,
            gender: .male
        ),
        .init(
            id: .pushGym,
            sessionName: "Push — épaules, trapèzes, pec",
            headline: "🔥 Push — développé, épaules & trapèzes",
            muscleTags: ["Pecs", "Épaules", "Trapèzes", "Deltoïdes"],
            location: .gym,
            gender: .male
        ),
        .init(
            id: .legsGym,
            sessionName: "Jambes + chaîne postérieure",
            headline: "🔥 Squat & chaîne postérieure — tu fais ça bien ?",
            muscleTags: ["Quadriceps", "Fessiers", "Ischio-jambiers", "Mollets"],
            location: .gym,
            gender: .male
        ),
        .init(
            id: .pullHome,
            sessionName: "Pull maison",
            headline: "💥 Pull maison — dos & posture",
            muscleTags: ["Dos", "Posture", "Core"],
            location: .home,
            gender: .male
        ),
        .init(
            id: .pushHome,
            sessionName: "Push maison",
            headline: "🔥 Push maison — pecs & épaules",
            muscleTags: ["Pecs", "Épaules", "Deltoïdes", "Posture"],
            location: .home,
            gender: .male
        ),
        .init(
            id: .legsHome,
            sessionName: "Jambes maison",
            headline: "🔥 Jambes maison — squat & fessiers",
            muscleTags: ["Quadriceps", "Fessiers", "Mollets"],
            location: .home,
            gender: .male
        ),
        .init(
            id: .femaleGlutes,
            sessionName: "Fessiers + hanches",
            headline: "🔥 Fessiers & hanches — activation ciblée",
            muscleTags: ["Fessiers", "Hanches", "Abducteurs", "Core"],
            location: .any,
            gender: .female
        ),
        .init(
            id: .femaleUpper,
            sessionName: "Haut du corps + posture",
            headline: "💥 Haut du corps léger & posture",
            muscleTags: ["Dos", "Pecs", "Posture", "Core"],
            location: .any,
            gender: .female
        ),
        .init(
            id: .restDay,
            sessionName: "Récup active",
            headline: "🌿 Récup active — marche & mobilité",
            muscleTags: ["Marche", "Mobilité", "Récupération"],
            location: .any,
            gender: .any
        )
    ]

    nonisolated static func entry(for training: OriginDayTraining) -> TrainingSessionCatalogEntry {
        entry(matchingSessionName: training.sessionName)
            ?? fallbackEntry(for: training)
    }

    nonisolated static func entry(matchingSessionName name: String) -> TrainingSessionCatalogEntry? {
        let normalized = normalize(name)
        return allEntries.first { normalize($0.sessionName) == normalized }
    }

    nonisolated static func entry(for id: TrainingSessionID) -> TrainingSessionCatalogEntry {
        allEntries.first { $0.id == id } ?? allEntries[0]
    }

    nonisolated static var imageAssetsToCreate: [(asset: String, session: String, muscles: String)] {
        allEntries.map { entry in
            (entry.imageAssetName, entry.sessionName, entry.muscleTagsLabel)
        }
    }

    // MARK: - Private

    nonisolated private static func fallbackEntry(for training: OriginDayTraining) -> TrainingSessionCatalogEntry {
        let groups = Array(Set(training.exercises.map(\.muscleGroup))).sorted()
        return TrainingSessionCatalogEntry(
            id: .pullGym,
            sessionName: training.sessionName,
            headline: training.sessionName,
            muscleTags: groups.isEmpty ? ["Full body"] : groups,
            location: .any,
            gender: .any
        )
    }

    nonisolated private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
