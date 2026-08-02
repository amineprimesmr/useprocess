import Foundation

/// Cardio debloat du jour — rotation stable par date (pas de musculation).
enum DebloatCardioDayCatalog {

    struct Session: Equatable, Identifiable {
        let id: String
        let title: String
        let detail: String
        let minutes: Int
        let assetName: String?
        let systemImage: String
    }

    private struct Template {
        let title: String
        let detail: String
        let minutes: Int
        let assetHint: String
        let systemImage: String
    }

    /// Suggestions légères — idéal chaque jour · minimum 3×/semaine.
    private static let templates: [Template] = [
        .init(
            title: "Marche active",
            detail: "20–30 min à rythme soutenu, bras libres — idéal drainage visage. Minimum 3×/semaine, mieux chaque jour.",
            minutes: 25,
            assetHint: "Marche",
            systemImage: "figure.walk"
        ),
        .init(
            title: "Vélo léger",
            detail: "20–30 min en endurance facile (intérieur ou extérieur). Cardio debloat sans impact.",
            minutes: 25,
            assetHint: "Vélo",
            systemImage: "bicycle"
        ),
        .init(
            title: "Tapis incliné",
            detail: "20–25 min marche inclinée (5–8 %) — pompe lymphatique sans course.",
            minutes: 22,
            assetHint: "Tapis incline",
            systemImage: "figure.walk"
        ),
        .init(
            title: "Course douce",
            detail: "15–25 min footing facile, ou marche rapide si tu préfères. Respiration nasale si possible.",
            minutes: 20,
            assetHint: "Course",
            systemImage: "figure.run"
        ),
        .init(
            title: "Elliptique",
            detail: "20–30 min rythme conversationnel — cardio debloat low-impact.",
            minutes: 25,
            assetHint: "Elliptique",
            systemImage: "figure.elliptical"
        ),
        .init(
            title: "Rameur léger",
            detail: "15–25 min en souplesse, sans forcer — circulation + respiration.",
            minutes: 20,
            assetHint: "Rameur",
            systemImage: "figure.rower"
        ),
        .init(
            title: "HIIT léger",
            detail: "12–18 min : 30 s effort / 60 s récup. Marche, vélo ou corde — pas de muscu.",
            minutes: 15,
            assetHint: "HIIT",
            systemImage: "bolt.fill"
        ),
        .init(
            title: "Escalier / stepper",
            detail: "15–20 min montées régulières — excellent pour le drainage.",
            minutes: 18,
            assetHint: "Escalier",
            systemImage: "figure.stairs"
        ),
        .init(
            title: "Natation / aqua",
            detail: "20–30 min nage douce ou aqua-jogging si dispo — drainage + récupération.",
            minutes: 25,
            assetHint: "Natation",
            systemImage: "figure.pool.swim"
        ),
        .init(
            title: "Randonnée courte",
            detail: "30–40 min marche nature ou ville en pente légère. Idéal un jour sur deux.",
            minutes: 35,
            assetHint: "Randonnee",
            systemImage: "figure.hiking"
        )
    ]

    static func session(for date: Date = Date()) -> Session {
        let day = Calendar.current.startOfDay(for: date)
        let dayNumber = Calendar.current.ordinality(of: .day, in: .era, for: day) ?? 0
        let template = templates[abs(dayNumber) % templates.count]
        let asset = TrainingAssetCatalog.blockAsset(for: template.assetHint)
        return Session(
            id: "cardio-day-\(dayNumber % templates.count)",
            title: template.title,
            detail: template.detail,
            minutes: template.minutes,
            assetName: asset,
            systemImage: template.systemImage
        )
    }

    static var frequencyCaption: String {
        "Idéal chaque jour · minimum \(ProcessDebloatValidation.weeklyCardioMinimum)×/semaine"
    }
}
