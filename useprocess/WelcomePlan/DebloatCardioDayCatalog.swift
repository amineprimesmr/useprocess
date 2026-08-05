import Foundation

/// Cardio debloat unique Process — marche inclinée uniquement (pas de rotation d’autres cardio).
enum DebloatCardioDayCatalog {

    /// Prescription fixe : durée, pente, allure.
    static let durationMinutes = 25
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
            "\(minutes) min"
        }

        @MainActor
        var prescriptionLine: String {
            AppCopy.t(
                "\(minutes) min · pente \(inclinePercent)% · allure \(paceLabel)",
                en: "\(minutes) min · \(inclinePercent)% incline · \(paceLabel) pace"
            )
        }
    }

    @MainActor
    static func session(for date: Date = Date()) -> Session {
        _ = date
        let asset = TrainingAssetCatalog.blockAsset(for: "Tapis incline")
            ?? TrainingAssetCatalog.blockAsset(for: "Marche")
        let pace = String(format: "%.1f", paceKmh)
        return Session(
            id: "cardio-day-incline-walk",
            title: AppCopy.t("Marche inclinée", en: "Incline walk"),
            detail: AppCopy.t(
                """
                \(durationMinutes) min sur tapis · pente \(inclinePercent)% · allure \(pace) km/h.
                Bras libres, pas d’appui sur les barres. Respiration confortable (tu peux parler).
                Minimum \(ProcessDebloatValidation.weeklyCardioMinimum)×/semaine.
                """,
                en: """
                \(durationMinutes) min on a treadmill · \(inclinePercent)% incline · \(pace) km/h pace.
                Arms free, no resting on the rails. Comfortable breathing (you can talk).
                At least \(ProcessDebloatValidation.weeklyCardioMinimum)×/week.
                """
            ),
            minutes: durationMinutes,
            inclinePercent: inclinePercent,
            paceKmh: paceKmh,
            assetName: asset,
            systemImage: "figure.walk"
        )
    }

    @MainActor
    static var frequencyCaption: String {
        AppCopy.t(
            "Minimum \(ProcessDebloatValidation.weeklyCardioMinimum)×/semaine",
            en: "At least \(ProcessDebloatValidation.weeklyCardioMinimum)×/week"
        )
    }
}
