import Foundation

/// Présentation courte du Protocole Origine — priorités, jour courant, libellés compacts.
enum OriginPlanPresenter {

    // MARK: - Jour courant

    static func todayDay(in plan: FaceOriginPlan, date: Date = Date()) -> OriginProgramDay? {
        let index = plan.calendar.currentProgramDayIndex(from: date)
        return plan.calendar.day(globalIndex: index)
    }

    static func todayChecklist(from day: OriginProgramDay, plan: FaceOriginPlan) -> [OriginPlanTask] {
        manualJournalTasks(from: day, plan: plan)
    }

    static func journalSections(for day: OriginProgramDay, calendar: OriginProgramCalendar) -> [JournalSection] {
        chronologicalPhases(for: day, calendar: calendar).map { phase in
            JournalSection(
                id: phase.id,
                title: phase.title,
                subtitle: phase.timeHint,
                tasks: phase.checklistTasks
            )
        }
    }

    // MARK: - Timeline chronologique (page Plan)

    enum PlanDayPhaseKind: Equatable {
        case checklist([OriginPlanTask])
        case meals
        case training(OriginDayTraining)
        case autoTracking
    }

    struct PlanDayPhase: Identifiable, Equatable {
        let id: String
        let title: String
        var timeHint: String?
        let kind: PlanDayPhaseKind

        var checklistTasks: [OriginPlanTask] {
            if case .checklist(let tasks) = kind { return tasks }
            return []
        }

        var isActionOnly: Bool {
            switch kind {
            case .checklist: return false
            case .meals, .training, .autoTracking: return true
            }
        }
    }

    /// Ordre logique d'une journée : hier soir → matin → repas → sport → mouvement → posture → visage → soir.
    static func chronologicalPhases(
        for day: OriginProgramDay,
        calendar: OriginProgramCalendar,
        includeAutoTracking: Bool = false,
        includeMeals: Bool = true,
        includeTraining: Bool = true
    ) -> [PlanDayPhase] {
        let morning = visibleJournalTasks(day.morning)
        let posture = visibleJournalTasks(day.posture)
        let face = visibleJournalTasks(day.face)
        let evening = visibleJournalTasks(day.evening)
        var phases: [PlanDayPhase] = []

        let lastNight = visibleJournalTasks(lastNightJournalTasks(dayId: day.id))
        if !lastNight.isEmpty {
            phases.append(.init(
                id: "lastNight",
                title: "Hier soir",
                timeHint: "Avant le coucher",
                kind: .checklist(lastNight)
            ))
        }

        if !morning.isEmpty {
            phases.append(.init(
                id: "morning",
                title: "Matin",
                timeHint: "Au réveil",
                kind: .checklist(morning)
            ))
        }

        if includeMeals {
            phases.append(.init(
                id: "meals",
                title: "Repas",
                timeHint: mealPhaseHint(for: day),
                kind: .meals
            ))
        }

        if includeTraining, let training = day.training {
            phases.append(.init(
                id: "training",
                title: "Entraînement",
                timeHint: "\(training.durationMinutes) min · \(training.sessionName)",
                kind: .training(training)
            ))
        }

        if includeAutoTracking {
            phases.append(.init(
                id: "movement",
                title: "Mouvement",
                timeHint: "Suivi automatique · Santé",
                kind: .autoTracking
            ))
        }

        if !posture.isEmpty {
            phases.append(.init(
                id: "posture",
                title: "Posture",
                timeHint: "Dans la journée",
                kind: .checklist(posture)
            ))
        }

        if !face.isEmpty {
            phases.append(.init(
                id: "face",
                title: "Visage",
                timeHint: "Routine",
                kind: .checklist(face)
            ))
        }

        if !evening.isEmpty {
            phases.append(.init(
                id: "evening",
                title: "Soir",
                timeHint: nightRangeLabel(for: day, calendar: calendar) ?? "Avant le coucher",
                kind: .checklist(evening)
            ))
        }

        return phases
    }

    private static func mealPhaseHint(for day: OriginProgramDay) -> String {
        if day.nutrition.isOMAD { return "Un repas principal" }
        let configured = [
            day.nutrition.breakfast.isEmpty ? nil : "Petit-déj",
            day.nutrition.lunch.isEmpty ? nil : "Déjeuner",
            day.nutrition.dinner.isEmpty ? nil : "Dîner"
        ].compactMap { $0 }
        if configured.isEmpty { return "Valide tes repas du jour" }
        return configured.joined(separator: " · ")
    }

    static func manualJournalTasks(from day: OriginProgramDay, plan: FaceOriginPlan) -> [OriginPlanTask] {
        let tasks = visibleJournalTasks(
            lastNightJournalTasks(dayId: day.id)
            + day.morning
            + day.posture
            + day.face
            + day.evening
        )
        return sortedJournalTasks(tasks, dayId: day.id, plan: plan)
    }

