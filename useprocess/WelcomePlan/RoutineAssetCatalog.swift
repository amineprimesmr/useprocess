import Foundation

/// Visuels carousel « Routine matinale ».
enum RoutineAssetCatalog {
    // Anciens assets (conservés pour compatibilité)
    static let soleil = "routinesoleil"
    static let eau = "routineau"
    static let mewing = "routinemewing"
    static let posture = "routineposture"
    static let dormir = "routinedormir"

    // Nouveaux assets routine matinale
    static let eauTiede = "routineeautiede"
    static let sauts = "routinesauts"
    static let genoux = "routinegenoux"
    static let bras = "routinebras"
    static let glacons = "routineglacons"

    static let allAssetNames: [String] = [soleil, eau, mewing, posture, dormir, eauTiede, sauts, genoux, bras, glacons]

    static func asset(forHabitTitle title: String) -> String? {
        switch title {
        case ProcessContinuousHabits.mewingTitle:
            return mewing
        case ProcessContinuousHabits.postureTitle:
            return posture
        case ProcessContinuousHabits.sideSleepTitle:
            return dormir
        default:
            return nil
        }
    }

    static func asset(forRoutineLine line: String) -> String? {
        let key = normalize(line)
        if key.contains("eau tiede") || key.contains("eau tiède") || key.contains("eau chaude") { return eauTiede }
        if key.hasPrefix("soleil") { return soleil }
        if key.contains("saut sur place") || key.contains("sauts sur place") || (key.contains("saut") && !key.contains("genoux")) { return sauts }
        if key.contains("montee") || key.contains("montée") || key.contains("genoux") { return genoux }
        if key.contains("bras alterne") || key.contains("bras alternés") || key.contains("bras alternés") { return bras }
        if key.contains("corde") { return sauts }
        if key.contains("glacon") || key.contains("glaçon") || key.contains("eau froide") { return glacons }
        if key.contains("mewing") || key.contains("suction mew") { return mewing }
        if key.contains("nuque") || key.contains("posture") { return posture }
        if key.contains("respiration nasale") || key.contains("sommeil") { return dormir }
        return nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
    }
}
