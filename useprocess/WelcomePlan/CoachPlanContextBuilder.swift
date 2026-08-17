import Foundation

/// Contexte Plan personnalisé injecté dans **tous** les appels IA (coach, repas, mémoire).
enum CoachPlanContextBuilder {

    // MARK: - Bloc compact (résumé plan)

    @MainActor
    static func compactBlock(plan: FaceOriginPlan?, memory: CoachGlobalMemory) -> String {
        guard let plan else {
            return AppCopy.tSync(
                "PLAN PERSONNALISÉ : en cours de préparation.",
                en: "PERSONALIZED PLAN: currently being prepared."
            )
        }

        let dayIdx = plan.calendar.currentProgramDayIndex()
        let progress = ProcessPlanProgressStore.shared.snapshot
        let today = plan.calendar.day(globalIndex: dayIdx)
        let completed = plan.progress.completedTaskIds.count

        var lines: [String] = [
            AppCopy.tSync(
                "PLAN PERSONNALISÉ (base de TOUTES tes réponses) :",
                en: "PERSONALIZED PLAN (base of ALL your answers):"
            ),
            AppCopy.tSync("• Objectif : \(plan.primaryFaceGoal)", en: "• Goal: \(plan.primaryFaceGoal)"),
            AppCopy.tSync(
                "• Programme debloat : jour \(progress.elapsedProgramDays)/\(progress.totalProgramDays)",
                en: "• Debloat program: day \(progress.elapsedProgramDays)/\(progress.totalProgramDays)"
            ),
            AppCopy.tSync(
                "• Durée debloat : \(progress.weeksLabel)\(progress.durationAdjustmentDays != 0 ? ", ajustement \(abs(progress.durationAdjustmentDays)) j" : "")",
                en: "• Debloat duration: \(progress.weeksLabel)\(progress.durationAdjustmentDays != 0 ? ", adjustment \(abs(progress.durationAdjustmentDays)) d" : "")"
            ),
            AppCopy.tSync("• Jours validés : \(progress.validatedDays)", en: "• Validated days: \(progress.validatedDays)"),
        ]
        if progress.remainingProgramDays > 0, let end = progress.estimatedEndDate {
            lines.append(AppCopy.tSync(
                "• Debloat visé dans \(progress.remainingProgramDays) j · \(Self.formatShortDate(end))",
                en: "• Debloat target in \(progress.remainingProgramDays) d · \(Self.formatShortDate(end))"
            ))
        }
        lines.append(contentsOf: [
            AppCopy.tSync(
                "• Cardio cible : \(max(plan.trainingProtocol.sessionsPerWeek, ProcessDebloatValidation.weeklyCardioMinimum))×/sem (idéal chaque jour) · Sommeil \(String(format: "%.1f", plan.sleepProtocol.targetHours)) h",
                en: "• Cardio target: \(max(plan.trainingProtocol.sessionsPerWeek, ProcessDebloatValidation.weeklyCardioMinimum))×/wk (ideally every day) · Sleep \(String(format: "%.1f", plan.sleepProtocol.targetHours)) h"
            ),
            AppCopy.tSync(
                "• Nutrition : \(plan.nutritionPlanType.label) · Créneaux : \(plan.configuredMealSlots.map(\.displayTitle).joined(separator: ", "))",
                en: "• Nutrition: \(plan.nutritionPlanType.label) · Slots: \(plan.configuredMealSlots.map(\.displayTitle).joined(separator: ", "))"
            ),
            AppCopy.tSync("• Zéro pilule — 100 % naturel", en: "• Zero pills — 100% natural"),
            AppCopy.tSync("• Tâches cochées : \(completed)", en: "• Tasks checked: \(completed)")
        ])

        let face = plan.faceProtocol
        if !face.focusAreas.isEmpty {
            lines.append(AppCopy.tSync(
                "• Visage : \(face.focusAreas.prefix(3).joined(separator: " · "))",
                en: "• Face: \(face.focusAreas.prefix(3).joined(separator: " · "))"
            ))
        }
        if ProcessContinuousHabits.all.first != nil {
            lines.append(AppCopy.tSync(
                "  → Habitudes 24/7 : \(ProcessContinuousHabits.all.map(\.title).joined(separator: ", "))",
                en: "  → 24/7 habits: \(ProcessContinuousHabits.all.map(\.title).joined(separator: ", "))"
            ))
        }
        if !plan.postureProtocol.mobilityBlocks.isEmpty {
            lines.append(AppCopy.tSync(
                "• Posture : \(plan.postureProtocol.mobilityBlocks.count) blocs mobilité quotidiens",
                en: "• Posture: \(plan.postureProtocol.mobilityBlocks.count) daily mobility blocks"
            ))
        }
        if let sleepStep = plan.sleepProtocol.eveningRoutine.first(where: { line in
            let lower = line.lowercased()
            return lower.contains("côté") || lower.contains("spot t") || lower.contains("langue")
                || lower.contains("side") || lower.contains("tongue") || lower.contains("palate")
        }) {
            lines.append(AppCopy.tSync("• Sommeil : \(sleepStep)", en: "• Sleep: \(sleepStep)"))
        }

        if let today {
            lines.append(AppCopy.tSync(
                "• Aujourd'hui (\(today.weekdayLabel)) : \(today.title)",
                en: "• Today (\(today.weekdayLabel)): \(today.title)"
            ))
            let cardio = DebloatCardioDayCatalog.session()
            lines.append(AppCopy.tSync(
                "  → Cardio obligatoire : \(cardio.title) — \(cardio.prescriptionLine)",
                en: "  → Required cardio: \(cardio.title) — \(cardio.prescriptionLine)"
            ))
            lines.append(AppCopy.tSync(
                "  → \(DebloatCardioDayCatalog.frequencyCaption) · aucun autre cardio",
                en: "  → \(DebloatCardioDayCatalog.frequencyCaption) · no other cardio"
            ))
            lines.append(AppCopy.tSync(
                "  → Circuit / postures disponible dans Cardio et Circuit",
                en: "  → Circuit / postures available in Cardio & Circuit"
            ))
        }

        if !memory.planAdjustments.isEmpty {
            lines.append(AppCopy.tSync(
                "• Derniers ajustements : \(memory.planAdjustments.prefix(3).joined(separator: " | "))",
                en: "• Latest adjustments: \(memory.planAdjustments.prefix(3).joined(separator: " | "))"
            ))
        }

        let recentFeedbacks = plan.progress.mealFeedbacks.prefix(2)
        if !recentFeedbacks.isEmpty {
            let fb = recentFeedbacks.map { "\($0.feeling.displayTitle) (\($0.rating)/5)" }.joined(separator: ", ")
            lines.append(AppCopy.tSync(
                "• Feedback repas récent : \(fb)",
                en: "• Recent meal feedback: \(fb)"
            ))
        }

        if !memory.keyFacts.isEmpty {
            lines.append(AppCopy.tSync(
                "• Mémoire utilisateur : \(memory.keyFacts.prefix(4).joined(separator: " · "))",
                en: "• User memory: \(memory.keyFacts.prefix(4).joined(separator: " · "))"
            ))
        }

        if !memory.conversationDigests.isEmpty {
            let convs = memory.conversationDigests.prefix(4).map { "«\($0.title)»" }.joined(separator: ", ")
            lines.append(AppCopy.tSync(
                "• Conversations passées : \(convs)",
                en: "• Past conversations: \(convs)"
            ))
        }

        if let summary = memory.aiSummary, !summary.isEmpty {
            lines.append(AppCopy.tSync("• Mémoire IA globale :\n\(summary)", en: "• Global AI memory:\n\(summary)"))
        }

        lines.append(AppCopy.tSync(
            "Règle : ancre chaque réponse au plan ET aux repas debloat ci-dessous. Ne propose jamais un repas qui contredit les brouillons/validations déjà faits sans le dire.",
            en: "Rule: anchor every answer to the plan AND the debloat meals below. Never propose a meal that contradicts existing drafts/validations without saying so."
        ))

        return lines.joined(separator: "\n")
    }

