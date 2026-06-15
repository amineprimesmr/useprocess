import Foundation

enum CoachPlanModificationScope {
    case today
    case allDays
    case protocolLevel
}

struct CoachPlanModificationIntent: Equatable {
    var scope: CoachPlanModificationScope
    var section: String // nutrition, training, sleep, face, posture, general
    var userRequest: String
}

enum CoachPlanModificationService {

    // MARK: - Intent

    @MainActor
    static func detectIntent(in userText: String) -> CoachPlanModificationIntent? {
        let lower = userText.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        let modifySignals = [
            "modif", "change", "adapte", "ajuste", "ajoute", "supprime", "enleve",
            "remplace", "mets ", "passer a", "je veux", "fais ", "applique", "mets-moi"
        ]
        let planSignals = [
            "programme", "plan", "protocole", "calendrier", "repas", "pdj",
            "petit-dej", "dejeuner", "diner", "seance", "entrainement", "sommeil",
            "mewing", "nutrition", "mon plan"
        ]

        let hasModify = modifySignals.contains { lower.contains($0) }
        let hasPlan = planSignals.contains { lower.contains($0) }
        let explicitMeal = lower.contains("1 repas") || lower.contains("un repas")
            || lower.contains("un seul repas") || lower.contains("omad")
            || lower.contains("2 repas") || lower.contains("deux repas")

        guard (hasModify && hasPlan) || explicitMeal else { return nil }

        let section: String
        if lower.contains("repas") || lower.contains("pdj") || lower.contains("dejeuner")
            || lower.contains("diner") || lower.contains("nutrition") || lower.contains("omad") {
            section = "nutrition"
        } else if lower.contains("seance") || lower.contains("entrainement") || lower.contains("training") {
            section = "training"
        } else if lower.contains("sommeil") || lower.contains("coucher") || lower.contains("reveil") {
            section = "sleep"
        } else if lower.contains("mewing") || lower.contains("maxillaire") || lower.contains("visage") {
            section = "face"
        } else if lower.contains("posture") || lower.contains("marche") {
            section = "posture"
        } else {
            section = "general"
        }

        let scope: CoachPlanModificationScope
        if lower.contains("aujourd") || lower.contains("ce jour") {
            scope = .today
        } else if lower.contains("tout le") || lower.contains("tous les jours") || lower.contains("calendrier") {
            scope = .allDays
        } else {
            scope = section == "nutrition" || section == "training" ? .allDays : .today
        }

        return CoachPlanModificationIntent(scope: scope, section: section, userRequest: userText)
    }

    @MainActor
    static func buildFocus(intent: CoachPlanModificationIntent, plan: FaceOriginPlan) -> CoachPlanFocus {
        let dayIdx = plan.calendar.currentProgramDayIndex()
        let day = plan.calendar.day(globalIndex: dayIdx)
        let dayId = day?.id ?? "global"

        let sectionPath: String
        let title: String
        let content: String

        switch intent.section {
        case "nutrition":
            sectionPath = intent.scope == .allDays ? "global/nutrition" : "\(dayId)/nutrition"
            title = "Nutrition"
            if let day {
                content = """
                Petit-déjeuner : \(day.nutrition.breakfast)
                Déjeuner : \(day.nutrition.lunch)
                Dîner : \(day.nutrition.dinner)
                \(day.nutrition.snack.map { "Collation : \($0)" } ?? "")
                Hydratation : \(day.nutrition.hydration)
                """
            } else {
                content = plan.nutritionProtocol.dailyStructure.joined(separator: "\n")
            }
        case "training":
            sectionPath = intent.scope == .allDays ? "global/training" : "\(dayId)/training"
            title = "Entraînement"
            content = day?.training.map {
                "\($0.sessionName) — \($0.exercises.map(\.name).joined(separator: ", "))"
            } ?? plan.trainingProtocol.weeklyTemplate.joined(separator: "\n")
        case "sleep":
            sectionPath = "\(dayId)/sleep"
            title = "Sommeil"
            content = day.map {
                "Coucher \($0.sleep.targetBedtime) · Réveil \($0.sleep.targetWake)"
            } ?? plan.sleepProtocol.bedtimeWindow
        default:
            sectionPath = "global/program"
            title = "Protocole Origine"
            content = CoachPlanContextBuilder.todayDetailBlock(plan: plan)
        }

        return CoachPlanFocus(
            sectionPath: sectionPath,
            sectionTitle: title,
            sectionContent: content,
            mode: .modify
        )
    }

    // MARK: - Apply

    @MainActor
    static func apply(
        userRequest: String,
        coachResponse: String,
        focus: CoachPlanFocus?,
        plan: inout FaceOriginPlan
    ) -> [String] {
        var changes = CoachPlanAutoApplier.applyUserRequest(userRequest, plan: &plan)
        let userAlreadyApplied = !changes.isEmpty

        if let focus, !userAlreadyApplied {
            if CoachPlanAutoApplier.apply(response: coachResponse, focus: focus, plan: &plan) {
                changes.append("Section « \(focus.sectionTitle) » mise à jour")
            }
        }

        if let focus {
            CoachPlanEditor.applyCalendarPatch(
                plan: &plan,
                sectionPath: focus.sectionPath,
                newContent: coachResponse,
                userRequest: userRequest,
                coachResponse: coachResponse
            )
        } else if !changes.isEmpty {
            CoachPlanEditor.applyCalendarPatch(
                plan: &plan,
                sectionPath: "global/nutrition",
                newContent: coachResponse,
                userRequest: userRequest,
                coachResponse: coachResponse
            )
        }

        if !changes.isEmpty {
            CoachMemoryStore.shared.recordPlanAdjustment(changes.joined(separator: " · "))
        }

        return changes
    }

    static func confirmationPrefix(changes: [String]) -> String {
        guard !changes.isEmpty else { return "" }
        let list = changes.map { "• \($0)" }.joined(separator: "\n")
        return "✅ Modifié dans ton programme\n\(list)\n\n"
    }
}
