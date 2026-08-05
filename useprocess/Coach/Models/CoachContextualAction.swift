import Foundation

enum CoachContextualActionKind: String, Codable, Equatable, CaseIterable {
    case validateMeal
    case saveMealDraft
    case modifyMeal
    case anotherMeal
    case addToShoppingList
    case applyPlanChanges
    case swapWorkout
    case openPlan
    case openJournal
    case takePhoto
    case followUp

    var defaultLabel: String {
        switch self {
        case .validateMeal: return AppCopy.t("Valider dans mon plan", en: "Confirm in my plan")
        case .saveMealDraft: return AppCopy.t("Garder comme suggestion", en: "Keep as a suggestion")
        case .modifyMeal: return AppCopy.t("Ajuster ce repas", en: "Adjust this meal")
        case .anotherMeal: return AppCopy.t("Autre idée", en: "Another idea")
        case .addToShoppingList: return AppCopy.t("Liste de courses", en: "Shopping list")
        case .applyPlanChanges: return AppCopy.t("Appliquer au programme", en: "Apply to program")
        case .swapWorkout: return AppCopy.t("Changer le cardio", en: "Change cardio")
        case .openPlan: return AppCopy.t("Ouvrir l'accueil", en: "Open Home")
        case .openJournal: return AppCopy.t("Ouvrir le journal", en: "Open journal")
        case .takePhoto: return AppCopy.t("Prendre une photo", en: "Take a photo")
        case .followUp: return AppCopy.continueCTA
        }
    }

    var icon: String {
        switch self {
        case .validateMeal: return "checkmark.seal.fill"
        case .saveMealDraft: return "square.and.arrow.down"
        case .modifyMeal: return "slider.horizontal.3"
        case .anotherMeal: return "arrow.triangle.2.circlepath"
        case .addToShoppingList: return "cart.fill"
        case .applyPlanChanges: return "calendar.badge.checkmark"
        case .swapWorkout: return "figure.run"
        case .openPlan: return "calendar"
        case .openJournal: return "checklist"
        case .takePhoto: return "camera.fill"
        case .followUp: return "bubble.left.and.bubble.right"
        }
    }

    var isPrimary: Bool {
        switch self {
        case .validateMeal, .applyPlanChanges: return true
        default: return false
        }
    }
}

struct CoachContextualAction: Codable, Equatable, Identifiable {
    let kind: CoachContextualActionKind
    let label: String
    let payload: String?

    var id: String { "\(kind.rawValue)|\(label)|\(payload ?? "")" }

    init(kind: CoachContextualActionKind, label: String? = nil, payload: String? = nil) {
        self.kind = kind
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.label = trimmed.isEmpty ? kind.defaultLabel : trimmed
        self.payload = payload?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : payload
    }

    func encodedLine() -> String {
        if let payload {
            return "\(kind.rawValue)|\(label)|\(payload)"
        }
        return "\(kind.rawValue)|\(label)"
    }

    static func parse(line: String) -> CoachContextualAction? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: "|", maxSplits: 2).map(String.init)
        guard let kindRaw = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              let kind = CoachContextualActionKind(rawValue: kindRaw) else { return nil }

        let label = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let payload = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        return CoachContextualAction(
            kind: kind,
            label: label.isEmpty ? nil : label,
            payload: payload?.isEmpty == true ? nil : payload
        )
    }

    static func encodeList(_ actions: [CoachContextualAction]) -> [String] {
        actions.map { $0.encodedLine() }
    }

    static func decodeList(_ lines: [String]) -> [CoachContextualAction] {
        lines.compactMap { CoachContextualAction.parse(line: $0) }
    }
}

struct PendingCoachPlanPatch: Equatable {
    let userRequest: String
    let coachResponse: String
    let focus: CoachPlanFocus?
}
