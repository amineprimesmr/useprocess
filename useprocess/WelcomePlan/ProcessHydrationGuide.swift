import Foundation

/// Hydratation debloat — quantité fixe + eaux minérales recommandées.
enum ProcessHydrationGuide {

    static var dailyLiters: String { ProcessDailyTargets.hydrationLabel }

    static var morningLine: String {
        AppCopy.tSync(
            "3 grands verres d'eau (~750 ml) au réveil, citron facultatif — électrolytes seulement après forte transpiration.",
            en: "3 large glasses of water (~750 ml) on waking, optional lemon — electrolytes only after heavy sweating."
        )
    }

    /// Hydratation Accueil uniquement — jamais injectée dans les repas / recettes.
    static let morningWaterMilliliters = 750
    static var morningWaterLabel: String { "\(morningWaterMilliliters) ml" }
    static var morningWaterItemName: String {
        AppCopy.tSync(
            "3 grands verres d'eau filtrée, citron facultatif",
            en: "3 large glasses of filtered water, optional lemon"
        )
    }

    /// Classement eaux (minéraux naturels). Brand names stay as-is.
    static var rankedWaters: [(rank: Int, name: String, detail: String)] {
        [
            (1, "Rozana", AppCopy.tSync("Minéraux équilibrés — meilleur rapport qualité/prix", en: "Balanced minerals — best value")),
            (2, "Mont Roucous", AppCopy.tSync("Pureté exceptionnelle, faible minéralisation", en: "Exceptional purity, low mineralization")),
            (3, "Volvic", AppCopy.tSync("Accessible partout, légèrement minéralisée", en: "Widely available, lightly mineralized"))
        ]
    }

    static var dailyTaskTitle: String {
        AppCopy.tSync(
            "Boire \(ProcessDailyTargets.hydrationLitersPerDay) litres",
            en: "Drink \(ProcessDailyTargets.hydrationLitersPerDay) liters"
        )
    }

    static var dailyTaskDetail: String {
        let brands = rankedWaters.map { "\($0.rank). \($0.name)" }.joined(separator: " · ")
        return AppCopy.tSync(
            "\(morningLine) Total : \(dailyLiters). Eaux : \(brands).",
            en: "\(morningLine) Total: \(dailyLiters). Waters: \(brands)."
        )
    }

    static var protocolGuide: String {
        let brands = rankedWaters.map { "\($0.rank). \($0.name) — \($0.detail)" }.joined(separator: " ")
        return AppCopy.tSync(
            "\(dailyLiters) (\(ProcessDailyTargets.hydrationLitersPerDay * 1000) ml). \(brands) Électrolytes uniquement selon chaleur, sport et transpiration.",
            en: "\(dailyLiters) (\(ProcessDailyTargets.hydrationLitersPerDay * 1000) ml). \(brands) Electrolytes only based on heat, sport, and sweat."
        )
    }
}
