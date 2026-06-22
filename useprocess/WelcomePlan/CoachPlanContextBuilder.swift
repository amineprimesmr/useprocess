import Foundation

enum CoachPlanContextBuilder {

    @MainActor
    static func compactBlock(plan: FaceOriginPlan?, memory: CoachGlobalMemory) -> String {
        guard let plan else {
            return "PROTOCOLE ORIGINE : non généré — invite l'utilisateur à compléter le questionnaire."
        }

        let dayIdx = plan.calendar.currentProgramDayIndex()
        let weekNum = plan.calendar.currentWeekNumber()
        let today = plan.calendar.day(globalIndex: dayIdx)
        let completed = plan.progress.completedTaskIds.count

        var lines: [String] = [
            "PROTOCOLE ORIGINE (base de TOUTES tes réponses) :",
            "• Objectif : \(plan.primaryFaceGoal)",
            "• Semaine \(weekNum)/13 — jour \(dayIdx + 1)/\(max(plan.calendar.totalDays, 1))",
            "• \(plan.trainingProtocol.sessionsPerWeek) séances/sem · Sommeil cible \(String(format: "%.1f", plan.sleepProtocol.targetHours)) h",
            "• Nutrition : \(plan.nutritionPlanType.label)",
            "• Zéro pilule — 100 % naturel",
            "• Tâches cochées : \(completed)"
        ]

        if let today {
            lines.append("• Aujourd'hui (\(today.weekdayLabel)) : \(today.title)")
            if let meal = plan.progress.validatedMeals[today.id],
               let content = MealSuggestionContent.fromStored(meal) {
                lines.append("  → Repas validé : \(content.name) (score \(content.protocolScore)/100)")
            }
            if let training = today.training {
                lines.append("  → Séance : \(training.sessionName) (\(training.durationMinutes) min)")
            }
            if today.nutrition.isOMAD {
                lines.append("  → Nutrition OMAD : \(today.nutrition.omadMeal ?? "repas unique")")
            } else {
                lines.append("  → Nutrition : \(today.nutrition.breakfast) / \(today.nutrition.lunch)")
            }
        }

        if !memory.planAdjustments.isEmpty {
            lines.append("• Derniers ajustements plan : \(memory.planAdjustments.prefix(2).joined(separator: " | "))")
        }

        let recentFeedbacks = plan.progress.mealFeedbacks.prefix(2)
        if !recentFeedbacks.isEmpty {
            let fb = recentFeedbacks.map { "\($0.feeling.rawValue) (\($0.rating)/5)" }.joined(separator: ", ")
            lines.append("• Feedback repas récent : \(fb)")
        }

        if !memory.keyFacts.isEmpty {
            lines.append("• Mémoire utilisateur : \(memory.keyFacts.prefix(4).joined(separator: " · "))")
        }

        if !memory.conversationDigests.isEmpty {
            let convs = memory.conversationDigests.prefix(4).map { "«\($0.title)»" }.joined(separator: ", ")
            lines.append("• Conversations passées (contexte) : \(convs)")
        }

        if let summary = memory.aiSummary, !summary.isEmpty {
            lines.append("• Mémoire IA (toutes conversations) :\n\(summary)")
        }

        lines.append("Règle : ancre chaque réponse au plan. Si l'utilisateur demande une modification → l'app l'applique dans le calendrier automatiquement.")

        return lines.joined(separator: "\n")
    }

    static func todayDetailBlock(plan: FaceOriginPlan) -> String {
        let idx = plan.calendar.currentProgramDayIndex()
        guard let day = plan.calendar.day(globalIndex: idx) else { return "" }

        var parts: [String] = ["JOUR \(idx + 1) — \(day.title)"]

        parts.append("MATIN : " + day.morning.map { $0.title }.joined(separator: ", "))

        if day.nutrition.isOMAD || day.nutrition.mealPlanStyle == .omad {
            let meal = day.nutrition.omadMeal ?? day.nutrition.lunch
            parts.append("NUTRITION OMAD : \(meal)")
        } else {
            parts.append("NUTRITION : PDJ \(day.nutrition.breakfast) · Déj \(day.nutrition.lunch) · Dîner \(day.nutrition.dinner)")
            if let s = day.nutrition.snack { parts.append("Collation : \(s)") }
        }

        if let t = day.training {
            parts.append("TRAINING : \(t.sessionName) — \(t.exercises.map { "\($0.name) \($0.sets)×\($0.reps)" }.joined(separator: " · "))")
        } else {
            parts.append("TRAINING : repos actif / marche")
        }

        parts.append("POSTURE : " + day.posture.map(\.title).joined(separator: ", "))
        let continuous = ProcessContinuousHabits.all.map(\.title).joined(separator: ", ")
        parts.append("24/7 : \(continuous)")
        parts.append("SOIR : " + day.evening.map(\.title).joined(separator: ", "))

        return parts.joined(separator: "\n")
    }

    static func fullPlanJSON(plan: FaceOriginPlan) -> String {
        guard let data = try? JSONEncoder().encode(plan),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return String(json.prefix(12000))
    }
}
