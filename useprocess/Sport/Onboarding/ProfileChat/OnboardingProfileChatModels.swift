//
//  OnboardingProfileChatModels.swift
//  useprocess
//

import Foundation

enum OnboardingProfileChatRole {
    case assistant
    case user
}

struct OnboardingProfileChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: OnboardingProfileChatRole
    let text: String
    /// Texte complet pour figer la mise en page pendant le typewriter.
    let layoutAnchorText: String?
    /// Question associée quand il s'agit d'une réponse utilisateur (édition depuis l'historique).
    let questionId: String?

    init(
        id: UUID = UUID(),
        role: OnboardingProfileChatRole,
        text: String,
        layoutAnchorText: String? = nil,
        questionId: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.layoutAnchorText = layoutAnchorText
        self.questionId = questionId
    }
}

enum OnboardingProfileChatQuestionKind {
    case infoContinue
    case autoPlanCreation
    case yesNo
    case singleChoice
    case multiChoice
    case faceScanOffer
    case answersAnalysis
    case analysisProgress
}

struct OnboardingProfileChatChoice: Identifiable, Equatable {
    let id: String
    let label: String
    let emoji: String?

    init(id: String, label: String, emoji: String? = nil) {
        self.id = id
        self.label = label
        self.emoji = emoji
    }
}

struct OnboardingProfileChatQuestion: Identifiable, Equatable {
    let id: String
    let prompt: String
    let kind: OnboardingProfileChatQuestionKind
    let choices: [OnboardingProfileChatChoice]
    let allowsSkip: Bool
    let detailText: String?

    init(
        id: String,
        prompt: String,
        kind: OnboardingProfileChatQuestionKind,
        choices: [OnboardingProfileChatChoice] = [],
        allowsSkip: Bool = false,
        detailText: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.kind = kind
        self.choices = choices
        self.allowsSkip = allowsSkip
        self.detailText = detailText
    }
}

enum OnboardingProfileChatQuestionBank {
    static func questions(for viewModel: OnboardingViewModel) -> [OnboardingProfileChatQuestion] {
        [
            .init(
                id: "primary_focus",
                prompt: "Qu'est-ce que tu veux améliorer en premier ?",
                kind: .singleChoice,
                choices: primaryFocusChoices
            ),
            .init(
                id: "debloat_driver",
                prompt: "D'après toi, qu'est-ce qui te déséquilibre le plus au quotidien ?",
                kind: .multiChoice,
                choices: debloatDriverChoices
            ),
            .init(
                id: "nutrition_quality",
                prompt: "Ton alimentation ressemble plutôt à quoi ?",
                kind: .singleChoice,
                choices: nutritionChoices
            ),
            faceScanQuestion(for: viewModel),
            scanExplanationQuestion(for: viewModel)
        ]
    }

    static func faceScanQuestion(for viewModel: OnboardingViewModel) -> OnboardingProfileChatQuestion {
        .init(
            id: "face_scan_offer",
            prompt: faceScanPrompt(for: viewModel),
            kind: .faceScanOffer,
            detailText: "Faire mon scan plus tard"
        )
    }

    static func scanExplanationQuestion(for viewModel: OnboardingViewModel) -> OnboardingProfileChatQuestion {
        .init(
            id: "scan_explanation",
            prompt: scanExplanationText(for: viewModel),
            kind: .autoPlanCreation
        )
    }