    /// Tri debloat : impact physiologique, puis leviers faibles du plan, puis statut (à faire en premier).
    static func sortedJournalTasks(
        _ tasks: [OriginPlanTask],
        dayId: String,
        plan: FaceOriginPlan
    ) -> [OriginPlanTask] {
        tasks.sorted { lhs, rhs in
            let leftPriority = journalTaskPriority(for: lhs, in: plan)
            let rightPriority = journalTaskPriority(for: rhs, in: plan)
            if leftPriority != rightPriority { return leftPriority < rightPriority }

            let leftStatus = journalTaskStatusRank(plan.progress.status(for: lhs.id, dayId: dayId))
            let rightStatus = journalTaskStatusRank(plan.progress.status(for: rhs.id, dayId: dayId))
            if leftStatus != rightStatus { return leftStatus < rightStatus }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    /// Score bas = priorité haute. Hydratation d'abord, puis le reste du protocole debloat.
    static func journalTaskPriority(for task: OriginPlanTask, in plan: FaceOriginPlan) -> Int {
        let text = searchableText(for: task)
        var score: Int

        switch true {
        case isHydrationJournalTask(task):
            score = 0
        case text.contains("repas tardif"):
            score = 15
        case text.contains("lumiere") || text.contains("lumière"):
            score = 20
        case text.contains("alcool"):
            score = 25
        case text.contains("eau froide"):
            score = 30
        case text.contains("lymph") || text.contains("massage"):
            score = 35
        case text.contains("posture"):
            score = 40
        case text.contains("ecran") || text.contains("écran") || text.contains("couvre-feu"):
            score = 45
        default:
            score = 50
        }

        let weakPillars = impactPriorities(from: plan, limit: 3)
        for (index, weak) in weakPillars.enumerated() {
            if taskMatchesWeakPillar(task, weakPillar: weak.pillar) {
                score -= (3 - index)
                break
            }
        }

        return score
    }

    private static func taskMatchesWeakPillar(_ task: OriginPlanTask, weakPillar: String) -> Bool {
        let taskCategory = taskPillarCategory(for: task)
        let weakCategory = weakPillarCategory(weakPillar)
        return taskCategory == weakCategory
    }

    private static func taskPillarCategory(for task: OriginPlanTask) -> String {
        let text = searchableText(for: task)
        let pillar = task.pillar
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if text.contains("hydrat") || text.contains("alcool") || text.contains("repas") {
            return "nutrition"
        }
        if pillar.contains("sommeil") || text.contains("ecran") || text.contains("écran") || text.contains("couvre-feu") {
            return "hormones"
        }
        if pillar.contains("hormone") || text.contains("lumiere") || text.contains("lumière") {
            return "hormones"
        }
        if pillar.contains("visage") || text.contains("eau froide") || text.contains("lymph") || text.contains("massage") {
            return "visage"
        }
        if pillar.contains("posture") {
            return "posture"
        }
        if pillar.contains("entrain") {
            return "training"
        }
        return pillar
    }

    private static func weakPillarCategory(_ pillar: String) -> String {
        let normalized = pillar
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        if normalized.contains("hormone") { return "hormones" }
        if normalized.contains("posture") || normalized.contains("fascia") { return "posture" }
        if normalized.contains("visage") || normalized.contains("result") { return "visage" }
        if normalized.contains("entrain") { return "training" }
        if normalized.contains("nutrition") { return "nutrition" }
        return normalized
    }

    private static func journalTaskStatusRank(_ status: JournalTaskStatus?) -> Int {
        switch status {
        case nil: return 0
        case .failed: return 1
        case .completed: return 2
        }
    }

    static func isAutomaticStepsTask(_ task: OriginPlanTask) -> Bool {
        let text = searchableText(for: task)
        return text.contains("marche")
            || text.contains("healthkit")
            || text.contains("objectif \(ProcessDailyTargets.dailySteps) pas")
            || text.contains("steps")
    }

    static func visibleJournalTasks(_ tasks: [OriginPlanTask]) -> [OriginPlanTask] {
        tasks.filter { !isHiddenJournalChecklistTask($0) }
    }

    static func isHiddenJournalChecklistTask(_ task: OriginPlanTask) -> Bool {
        let text = searchableText(for: task)
        if isAutomaticStepsTask(task) { return true }
        if text.contains("mewing") { return true }
        if text.contains("mastication") || text.contains("machées") || text.contains("mâchées") { return true }
        if text.contains("routine soir") { return true }
        if (text.contains("dîner") || text.contains("diner")) && text.contains("debloat") { return true }
        if text.contains("telephone") && text.contains("lit") { return true }
        if text.contains("alimentation parfaite") { return true }
        if text.contains("scan visage") { return true }
        return false
    }

    static func isHydrationJournalTask(_ task: OriginPlanTask) -> Bool {
        if task.id.contains("hydrate") { return true }
        let text = searchableText(for: task)
        if text.contains("hydrat") { return true }
        if text.contains("boire") && text.contains("litre") { return true }
        return task.title == ProcessHydrationGuide.dailyTaskTitle
    }

    private static func searchableText(for task: OriginPlanTask) -> String {
        "\(task.title) \(task.detail) \(task.pillar)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    struct JournalSection: Identifiable {
        let id: String
        let title: String
        var subtitle: String?
        let tasks: [OriginPlanTask]
    }

    static func lastNightJournalTasks(dayId: String) -> [OriginPlanTask] {
        [
            OriginPlanTask(
                id: "\(dayId).hier-soir.repas-tardif",
                title: "Pas de repas tardif",
                detail: "Rien de lourd dans les 2–3 h avant le coucher.",
                pillar: "Nutrition",
                durationMinutes: nil,
                isOptional: false
            )
        ]
    }

    static func programDay(in plan: FaceOriginPlan, for date: Date = Date()) -> OriginProgramDay? {
        guard let start = plan.calendar.startedAt else {
            return todayDay(in: plan, date: date)
        }
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: start),
            to: cal.startOfDay(for: date)
        ).day ?? 0
        guard days >= 0, days < plan.calendar.totalDays else { return nil }
        return plan.calendar.day(globalIndex: days)
    }

