import Foundation

/// Durée personnalisée du Protocole Origine (fourchette + calendrier réel).
struct OriginPlanDuration: Equatable {
    let minWeeks: Int
    let maxWeeks: Int
    let totalWeeks: Int
    let archetype: OriginPlanArchetype?

    var rangeLabel: String {
        if minWeeks == maxWeeks { return "\(minWeeks) semaine\(minWeeks > 1 ? "s" : "")" }
        return "\(minWeeks) à \(maxWeeks) semaines"
    }

    var headlineLabel: String {
        if let archetype {
            return "\(archetype.label) — \(totalWeeks) sem."
        }
        return "Protocole Origine — \(totalWeeks) semaines"
    }

    /// Fins de phase inclusives pour le calendrier (une entrée par phase).
    var phaseWeekEnds: [Int] {
        guard totalWeeks > 0 else { return [] }
        let archetype = archetype ?? .foundationBuild
        let phaseCount: Int
        switch archetype {
        case .habitReset: phaseCount = totalWeeks <= 1 ? 1 : 2
        case .maintenancePolish: phaseCount = 2
        case .stressRecovery: phaseCount = 3
        case .recomposition, .foundationBuild: phaseCount = 4
        }

        if phaseCount == 1 { return [totalWeeks] }

        var ends: [Int] = []
        var remaining = totalWeeks
        var start = 1
        for index in 0..<phaseCount {
            let phasesLeft = phaseCount - index
            let chunk = max(1, Int((Double(remaining) / Double(phasesLeft)).rounded()))
            let end = min(totalWeeks, start + chunk - 1)
            ends.append(end)
            remaining = totalWeeks - end
            start = end + 1
            if end >= totalWeeks { break }
        }
        if ends.last != totalWeeks {
            ends[ends.count - 1] = totalWeeks
        }
        return ends
    }

    /// Legacy tuple pour compatibilité progressive.
    var phaseEnds: (p1: Int, p2: Int, p3: Int) {
        let ends = phaseWeekEnds
        return (
            ends.indices.contains(0) ? ends[0] : max(1, totalWeeks / 4),
            ends.indices.contains(1) ? ends[1] : max(2, totalWeeks / 2),
            ends.indices.contains(2) ? ends[2] : max(3, (totalWeeks * 3) / 4)
        )
    }

    init(minWeeks: Int, maxWeeks: Int, totalWeeks: Int, archetype: OriginPlanArchetype? = nil) {
        self.minWeeks = minWeeks
        self.maxWeeks = maxWeeks
        self.totalWeeks = totalWeeks
        self.archetype = archetype
    }

    static func compute(from answers: [String: WelcomePlanAnswer], profile: UnifiedUserProfile? = nil) -> OriginPlanDuration {
        OriginUserAssessment.evaluate(answers: answers, profile: profile, baselineScan: nil).duration
    }

    static func weeksRangeLabel(from start: Int, through end: Int) -> String {
        if start >= end { return "Semaine \(start)" }
        return "Semaines \(start)–\(end)"
    }

    func phaseBlock(for week: Int, roadmap: [OriginPlanPhaseBlock]) -> OriginPlanPhaseBlock {
        for block in roadmap {
            if weekMatches(week, weeksRange: block.weeksRange) {
                return block
            }
        }
        return roadmap.last ?? .init(
            id: "default",
            weeksRange: OriginPlanDuration.weeksRangeLabel(from: 1, through: totalWeeks),
            title: "Protocole",
            objectives: [],
            habits: []
        )
    }

    private func weekMatches(_ week: Int, weeksRange: String) -> Bool {
        let digits = weeksRange.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        guard let first = digits.first else { return false }
        if digits.count >= 2 {
            return week >= first && week <= digits[1]
        }
        return week == first
    }
}
