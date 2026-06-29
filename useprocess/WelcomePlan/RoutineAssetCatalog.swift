import Foundation

/// Visuels carousel « Routine quotidienne ».
enum RoutineAssetCatalog {
    static let soleil = "routinesoleil"
    static let eau = "routineau"
    static let mewing = "routinemewing"
    static let posture = "routineposture"
    static let dormir = "routinedormir"

    static let allAssetNames: [String] = [soleil, eau, mewing, posture, dormir]

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
        if key.hasPrefix("soleil") { return soleil }
        if key.contains("glacon") || key.contains("glaçon") || key.contains("eau froide") { return eau }
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
