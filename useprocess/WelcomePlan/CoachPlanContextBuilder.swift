import Foundation

/// Contexte Protocole Origine injecté dans **tous** les appels IA (coach, repas, mémoire).
enum CoachPlanContextBuilder {

    // MARK: - Bloc compact (résumé plan)

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
            "• Nutrition : \(plan.nutritionPlanType.label) · Créneaux : \(plan.configuredMealSlots.map(\.rawValue).joined(separator: ", "))",
            "• Zéro pilule — 100 % naturel",
            "• Tâches cochées : \(completed)"
        ]

        let face = plan.faceProtocol
        if !face.focusAreas.isEmpty {
            lines.append("• Visage : \(face.focusAreas.prefix(3).joined(separator: " · "))")
        }
        if ProcessContinuousHabits.all.first != nil {
            lines.append("  → Habitudes 24/7 : \(ProcessContinuousHabits.all.map(\.title).joined(separator: ", "))")
        }
        if !plan.postureProtocol.mobilityBlocks.isEmpty {
            lines.append("• Posture : \(plan.postureProtocol.mobilityBlocks.count) blocs mobilité quotidiens")
        }
        if let sleepStep = plan.sleepProtocol.eveningRoutine.first(where: { line in
            let lower = line.lowercased()
            return lower.contains("côté") || lower.contains("spot t") || lower.contains("langue")
        }) {
            lines.append("• Sommeil : \(sleepStep)")
        }

        if let today {
            lines.append("• Aujourd'hui (\(today.weekdayLabel)) : \(today.title)")
            if let training = today.training {
                lines.append("  → Séance : \(training.sessionName) (\(training.durationMinutes) min)")
            }
        }

        if !memory.planAdjustments.isEmpty {
            lines.append("• Derniers ajustements : \(memory.planAdjustments.prefix(3).joined(separator: " | "))")
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
            lines.append("• Conversations passées : \(convs)")
        }

        if let summary = memory.aiSummary, !summary.isEmpty {
            lines.append("• Mémoire IA globale :\n\(summary)")
        }

        lines.append("Règle : ancre chaque réponse au plan ET aux repas du jour ci-dessous. Ne propose jamais un repas qui contredit les brouillons/validations déjà faits sans le dire.")

        return lines.joined(separator: "\n")
    }

    // MARK: - Repas du jour (validés, brouillons IA, propositions)

    @MainActor
    static func todayMealsBlock(plan: FaceOriginPlan) -> String {
        let store = WelcomePlanStore.shared
        let dayIdx = plan.calendar.currentProgramDayIndex()
        guard let day = plan.calendar.day(globalIndex: dayIdx) else { return "" }

        let entries = PlanDayMealsProvider.entries(plan: plan, day: day, store: store)
        guard !entries.isEmpty else { return "" }

        var lines: [String] = [
            "REPAS AUJOURD'HUI (\(day.weekdayLabel), jour \(dayIdx + 1)) — état réel dans l'app :"
        ]

        for entry in entries {
            let hasDraft = store.draftMealContent(for: day.id, slot: entry.slot) != nil
            let status: String
            if entry.isValidated {
                status = "validé"
            } else if hasDraft {
                status = "brouillon IA (personnalisé, pas encore validé)"
            } else {
                status = "proposition Process (non validé)"
            }

            let ingredients = entry.meal.items
                .map { "\($0.name) (\($0.quantity))" }
                .joined(separator: ", ")

            lines.append("• \(entry.slot.rawValue) [\(status)] : \(entry.meal.name)")
            if !ingredients.isEmpty {
                lines.append("  Ingrédients : \(ingredients)")
            }
            if !entry.meal.prepSummary.isEmpty {
                lines.append("  Préparation : \(entry.meal.prepSummary)")
            }
            if entry.meal.showsScore, entry.meal.protocolScore > 0 {
                lines.append("  Score protocole : \(entry.meal.protocolScore)/100")
            }
        }

        lines.append("Si l'utilisateur parle d'un ingrédient manquant ou d'une substitution, pars de ces repas — ne repars pas de zéro.")

        return lines.joined(separator: "\n")
    }

    // MARK: - Questionnaire Origine (contraintes perso)

    static func questionnaireBlock(answers: [String: WelcomePlanAnswer]) -> String {
        guard !answers.isEmpty else { return "" }

        let keys: [(id: String, label: String)] = [
            ("face_concerns", "Priorités visage"),
            ("body_fat_feel", "Ressenti corporel"),
            ("nutrition_quality", "Qualité nutrition actuelle"),
            ("processed_food", "Ultra-transformés"),
            ("animal_protein", "Protéines animales"),
            ("hydration_level", "Hydratation"),
            ("current_meals_count", "Repas/jour actuellement"),
            ("target_meals_count", "Structure repas protocole"),
            ("alcohol_frequency", "Alcool"),
            ("caffeine_afternoon", "Caféine après 14h"),
            ("sleep_quality", "Sommeil"),
            ("bedtime", "Coucher"),
            ("wake_time", "Réveil"),
            ("sessions_per_week", "Séances/sem"),
            ("training_location", "Lieu d'entraînement"),
            ("training_experience", "Niveau sport")
        ]

        var lines: [String] = []
        for key in keys {
            guard let answer = answers[key.id] else { continue }
            let text = formattedAnswer(questionId: key.id, answer: answer)
            guard !text.isEmpty else { continue }
            lines.append("• \(key.label) : \(text)")
        }

        guard !lines.isEmpty else { return "" }
        return "QUESTIONNAIRE ORIGINE (contraintes personnelles — respecte-les) :\n" + lines.joined(separator: "\n")
    }

    // MARK: - Modifications récentes dans l'app

    static func recentChangesBlock(plan: FaceOriginPlan?) -> String {
        guard let plan else { return "" }

        var lines: [String] = []

        for mod in plan.progress.modifications.prefix(4) {
            let req = mod.userRequest.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !req.isEmpty else { continue }
            lines.append("• Plan [\(mod.sectionPath)] : «\(String(req.prefix(100)))»")
        }

        for entry in plan.progress.mealHistory.prefix(4) {
            guard let content = entry.content else { continue }
            lines.append("• Repas validé récemment (\(entry.mealSlot.rawValue)) : \(content.name)")
        }

        let notes = plan.progress.userNotes
        if !notes.isEmpty {
            let sample = notes.prefix(2).map { "jour \($0.key) : \($0.value.prefix(60))" }.joined(separator: " · ")
            lines.append("• Notes journal : \(sample)")
        }

        guard !lines.isEmpty else { return "" }
        return "HISTORIQUE MODIFICATIONS APP :\n" + lines.joined(separator: "\n")
    }

    // MARK: - Détail journée (emploi du temps)

    static func todayDetailBlock(plan: FaceOriginPlan) -> String {
        let idx = plan.calendar.currentProgramDayIndex()
        guard let day = plan.calendar.day(globalIndex: idx) else { return "" }

        var parts: [String] = ["EMPLOI DU TEMPS JOUR \(idx + 1) — \(day.title)"]

        parts.append("MATIN : " + day.morning.map { $0.title }.joined(separator: ", "))

        if day.nutrition.isOMAD || day.nutrition.mealPlanStyle == .omad {
            let meal = day.nutrition.omadMeal ?? day.nutrition.lunch
            parts.append("MODÈLE NUTRITION OMAD (calendrier) : \(meal)")
        } else {
            parts.append("MODÈLE NUTRITION (calendrier) : PDJ \(day.nutrition.breakfast) · Déj \(day.nutrition.lunch) · Dîner \(day.nutrition.dinner)")
            if let s = day.nutrition.snack { parts.append("Collation : \(s)") }
        }

        parts.append("Principes du jour : \(day.nutrition.principles.joined(separator: " · "))")
        parts.append("Aliments à privilégier : \(day.nutrition.foodsToday.joined(separator: ", "))")

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

    /// Bloc unifié pour toutes les surfaces IA.
    @MainActor
    static func unifiedPromptSections(plan: FaceOriginPlan?, memory: CoachGlobalMemory, questionnaire: WelcomePlanQuestionnaireState) -> String {
        var sections: [String] = []

        sections.append(compactBlock(plan: plan, memory: memory))

        if let plan {
            sections.append(todayMealsBlock(plan: plan))
            sections.append(todayDetailBlock(plan: plan))
        }

        let questionnaireSection = questionnaireBlock(answers: questionnaire.answers)
        if !questionnaireSection.isEmpty {
            sections.append(questionnaireSection)
        }

        let changesSection = recentChangesBlock(plan: plan)
        if !changesSection.isEmpty {
            sections.append(changesSection)
        }

        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    static func fullPlanJSON(plan: FaceOriginPlan) -> String {
        guard let data = try? JSONEncoder().encode(plan),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return String(json.prefix(12000))
    }

    // MARK: - Private

    private static func formattedAnswer(questionId: String, answer: WelcomePlanAnswer) -> String {
        if answer.skipped { return "passé" }
        if !answer.choiceIds.isEmpty {
            return answer.choiceIds
                .map { WelcomePlanQuestionBank.choiceLabel(for: questionId, choiceId: $0) }
                .joined(separator: ", ")
        }
        let text = answer.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "" : text
    }
}
