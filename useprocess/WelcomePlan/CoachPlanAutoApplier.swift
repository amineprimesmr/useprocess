import Foundation

enum CoachPlanAutoApplier {

    // MARK: - User request (prioritaire — exécute la demande utilisateur)

    @MainActor
    static func applyUserRequest(_ request: String, plan: inout FaceOriginPlan) -> [String] {
        let lower = request.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        var results: [String] = []

        if matchesOMAD(lower) {
            NutritionPlanType.omad.applyToPlan(&plan)
            results.append("Nutrition → OMAD (1 repas / jour)")
            return results
        }

        if matchesRemoveBreakfast(lower) || lower.contains("2mad") {
            NutritionPlanType.twoMAD.applyToPlan(&plan)
            results.append("Nutrition → 2MAD (déjeuner + dîner)")
            return results
        }

        if lower.contains("2 repas") || lower.contains("deux repas") {
            NutritionPlanType.twoMAD.applyToPlan(&plan)
            results.append("Nutrition → 2MAD (déjeuner + dîner)")
            return results
        }

        if lower.contains("3 repas") || lower.contains("trois repas") {
            NutritionPlanType.threeMeals.applyToPlan(&plan)
            results.append("Nutrition → 3 repas / jour")
            return results
        }

        if let sessions = parseSessionsPerWeek(lower) {
            plan.trainingProtocol.sessionsPerWeek = sessions
            plan.lastUpdated = Date()
            results.append("Entraînement → \(sessions) séance(s)/semaine")
        }

        return results
    }

    private static func matchesOMAD(_ lower: String) -> Bool {
        lower.contains("1 repas") || lower.contains("un repas") || lower.contains("un seul repas")
            || lower.contains("omad") || lower.contains("one meal")
    }

    private static func matchesRemoveBreakfast(_ lower: String) -> Bool {
        let remove = lower.contains("supprime") || lower.contains("enleve") || lower.contains("pas de")
        let breakfast = lower.contains("pdj") || lower.contains("petit-dej") || lower.contains("petit dej")
        return remove && breakfast
    }

    private static func parseSessionsPerWeek(_ lower: String) -> Int? {
        if lower.contains("1 seance") || lower.contains("une seance") { return 1 }
        if lower.contains("2 seances") || lower.contains("deux seances") { return 2 }
        if lower.contains("3 seances") || lower.contains("trois seances") { return 3 }
        if lower.contains("4 seances") || lower.contains("quatre seances") { return 4 }
        return nil
    }

    // MARK: - Coach response

    @MainActor
    static func apply(response: String, focus: CoachPlanFocus, plan: inout FaceOriginPlan) -> Bool {
        let parts = focus.sectionPath.split(separator: "/").map(String.init)

        if parts.first == "global" {
            return applyGlobal(response: response, focus: focus, plan: &plan)
        }

        guard parts.count >= 2 else { return applyGlobal(response: response, focus: focus, plan: &plan) }

        let dayId = parts[0]
        let section = parts[1]

        guard let weekIndex = plan.calendar.weeks.firstIndex(where: { $0.days.contains { $0.id == dayId } }),
              let dayIndex = plan.calendar.weeks[weekIndex].days.firstIndex(where: { $0.id == dayId }) else {
            return applyGlobal(response: response, focus: focus, plan: &plan)
        }

        var day = plan.calendar.weeks[weekIndex].days[dayIndex]
        var applied = false

        switch section {
        case "nutrition":
            applied = applyNutrition(response, to: &day.nutrition)
        case "training":
            if day.training != nil {
                applied = applyTraining(response, to: &day.training!)
            }
        case "sleep":
            applied = applySleep(response, to: &day.sleep)
        case "morning", "posture", "face", "evening":
            applied = applyTasks(response, to: &day, section: section)
        default:
            if section.hasPrefix("extras") {
                applied = applyExtras(response, title: focus.sectionTitle, plan: &plan)
            }
        }

        if applied {
            plan.calendar.weeks[weekIndex].days[dayIndex] = day
            plan.lastUpdated = Date()
        }
        return applied
    }

    private static func applyGlobal(response: String, focus: CoachPlanFocus, plan: inout FaceOriginPlan) -> Bool {
        let path = focus.sectionPath.lowercased()
        let title = focus.sectionTitle.lowercased()

        if path.contains("nutrition") || title.contains("nutrition") {
            guard plan.nutritionProtocol.mealPlanStyle != .omad else { return false }
            var changed = false
            if !extractBulletLines(from: response, fallback: []).isEmpty {
                plan.nutritionProtocol.principles = Array(extractBulletLines(from: response, fallback: plan.nutritionProtocol.principles).prefix(5))
                changed = true
            }
            for weekIndex in plan.calendar.weeks.indices {
                for dayIndex in plan.calendar.weeks[weekIndex].days.indices {
                    if applyNutrition(response, to: &plan.calendar.weeks[weekIndex].days[dayIndex].nutrition) {
                        changed = true
                    }
                }
            }
            plan.lastUpdated = Date()
            return changed
        }

        if path.contains("training") || title.contains("entraînement") || title.contains("entrainement") {
            if let sessions = extractLabel("Séances", from: response).flatMap({ Int($0.filter(\.isNumber)) }) {
                plan.trainingProtocol.sessionsPerWeek = sessions
                plan.lastUpdated = Date()
                return true
            }
        }

        return false
    }