    // MARK: - Repas debloat (validés, brouillons IA, propositions)

    @MainActor
    static func todayMealsBlock(plan: FaceOriginPlan) -> String {
        let store = WelcomePlanStore.shared
        let dayIdx = plan.calendar.currentProgramDayIndex()
        guard let day = plan.calendar.day(globalIndex: dayIdx) else { return "" }

        let entries = PlanDayMealsProvider.entries(plan: plan, day: day, store: store)
        guard !entries.isEmpty else { return "" }

        var lines: [String] = [
            AppCopy.tSync(
                "REPAS AUJOURD'HUI (\(day.weekdayLabel), jour \(dayIdx + 1)) — état réel dans l'app :",
                en: "TODAY'S MEALS (\(day.weekdayLabel), day \(dayIdx + 1)) — real state in the app:"
            )
        ]

        for entry in entries {
            let hasDraft = store.draftMealContent(for: day.id, slot: entry.slot) != nil
            let status: String
            if entry.isValidated {
                status = AppCopy.tSync("validé", en: "validated")
            } else if hasDraft {
                status = AppCopy.tSync(
                    "brouillon IA (personnalisé, pas encore validé)",
                    en: "AI draft (personalized, not validated yet)"
                )
            } else {
                status = AppCopy.tSync(
                    "proposition Process (non validé)",
                    en: "Process suggestion (not validated)"
                )
            }

            let ingredients = entry.meal.foodItems
                .map { "\($0.localizedName) (\($0.localizedQuantity))" }
                .joined(separator: ", ")

            lines.append("• \(entry.slot.displayTitle) [\(status)] : \(entry.meal.localizedDisplayName)")
            if !ingredients.isEmpty {
                lines.append(AppCopy.tSync("  Ingrédients : \(ingredients)", en: "  Ingredients: \(ingredients)"))
            }
            if !entry.meal.localizedPrep.isEmpty {
                lines.append(AppCopy.tSync("  Préparation : \(entry.meal.localizedPrep)", en: "  Prep: \(entry.meal.localizedPrep)"))
            }
            if entry.meal.showsScore, entry.meal.protocolScore > 0 {
                lines.append(AppCopy.tSync(
                    "  Score protocole : \(entry.meal.protocolScore)/100",
                    en: "  Protocol score: \(entry.meal.protocolScore)/100"
                ))
            }
        }

        lines.append(AppCopy.tSync(
            "Si l'utilisateur parle d'un ingrédient manquant ou d'une substitution, pars de ces repas — ne repars pas de zéro.",
            en: "If the user mentions a missing ingredient or a substitution, start from these meals — don't start from scratch."
        ))

        return lines.joined(separator: "\n")
    }

