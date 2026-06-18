import Foundation

/// Présentation courte du Protocole Origine — priorités, jour courant, libellés compacts.
enum OriginPlanPresenter {

    // MARK: - Jour courant

    static func todayDay(in plan: FaceOriginPlan, date: Date = Date()) -> OriginProgramDay? {
        let index = plan.calendar.currentProgramDayIndex(from: date)
        return plan.calendar.day(globalIndex: index)
    }

    static func todayChecklist(from day: OriginProgramDay) -> [OriginPlanTask] {
        day.morning + day.posture + day.face + day.evening
    }

    static func todayTaskCount(in plan: FaceOriginPlan, date: Date = Date()) -> (done: Int, total: Int) {
        guard let day = todayDay(in: plan, date: date) else { return (0, 0) }
        let tasks = todayChecklist(from: day)
        let done = tasks.filter { plan.progress.completedTaskIds.contains($0.id) }.count
        return (done, tasks.count)
    }

    // MARK: - Priorités impact

    /// Piliers les plus faibles = leviers à traiter en priorité.
    static func impactPriorities(from plan: FaceOriginPlan, limit: Int = 3) -> [OriginPillarScore] {
        Array(plan.pillarScores.sorted { $0.score < $1.score }.prefix(limit))
    }

    static func impactLabel(for score: Int) -> String {
        switch score {
        case ..<45: return "Impact maximal"
        case 45..<60: return "Fort impact"
        case 60..<75: return "Impact modéré"
        default: return "Maintien"
        }
    }

    // MARK: - Textes courts

    static func oneLineSummary(_ plan: FaceOriginPlan) -> String {
        let raw = plan.primaryFaceGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty { return raw }
        return firstSentence(plan.executiveSummary, maxLength: 100)
    }

    static func phaseHeadline(_ plan: FaceOriginPlan, date: Date = Date()) -> String {
        let week = plan.calendar.currentWeekNumber(from: date)
        if let block = plan.phaseRoadmap.first(where: { rangeContains(week, in: $0.weeksRange) }) {
            return block.title
        }
        return plan.phaseRoadmap.first?.title ?? "Fondations"
    }

    static func nutritionOneLiner(day: OriginProgramDay, plan: FaceOriginPlan) -> String {
        let n = day.nutrition
        if n.isOMAD || plan.nutritionProtocol.mealPlanStyle == .omad {
            let meal = n.omadMeal ?? n.lunch
            return meal.isEmpty ? "1 repas dense (OMAD)" : "OMAD · \(truncate(meal, max: 48))"
        }
        if n.mealPlanStyle == .twoMeals || plan.nutritionProtocol.mealPlanStyle == .twoMeals {
            return "2 repas · \(truncate(n.lunch, max: 28))"
        }
        if !n.lunch.isEmpty {
            return "Déjeuner · \(truncate(n.lunch, max: 40))"
        }
        return truncate(plan.nutritionProtocol.hydrationGuide, max: 60)
    }

    static func sleepOneLiner(_ sleep: OriginDaySleep) -> String {
        "\(sleep.targetBedtime) → \(sleep.targetWake) · \(String(format: "%.1f", sleep.targetHours)) h"
    }

    static func trainingOneLiner(_ training: OriginDayTraining?) -> String? {
        guard let training else { return nil }
        let first = training.exercises.first?.name ?? training.sessionName
        return "\(training.sessionName) · \(training.durationMinutes) min · \(first)"
    }

    // MARK: - Helpers

    private static func firstSentence(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Protocole personnalisé" }
        let sentence = trimmed.split(separator: ".").first.map(String.init) ?? trimmed
        return truncate(sentence, max: maxLength)
    }

    static func truncate(_ text: String, max: Int) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > max else { return t }
        return String(t.prefix(max - 1)) + "…"
    }

    private static func rangeContains(_ week: Int, in rangeLabel: String) -> Bool {
        let digits = rangeLabel.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard let low = digits.first else { return false }
        let high = digits.count > 1 ? digits[1] : low
        return week >= low && week <= high
    }
}