    private static func applyNutrition(_ response: String, to nutrition: inout OriginDayNutrition) -> Bool {
        guard nutrition.mealPlanStyle != .omad else { return false }

        var changed = false
        if let v = extractLabel("Petit-déjeuner", from: response) ?? extractLabel("PDJ", from: response) {
            nutrition.breakfast = CoachFormattedText.sanitizeField(v); changed = true
        }
        if let v = extractLabel("Déjeuner", from: response) {
            nutrition.lunch = CoachFormattedText.sanitizeField(v); changed = true
        }
        if let v = extractLabel("Dîner", from: response) {
            nutrition.dinner = CoachFormattedText.sanitizeField(v); changed = true
        }
        if let v = extractLabel("Collation", from: response) {
            nutrition.snack = CoachFormattedText.sanitizeField(v); changed = true
        }
        if let v = extractLabel("Hydratation", from: response) {
            nutrition.hydration = CoachFormattedText.sanitizeField(v); changed = true
        }
        if let v = extractLabel("Repas unique", from: response) ?? extractLabel("OMAD", from: response) {
            nutrition.mealPlanStyle = .omad
            nutrition.omadMeal = CoachFormattedText.sanitizeField(v)
            nutrition.breakfast = ""
            nutrition.lunch = ""
            nutrition.dinner = ""
            nutrition.snack = nil
            changed = true
        }
        let bullets = extractBulletLines(from: response, fallback: [])
        if !bullets.isEmpty {
            nutrition.principles = Array(bullets.prefix(4))
            changed = true
        }
        return changed
    }

    private static func applyTraining(_ response: String, to training: inout OriginDayTraining) -> Bool {
        let lines = response.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var newExercises: [OriginExercise] = []

        for line in lines {
            if let ex = parseExerciseLine(line) {
                newExercises.append(ex)
            }
        }

        if !newExercises.isEmpty {
            training.exercises = newExercises
            if let name = extractLabel("Séance", from: response) {
                training.sessionName = name
            }
            return true
        }

        if let note = lines.last, note.count > 20 {
            training.notes = note
            return true
        }
        return false
    }

    private static func parseExerciseLine(_ line: String) -> OriginExercise? {
        let cleaned = line.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespaces)
        guard cleaned.count > 3 else { return nil }

        if let match = cleaned.range(of: #"(\d+)\s*[x×]\s*([\d\./\-–\s]+)"#, options: .regularExpression) {
            let name = String(cleaned[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
            let pattern = String(cleaned[match])
            let nums = pattern.components(separatedBy: CharacterSet(charactersIn: "x×"))
            let sets = Int(nums.first?.trimmingCharacters(in: .whitespaces) ?? "") ?? 3
            let reps = nums.dropFirst().first?.trimmingCharacters(in: .whitespaces) ?? "10"
            guard !name.isEmpty else { return nil }
            return OriginExercise(
                id: UUID().uuidString,
                name: name,
                sets: sets,
                reps: reps,
                restSeconds: 90,
                coachingCue: "Ajusté par le coach",
                muscleGroup: "—"
            )
        }
        return nil
    }

    private static func applySleep(_ response: String, to sleep: inout OriginDaySleep) -> Bool {
        var changed = false
        if let v = extractLabel("Coucher", from: response) { sleep.targetBedtime = v; changed = true }
        if let v = extractLabel("Réveil", from: response) { sleep.targetWake = v; changed = true }
        let bullets = extractBulletLines(from: response, fallback: [])
        if !bullets.isEmpty {
            sleep.eveningActions = Array(bullets.prefix(4))
            changed = true
        }
        return changed
    }

    private static func applyTasks(_ response: String, to day: inout OriginProgramDay, section: String) -> Bool {
        let bullets = extractBulletLines(from: response, fallback: [])
        guard !bullets.isEmpty else { return false }

        let tasks = bullets.enumerated().map { idx, text in
            OriginPlanTask(
                id: UUID().uuidString,
                title: text,
                detail: "Ajusté par le coach",
                pillar: section.capitalized,
                durationMinutes: nil,
                isOptional: false
            )
        }

        switch section {
        case "morning": day.morning = tasks
        case "posture": day.posture = tasks
        case "face": day.face = tasks
        case "evening": day.evening = tasks
        default: break
        }
        return true
    }

    private static func applyExtras(_ response: String, title: String, plan: inout FaceOriginPlan) -> Bool {
        let bullets = extractBulletLines(from: response, fallback: [])
        guard !bullets.isEmpty else { return false }

        if title.contains("Soleil") {
            plan.lifestyleExtras.sunlightProtocol = bullets
        } else if title.contains("Récupération") {
            plan.lifestyleExtras.recoveryProtocol = bullets
        } else if title.contains("Suivi") {
            plan.lifestyleExtras.trackingChecklist = bullets
        } else {
            plan.lifestyleExtras.bonusProposals = bullets
        }
        plan.lastUpdated = Date()
        return true
    }

    private static func extractLabel(_ label: String, from text: String) -> String? {
        let patterns = ["\(label) :", "\(label):", "\(label) —", "\(label) -"]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .caseInsensitive) {
                let rest = text[range.upperBound...]
                let line = rest.split(separator: "\n").first.map(String.init) ?? String(rest)
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func extractBulletLines(from text: String, fallback: [String]) -> [String] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("•") || $0.hasPrefix("-") || $0.hasPrefix("*") }
            .map { $0.drop(while: { "•-* ".contains($0) }).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? fallback : lines
    }
}
