import Foundation

/// Hydratation debloat — quantité fixe + eaux minérales recommandées.
enum ProcessHydrationGuide {

    static var dailyLiters: String { ProcessDailyTargets.hydrationLabel }

    static let morningLine = "500 ml d'eau + pincée de sel ou citron au réveil — pas de café immédiat."

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
        return "\(dailyLiters) (\(ProcessDailyTargets.hydrationLitersPerDay * 1000) ml). \(brands) Sel de qualité."
    }
}