    // MARK: - Questionnaire du plan personnalisé (contraintes perso)

    static func questionnaireBlock(answers: [String: WelcomePlanAnswer]) -> String {
        guard !answers.isEmpty else { return "" }

        let keys: [(id: String, label: String)] = [
            ("face_concerns", AppCopy.tSync("Priorités visage", en: "Face priorities")),
            ("body_fat_feel", AppCopy.tSync("Ressenti corporel", en: "Body feel")),
            ("nutrition_quality", AppCopy.tSync("Qualité nutrition actuelle", en: "Current nutrition quality")),
            ("processed_food", AppCopy.tSync("Ultra-transformés", en: "Ultra-processed foods")),
            ("animal_protein", AppCopy.tSync("Protéines animales", en: "Animal protein")),
            ("hydration_level", AppCopy.tSync("Hydratation", en: "Hydration")),
            ("current_meals_count", AppCopy.tSync("Repas/jour actuellement", en: "Meals/day currently")),
            ("target_meals_count", AppCopy.tSync("Structure repas protocole", en: "Protocol meal structure")),
            ("alcohol_frequency", AppCopy.tSync("Alcool", en: "Alcohol")),
            ("caffeine_afternoon", AppCopy.tSync("Caféine après 14h", en: "Caffeine after 2pm")),
            ("sleep_quality", AppCopy.tSync("Sommeil", en: "Sleep")),
            ("bedtime", AppCopy.tSync("Coucher", en: "Bedtime")),
            ("wake_time", AppCopy.tSync("Réveil", en: "Wake-up")),
            ("sessions_per_week", AppCopy.tSync("Cardio/sem", en: "Cardio/wk")),
            ("training_location", AppCopy.tSync("Lieu cardio", en: "Cardio location")),
            ("training_experience", AppCopy.tSync("Niveau activité", en: "Activity level"))
        ]

        var lines: [String] = []
        for key in keys {
            guard let answer = answers[key.id] else { continue }
            let text = formattedAnswer(questionId: key.id, answer: answer)
            guard !text.isEmpty else { continue }
            lines.append("• \(key.label) : \(text)")
        }

        guard !lines.isEmpty else { return "" }
        return AppCopy.tSync(
            "QUESTIONNAIRE ORIGINE (contraintes personnelles — respecte-les) :\n",
            en: "ORIGIN QUESTIONNAIRE (personal constraints — respect them):\n"
        ) + lines.joined(separator: "\n")
    }

    // MARK: - Modifications récentes dans l'app

