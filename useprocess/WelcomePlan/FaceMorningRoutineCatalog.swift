import Foundation

/// Routine quotidienne — actions matin + habitudes 24/7 (carousel Plan).
enum FaceMorningRoutineCatalog {

    enum Step: Int, CaseIterable {
        case soleilAuReveil
        case eauFroide

        func canonicalLine(targets: OriginPersonalizedDailyTargets) -> String {
            switch self {
            case .soleilAuReveil:
                return "Soleil au réveil — \(targets.morningLightMinutes) min de lumière naturelle"
            case .eauFroide:
                return "Glaçons sur le visage"
            }
        }
    }

    static func buildSteps(targets: OriginPersonalizedDailyTargets) -> [String] {
        Step.allCases.map { $0.canonicalLine(targets: targets) }
    }

    /// Matin + habitudes 24/7 — tout le carousel « Routine quotidienne ».
    static func dailyRoutineLines(
        storedLines: [String],
        targets: OriginPersonalizedDailyTargets
    ) -> [String] {
        _ = storedLines
        var lines = buildSteps(targets: targets)

        for habit in ProcessContinuousHabits.all {
            lines.append("\(habit.title) — \(habit.detail)")
        }

        return lines
    }

    /// Lignes pour le carousel — priorité fixe, texte canonique (ignore pollution stockée).
    static func displaySteps(
        storedLines: [String],
        targets: OriginPersonalizedDailyTargets
    ) -> [String] {
        dailyRoutineLines(storedLines: storedLines, targets: targets)
    }

    static func estimatedMinutes(targets: OriginPersonalizedDailyTargets) -> Int {
        targets.morningLightMinutes + 1
    }

    static func dailyRoutineActionCount(targets: OriginPersonalizedDailyTargets) -> Int {
        carouselItems(targets: targets).count
    }

    /// Cartes carousel avec visuels routine (`routinesoleil`, `routineau`, etc.).
    static func carouselItems(targets: OriginPersonalizedDailyTargets) -> [PlanProtocolCarouselItem] {
        let category = "Routine quotidienne"
        var items: [PlanProtocolCarouselItem] = []

        items.append(PlanProtocolCarouselBuilder.lineItem(
            Step.soleilAuReveil.canonicalLine(targets: targets),
            id: "daily-routine-soleil",
            fallback: "sun.max.fill",
            category: category,
            assetName: RoutineAssetCatalog.soleil
        ))
        items.append(PlanProtocolCarouselBuilder.lineItem(
            Step.eauFroide.canonicalLine(targets: targets),
            id: "daily-routine-eau",
            fallback: "drop.fill",
            category: category,
            assetName: RoutineAssetCatalog.eau
        ))

        for (index, habit) in ProcessContinuousHabits.all.enumerated() {
            let line = "\(habit.title) — \(habit.detail)"
            items.append(PlanProtocolCarouselBuilder.lineItem(
                line,
                id: "daily-routine-habit-\(index)",
                fallback: habitFallbackIcon(for: habit.title),
                category: category,
                assetName: RoutineAssetCatalog.asset(forHabitTitle: habit.title)
            ))
        }

        return items
    }

    private static func habitFallbackIcon(for title: String) -> String {
        switch title {
        case ProcessContinuousHabits.mewingTitle: return "mouth.fill"
        case ProcessContinuousHabits.postureTitle: return "figure.stand"
        case ProcessContinuousHabits.sideSleepTitle: return "bed.double.fill"
        default: return "sun.max.fill"
        }
    }
}