    static func openingLine(for viewModel: OnboardingViewModel) -> String {
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            return "Salut \(trimmed) 👋 Quelques questions pour calibrer ton plan."
        }
        return "Salut 👋 Quelques questions pour calibrer ton plan."
    }

    // MARK: - Choices

    private static let primaryFocusChoices: [OnboardingProfileChatChoice] = [
        .init(id: OnboardingPrimaryFocus.face.rawValue, label: "Dégonfler mon visage", emoji: "💧"),
        .init(id: OnboardingPrimaryFocus.weight.rawValue, label: "Perdre du poids", emoji: "⚖️"),
        .init(id: OnboardingPrimaryFocus.health.rawValue, label: "Améliorer ma santé", emoji: "🌿"),
        .init(id: OnboardingPrimaryFocus.energy.rawValue, label: "Avoir plus d'énergie", emoji: "⚡️")
    ]

    private static let debloatDriverChoices: [OnboardingProfileChatChoice] = [
        .init(id: OnboardingDebloatDriver.sleep.rawValue, label: "Manque de sommeil", emoji: "😴"),
        .init(id: OnboardingDebloatDriver.nutrition.rawValue, label: "Alimentation (sel, fast-food…)", emoji: "🥡"),
        .init(id: OnboardingDebloatDriver.stress.rawValue, label: "Stress", emoji: "😰"),
        .init(id: OnboardingDebloatDriver.sedentary.rawValue, label: "Peu d'activité", emoji: "🛋️"),
        .init(id: OnboardingDebloatDriver.unknown.rawValue, label: "Je ne sais pas trop", emoji: "🤷")
    ]

    private static let nutritionChoices: [OnboardingProfileChatChoice] = [
        .init(id: NutritionQuality.excellent.rawValue, label: "Assez équilibrée", emoji: "🥗"),
        .init(id: NutritionQuality.average.rawValue, label: "Irrégulière", emoji: "🍝"),
        .init(id: NutritionQuality.poor.rawValue, label: "Souvent prise rapidement", emoji: "🥡"),
        .init(id: "snacking", label: "Beaucoup de grignotage", emoji: "🍪"),
        .init(id: "unknown", label: "Difficile à évaluer")
    ]

    private static func scanExplanationText(for viewModel: OnboardingViewModel) -> String {
        guard let markers = viewModel.onboardingFaceMarkers else {
            return """
            Pas de scan pour l'instant — je pars surtout de tes réponses pour calibrer ton plan.

            Tu pourras lancer un scan plus tard dans l'app pour affiner ton suivi.
            """
        }

        let result = FaceScanHistoryStore.shared.latestResult
            ?? FaceScanResult(userId: "local", markers: markers)
        let problems = scanProblemPhrases(for: result, limit: 3)

        let problemsBlock: String
        if problems.isEmpty {
            problemsBlock = "Ton scan est plutôt équilibré aujourd'hui — pas de signal très marqué."
        } else if problems.count == 1 {
            problemsBlock = "Ton scan montre surtout \(problems[0])."
        } else {
            let head = problems.dropLast().joined(separator: ", ")
            problemsBlock = "Ton scan montre surtout \(head) et \(problems.last!)."
        }

        let nextBlock = "Je croise ça avec tes réponses et je te prépare un plan adapté à toi."

        return [problemsBlock, nextBlock].joined(separator: "\n\n")
    }

    private static func scanProblemPhrases(
        for result: FaceScanResult,
        limit: Int
    ) -> [String] {
        FaceScanIndicators.Kind.allCases
            .map { kind in
                (
                    kind: kind,
                    zone: FaceScanIndicators.displayZone(for: kind, result: result),
                    percent: FaceScanIndicators.displayPercent(for: kind, result: result)
                )
            }
            .filter { $0.zone != .optimal }
            .sorted { metricSeverity(kind: $0.kind, percent: $0.percent) > metricSeverity(kind: $1.kind, percent: $1.percent) }
            .prefix(limit)
            .map { simpleProblemPhrase(kind: $0.kind, zone: $0.zone) }
    }

    private static func simpleProblemPhrase(
        kind: FaceScanIndicators.Kind,
        zone: FaceScanIndicators.WellnessZone
    ) -> String {
        switch kind {
        case .retention:
            return zone == .insufficient ? "une rétention d'eau marquée" : "un léger gonflement"
        case .recovery:
            return zone == .insufficient ? "une récupération insuffisante" : "des signes de fatigue"
        case .stressLoad:
            return zone == .insufficient ? "une charge de stress élevée" : "une tension modérée"
        case .skin:
            return zone == .insufficient ? "une peau terne" : "une peau qui manque un peu d'éclat"
        case .definition:
            return zone == .insufficient ? "une mâchoire peu marquée" : "une définition faciale moyenne"
        }
    }

    private static func metricSeverity(kind: FaceScanIndicators.Kind, percent: Int) -> Int {
        kind.higherIsWorse ? percent : (100 - percent)
    }

    private static func faceScanPrompt(for viewModel: OnboardingViewModel) -> String {
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            return "\(trimmed), fais ton scan visage pour calibrer ton suivi."
        }
        return "Fais ton scan visage pour calibrer ton suivi."
    }
}
