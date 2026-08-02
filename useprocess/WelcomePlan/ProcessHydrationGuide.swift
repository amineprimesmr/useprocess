import Foundation

/// Hydratation debloat — quantité fixe + eaux minérales recommandées.
enum ProcessHydrationGuide {

    static var dailyLiters: String { ProcessDailyTargets.hydrationLabel }

    static let morningLine = "3 grands verres d'eau (~750 ml) au réveil, citron facultatif — électrolytes seulement après forte transpiration."

    /// Hydratation Accueil uniquement — jamais injectée dans les repas / recettes.
    static let morningWaterMilliliters = 750
    static var morningWaterLabel: String { "\(morningWaterMilliliters) ml" }
    static let morningWaterItemName = "3 grands verres d'eau filtrée, citron facultatif"

    /// Classement eaux (minéraux naturels).
    static let rankedWaters: [(rank: Int, name: String, detail: String)] = [
        (1, "Rozana", "Minéraux équilibrés — meilleur rapport qualité/prix"),
        (2, "Mont Roucous", "Pureté exceptionnelle, faible minéralisation"),
        (3, "Volvic", "Accessible partout, légèrement minéralisée")
    ]

    static var dailyTaskTitle: String { "Boire \(ProcessDailyTargets.hydrationLitersPerDay) litres" }

    static var dailyTaskDetail: String {
        let brands = rankedWaters.map { "\($0.rank). \($0.name)" }.joined(separator: " · ")
        return "\(morningLine) Total : \(dailyLiters). Eaux : \(brands)."
    }

    static var protocolGuide: String {
        let brands = rankedWaters.map { "\($0.rank). \($0.name) — \($0.detail)" }.joined(separator: " ")
        return "\(dailyLiters) (\(ProcessDailyTargets.hydrationLitersPerDay * 1000) ml). \(brands) Électrolytes uniquement selon chaleur, sport et transpiration."
    }
}