    @MainActor
    static func recentChangesBlock(plan: FaceOriginPlan?) -> String {
        guard let plan else { return "" }

        var lines: [String] = []

        for mod in plan.progress.modifications.prefix(4) {
            let req = mod.userRequest.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !req.isEmpty else { continue }
            lines.append(AppCopy.tSync(
                "• Plan [\(mod.sectionPath)] : «\(String(req.prefix(100)))»",
                en: "• Plan [\(mod.sectionPath)]: “\(String(req.prefix(100)))”"
            ))
        }

        for entry in plan.progress.mealHistory.prefix(4) {
            guard let content = entry.content else { continue }
            lines.append(AppCopy.tSync(
                "• Repas validé récemment (\(entry.mealSlot.displayTitle)) : \(content.name)",
                en: "• Recently logged meal (\(entry.mealSlot.displayTitle)): \(content.name)"
            ))
        }

        let notes = plan.progress.userNotes
        if !notes.isEmpty {
            let sample = notes.prefix(2).map { "jour \($0.key) : \($0.value.prefix(60))" }.joined(separator: " · ")
            lines.append(AppCopy.tSync("• Notes journal : \(sample)", en: "• Journal notes: \(sample)"))
        }

        guard !lines.isEmpty else { return "" }
        return AppCopy.tSync(
            "HISTORIQUE MODIFICATIONS APP :\n",
            en: "APP CHANGE HISTORY:\n"
        ) + lines.joined(separator: "\n")
    }

    // MARK: - Détail journée (emploi du temps)

    @MainActor
    static func todayDetailBlock(plan: FaceOriginPlan) -> String {
        let idx = plan.calendar.currentProgramDayIndex()
        guard let day = plan.calendar.day(globalIndex: idx) else { return "" }

        var parts: [String] = [
            AppCopy.tSync(
                "EMPLOI DU TEMPS JOUR \(idx + 1) — \(day.title)",
                en: "DAY \(idx + 1) SCHEDULE — \(day.title)"
            )
        ]

        parts.append(AppCopy.tSync(
            "MATIN : " + day.morning.map { $0.title }.joined(separator: ", "),
            en: "MORNING: " + day.morning.map { $0.title }.joined(separator: ", ")
        ))

        if day.nutrition.isOMAD || day.nutrition.mealPlanStyle == .omad {
            let meal = day.nutrition.omadMeal ?? day.nutrition.lunch
            parts.append(AppCopy.tSync(
                "MODÈLE NUTRITION OMAD (calendrier) : \(meal)",
                en: "OMAD NUTRITION MODEL (calendar): \(meal)"
            ))
        } else {
            parts.append(AppCopy.tSync(
                "MODÈLE NUTRITION (calendrier) : PDJ \(day.nutrition.breakfast) · Déj \(day.nutrition.lunch) · Dîner \(day.nutrition.dinner)",
                en: "NUTRITION MODEL (calendar): Breakfast \(day.nutrition.breakfast) · Lunch \(day.nutrition.lunch) · Dinner \(day.nutrition.dinner)"
            ))
            if let s = day.nutrition.snack {
                parts.append(AppCopy.tSync("Collation : \(s)", en: "Snack: \(s)"))
            }
        }

        parts.append(AppCopy.tSync(
            "Principes du jour : \(day.nutrition.principles.joined(separator: " · "))",
            en: "Today’s principles: \(day.nutrition.principles.joined(separator: " · "))"
        ))
        parts.append(AppCopy.tSync(
            "Aliments à privilégier : \(day.nutrition.foodsToday.joined(separator: ", "))",
            en: "Foods to prioritize: \(day.nutrition.foodsToday.joined(separator: ", "))"
        ))

        let cardio = DebloatCardioDayCatalog.session()
        parts.append(AppCopy.tSync(
            "CARDIO OBLIGATOIRE : \(cardio.title) — \(cardio.prescriptionLine) — \(DebloatCardioDayCatalog.frequencyCaption)",
            en: "REQUIRED CARDIO: \(cardio.title) — \(cardio.prescriptionLine) — \(DebloatCardioDayCatalog.frequencyCaption)"
        ))
        parts.append(AppCopy.tSync(
            "POSTURE / CIRCUIT : " + day.posture.map(\.title).joined(separator: ", "),
            en: "POSTURE / CIRCUIT: " + day.posture.map(\.title).joined(separator: ", ")
        ))
        let continuous = ProcessContinuousHabits.all.map(\.title).joined(separator: ", ")
        parts.append(AppCopy.tSync("24/7 : \(continuous)", en: "24/7: \(continuous)"))
        parts.append(AppCopy.tSync(
            "SOIR : " + day.evening.map(\.title).joined(separator: ", "),
            en: "EVENING: " + day.evening.map(\.title).joined(separator: ", ")
        ))

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
        if answer.skipped { return AppCopy.tSync("passé", en: "skipped") }
        if !answer.choiceIds.isEmpty {
            return answer.choiceIds
                .map { WelcomePlanQuestionBank.choiceLabel(for: questionId, choiceId: $0) }
                .joined(separator: ", ")
        }
        let text = answer.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "" : text
    }

    private static func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.currentLocale
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
