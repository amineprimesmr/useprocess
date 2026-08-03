import Foundation

/// Visuels carousel « Routine matinale ».
enum RoutineAssetCatalog {
    static let eauTiede = "routineeautiede"
    static let sauts = "routinesauts"
    static let genoux = "routinegenoux"
    static let bras = "routinebras"
    static let glacons = "routineglacons"

    // Legacy (habitudes 24/7, anciennes cartes)
    static let soleil = "routinesoleil"
    static let eau = "routineau"
    static let mewing = "routinemewing"
    static let posture = "routineposture"
    static let dormir = "routinedormir"
    static let corde = "cardio_corde"

    static let morningRoutineAssetNames: [String] = [
        eauTiede, sauts, genoux, bras, glacons
    ]

    static let allAssetNames: [String] = morningRoutineAssetNames + [
        soleil, eau, mewing, posture, dormir, corde
    ]

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
        if key.contains("eau tiède") || key.contains("eau tiede") || key.contains("eau tiede au reveil") {
            return eauTiede
        }
        if key.contains("saut sur place") || key.contains("sauts sur place") {
            return sauts
        }
        if key.contains("montee de genoux") || key.contains("montées de genoux") || key.contains("genou") {
            return genoux
        }
        if key.contains("bras altern") {
            return bras
        }
        if key.contains("glacon") || key.contains("glaçon") {
            return glacons
        }
        if key.contains("corde") { return corde }
        if key.contains("eau froide") || key.hasPrefix("eau") { return eau }
        if key.contains("mewing") || key.contains("suction mew") { return mewing }
        if key.contains("nuque") || key.contains("posture") { return posture }
        if key.contains("respiration nasale") || key.contains("sommeil") { return dormir }
        if key.hasPrefix("soleil") { return soleil }
        return nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
    }
}
