import Foundation

/// Cardio debloat unique Process — marche inclinée uniquement (pas de rotation d’autres cardio).
enum DebloatCardioDayCatalog {

    /// Prescription fixe : durée, pente, allure.
    static let durationMinutes = 30
    static let inclinePercent = 10
    static let paceKmh = 5.0

    struct Session: Equatable, Identifiable {
        let id: String
        let title: String
        let detail: String
        let minutes: Int
        let inclinePercent: Int
        let paceKmh: Double
        let assetName: String?
        let systemImage: String

        var paceLabel: String {
            if paceKmh.rounded() == paceKmh {
                return "\(Int(paceKmh)) km/h"
            }
            return String(format: "%.1f km/h", paceKmh)
        }

        var badgeLabel: String {
            "\(minutes) min · \(inclinePercent)% · \(paceLabel)"
        }

        var prescriptionLine: String {
            "\(minutes) min · pente \(inclinePercent)% · allure \(paceLabel)"
        }
    }

    static func session(for date: Date = Date()) -> Session {
        _ = date
        let asset = TrainingAssetCatalog.blockAsset(for: "Tapis incline")
            ?? TrainingAssetCatalog.blockAsset(for: "Marche")
        return Session(
            id: "cardio-day-incline-walk",
            title: "Marche inclinée",
            detail: """
            \(durationMinutes) min sur tapis · pente \(inclinePercent)% · allure \(String(format: "%.1f", paceKmh)) km/h.
            Bras libres, pas d’appui sur les barres. Respiration confortable (tu peux parler).
            Idéal chaque jour · minimum \(ProcessDebloatValidation.weeklyCardioMinimum)×/semaine.
            """,
            minutes: durationMinutes,
            inclinePercent: inclinePercent,
            paceKmh: paceKmh,
            assetName: asset,
            systemImage: "figure.walk"
        )
    }

    static var frequencyCaption: String {
        "Idéal chaque jour · minimum \(ProcessDebloatValidation.weeklyCardioMinimum)×/semaine"
    }
}