    // MARK: - Disponibilité journal (passé / aujourd'hui / futur)

    enum JournalDayAvailability: Equatable {
        case editable(day: OriginProgramDay, date: Date)
        case future(date: Date)
        case outsidePlan(date: Date)

        var isEditable: Bool {
            if case .editable = self { return true }
            return false
        }
    }

    static func journalDayStart(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func isFutureJournalDate(_ date: Date, relativeTo now: Date = Date()) -> Bool {
        journalDayStart(date) > journalDayStart(now)
    }

    static func journalDayAvailability(for date: Date, in plan: FaceOriginPlan) -> JournalDayAvailability {
        let dayStart = journalDayStart(date)
        if isFutureJournalDate(date) {
            return .future(date: dayStart)
        }
        if let day = programDay(in: plan, for: date) {
            return .editable(day: day, date: dayStart)
        }
        return .outsidePlan(date: dayStart)
    }

    /// Bandeau journal : 7 jours avant → 7 jours après aujourd'hui, limité aux jours du protocole.
    static func journalStripDates(in plan: FaceOriginPlan, relativeTo today: Date = Date()) -> [Date] {
        journalStripDates(relativeTo: today).filter { programDay(in: plan, for: $0) != nil }
    }

    /// Bandeau journal : 7 jours avant → 7 jours après aujourd'hui.
    static func journalStripDates(relativeTo today: Date = Date()) -> [Date] {
        let cal = Calendar.current
        let todayStart = journalDayStart(today)
        return (-7...7).compactMap { cal.date(byAdding: .day, value: $0, to: todayStart) }
    }

    static func calendarDate(for day: OriginProgramDay, in plan: FaceOriginPlan) -> Date? {
        guard let start = plan.calendar.startedAt else { return nil }
        return Calendar.current.date(
            byAdding: .day,
            value: day.globalDayIndex,
            to: journalDayStart(start)
        )
    }

    static func isEditableJournalDay(dayId: String, in plan: FaceOriginPlan) -> Bool {
        guard let day = plan.calendar.weeks.flatMap(\.days).first(where: { $0.id == dayId }) else {
            return false
        }
        guard let date = calendarDate(for: day, in: plan) else {
            guard plan.calendar.startedAt == nil else { return false }
            return !isFutureJournalDate(Date())
        }
        return journalDayAvailability(for: date, in: plan).isEditable
    }

    static func isDayJournalComplete(plan: FaceOriginPlan, day: OriginProgramDay) -> Bool {
        let tasks = manualJournalTasks(from: day, plan: plan)
        guard !tasks.isEmpty else { return false }
        return tasks.allSatisfy { plan.progress.status(for: $0.id, dayId: day.id) == .completed }
    }

    static func isDayJournalFilled(plan: FaceOriginPlan, day: OriginProgramDay) -> Bool {
        let tasks = manualJournalTasks(from: day, plan: plan)
        guard !tasks.isEmpty else { return false }
        return tasks.allSatisfy { plan.progress.status(for: $0.id, dayId: day.id) != nil }
    }

    struct JournalDayCompletionSummary: Equatable {
        let title: String
        let dateLabel: String
        let analysis: String
        let completedCount: Int
        let failedCount: Int
        let totalCount: Int
        let validatedMeal: String?
    }

    static func journalCompletionSummary(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        date: Date
    ) -> JournalDayCompletionSummary {
        let tasks = manualJournalTasks(from: day, plan: plan)
        let completed = tasks.filter { plan.progress.status(for: $0.id, dayId: day.id) == .completed }
        let failed = tasks.filter { plan.progress.status(for: $0.id, dayId: day.id) == .failed }

        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        let dateLabel = df.string(from: date).capitalized

        var analysisParts: [String] = []
        if failed.isEmpty, completed.count == tasks.count {
            analysisParts.append("Toutes tes habitudes du jour sont validées.")
        } else if failed.isEmpty {
            analysisParts.append("\(completed.count)/\(tasks.count) habitudes validées.")
        } else {
            analysisParts.append("\(completed.count) validées, \(failed.count) à reprendre demain.")
        }

        let phase = phaseHeadline(plan, date: date)
        analysisParts.append("Phase : \(phase).")

        if let meal = plan.progress.validatedMeals[day.id], !meal.isEmpty {
            let mealLabel = MealSuggestionContent.fromStored(meal)?.name ?? truncate(meal, max: 72)
            analysisParts.append("Repas : \(mealLabel).")
        } else if let priority = impactPriorities(from: plan, limit: 1).first {
            analysisParts.append("Levier prioritaire : \(priority.pillar.lowercased()).")
        }

        return JournalDayCompletionSummary(
            title: "Analyse de ta journée",
            dateLabel: dateLabel,
            analysis: analysisParts.joined(separator: " "),
            completedCount: completed.count,
            failedCount: failed.count,
            totalCount: tasks.count,
            validatedMeal: plan.progress.validatedMeals[day.id]
        )
    }

    static func nightRangeLabel(for day: OriginProgramDay, calendar: OriginProgramCalendar) -> String? {
        guard let start = calendar.startedAt else { return nil }
        let cal = Calendar.current
        guard let evening = cal.date(byAdding: .day, value: day.globalDayIndex, to: cal.startOfDay(for: start)),
              let morning = cal.date(byAdding: .day, value: day.globalDayIndex + 1, to: cal.startOfDay(for: start))
        else { return nil }

        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.setLocalizedDateFormatFromTemplate("d MMM")
        return "\(df.string(from: evening)) – \(df.string(from: morning))"
    }

    static func journalDisplayTitle(for task: OriginPlanTask) -> String {
        let title = stripDailyFrequencySuffix(task.title)
        if title.lowercased().contains("hydrat") {
            return ProcessHydrationGuide.dailyTaskTitle
        }
        return title
    }

    static func taskEmoji(for task: OriginPlanTask) -> String {
        let t = task.title.lowercased()
        if t.contains("telephone") || t.contains("téléphone") { return "📱" }
        if t.contains("repas") { return "🍽️" }
        if t.contains("lumière") || t.contains("lumiere") { return "☀️" }
        if t.contains("hydrat") { return "💧" }
        if t.contains("eau froide") { return "🧊" }
        if t.contains("mastic") { return "🍴" }
        if t.contains("alimentation") { return "🥗" }
        if t.contains("drainage") || t.contains("lymph") { return "💆" }
        if t.contains("marche") { return "👟" }
        if t.contains("écran") || t.contains("ecran") { return "📱" }
        if t.contains("sommeil") || t.contains("routine") { return "🌙" }
        if t.contains("caféine") || t.contains("cafeine") { return "☕️" }
        return "✦"
    }

    static func todayTaskCount(in plan: FaceOriginPlan, date: Date = Date()) -> (done: Int, total: Int) {
        guard let day = programDay(in: plan, for: date) ?? todayDay(in: plan, date: date) else { return (0, 0) }
        let tasks = manualJournalTasks(from: day, plan: plan)
        let done = tasks.filter { plan.progress.status(for: $0.id, dayId: day.id) == .completed }.count
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
        if let validated = plan.progress.validatedMeals[day.id], !validated.isEmpty {
            return truncate(validated, max: 56)
        }
        let principles = day.nutrition.principles.prefix(2).joined(separator: " · ")
        if !principles.isEmpty {
            return truncate(principles, max: 56)
        }
        return "Demande une idée de repas à l'IA"
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

    /// Retire les suffixes « /j », « /jour » — le journal est déjà quotidien.
    private static func stripDailyFrequencySuffix(_ text: String) -> String {
        text
            .replacingOccurrences(of: "/j", with: "")
            .replacingOccurrences(of: "/jour", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
