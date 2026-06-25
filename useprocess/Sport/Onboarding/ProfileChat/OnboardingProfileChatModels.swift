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
        var items: [OnboardingProfileChatQuestion] = []

        if viewModel.hasWeightObjective {
            items.append(
                .init(
                    id: "goal_pace",
                    prompt: pacePrompt(for: viewModel),
                    kind: .singleChoice,
                    choices: paceChoices
                )
            )
        }

        items.append(
            .init(
                id: "sport_activity",
                prompt: "Tu fais du sport en ce moment ?",
                kind: .yesNo
            )
        )

        if viewModel.hasWeightObjective {
            items.append(
                .init(
                    id: "weight_experience",
                    prompt: experiencePrompt(for: viewModel),
                    kind: .singleChoice,
                    choices: experienceChoices
                )
            )
        }

        items.append(
            .init(
                id: "nutrition_quality",
                prompt: "Comment manges-tu au quotidien ?",
                kind: .singleChoice,
                choices: nutritionChoices
            )
        )

        items.append(faceScanQuestion(for: viewModel))
        items.append(analysisQuestion(for: viewModel))

        return items
    }

    static func faceScanQuestion(for viewModel: OnboardingViewModel) -> OnboardingProfileChatQuestion {
        .init(
            id: "face_scan_offer",
            prompt: faceScanPrompt(for: viewModel),
            kind: .faceScanOffer,
            detailText: "Faire plus tard"
        )
    }

    static func analysisQuestion(for viewModel: OnboardingViewModel) -> OnboardingProfileChatQuestion {
        .init(
            id: "answers_analysis",
            prompt: "J'analyse tes réponses…",
            kind: .answersAnalysis,
            detailText: analysisDetailText(for: viewModel)
        )
    }

    static func analysisDetailText(for viewModel: OnboardingViewModel) -> String {
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            return "\(trimmed), tout est prêt. On prépare ton plan sur mesure."
        }
        return "Tout est prêt. On prépare ton plan sur mesure."
    }

    static func openingLine(for viewModel: OnboardingViewModel) -> String {
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            return "Salut \(trimmed) 👋 Quelques questions pour calibrer ton plan."
        }
        return "Salut 👋 Quelques questions pour calibrer ton plan."
    }

    static func sportQuestion() -> OnboardingProfileChatQuestion {
        .init(
            id: "sport_pick",
            prompt: "C'est quoi ton sport ?",
            kind: .singleChoice,
            choices: OnboardingSportCatalog.featuredChoices
        )
    }

    static func failureReasonsQuestion() -> OnboardingProfileChatQuestion {
        .init(
            id: "weight_obstacles",
            prompt: "Qu'est-ce qui t'a le plus freiné ?",
            kind: .multiChoice,
            choices: obstacleChoices
        )
    }

    // MARK: - Choices

    private static let paceChoices: [OnboardingProfileChatChoice] = [
        .init(id: GoalPace.asFastAsPossible.rawValue, label: "Très vite", emoji: "⚡️"),
        .init(id: GoalPace.aggressive.rawValue, label: "Vite", emoji: "🔥"),
        .init(id: GoalPace.moderate.rawValue, label: "Progressivement", emoji: "📈"),
        .init(id: GoalPace.relaxed.rawValue, label: "À mon rythme", emoji: "🐢"),
        .init(id: GoalPace.noRush.rawValue, label: "Sans pression", emoji: "🌿")
    ]

    private static let experienceChoices: [OnboardingProfileChatChoice] = [
        .init(id: WeightManagementExperience.neverTried.rawValue, label: "Jamais"),
        .init(id: WeightManagementExperience.triedMultiple.rawValue, label: "Plusieurs fois"),
        .init(id: WeightManagementExperience.currentlyTrying.rawValue, label: "En ce moment"),
        .init(id: WeightManagementExperience.succeeded.rawValue, label: "Déjà réussi")
    ]

    private static let nutritionChoices: [OnboardingProfileChatChoice] = [
        .init(id: NutritionQuality.poor.rawValue, label: "Pas terrible", emoji: "🍔"),
        .init(id: NutritionQuality.average.rawValue, label: "Correcte", emoji: "🍝"),
        .init(id: NutritionQuality.excellent.rawValue, label: "Plutôt saine", emoji: "🥗")
    ]

    private static let obstacleChoices: [OnboardingProfileChatChoice] = [
        .init(id: NutritionObstacle.snacking.rawValue, label: "Grignotage"),
        .init(id: NutritionObstacle.lackOfTime.rawValue, label: "Pas le temps de cuisiner"),
        .init(id: NutritionObstacle.lackOfMotivation.rawValue, label: "Motivation"),
        .init(id: NutritionObstacle.emotionalEating.rawValue, label: "Manger par émotion"),
        .init(id: NutritionObstacle.socialPressure.rawValue, label: "Repas / sorties")
    ]

    // MARK: - Prompts

    private static func weightGoal(for viewModel: OnboardingViewModel) -> WeightGoal? {
        if let goal = viewModel.selectedWeightGoal { return goal }
        guard viewModel.hasWeightObjective,
              OnboardingViewModel.isPlausibleWeight(viewModel.selectedWeight),
              OnboardingViewModel.isPlausibleWeight(viewModel.idealWeightValue) else { return nil }
        if viewModel.idealWeightValue < viewModel.selectedWeight { return .lose }
        if viewModel.idealWeightValue > viewModel.selectedWeight { return .gain }
        return nil
    }

    private static func pacePrompt(for viewModel: OnboardingViewModel) -> String {
        let action = weightGoal(for: viewModel) == .gain ? "prendre" : "perdre"
        return "À quel rythme veux-tu \(action) du poids ?"
    }

    private static func experiencePrompt(for viewModel: OnboardingViewModel) -> String {
        let action = weightGoal(for: viewModel) == .gain ? "prendre" : "perdre"
        return "Déjà tenté de \(action) du poids ?"
    }

    private static func faceScanPrompt(for viewModel: OnboardingViewModel) -> String {
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            return "\(trimmed), fais ton scan visage pour calibrer ton suivi."
        }
        return "Fais ton scan visage pour calibrer ton suivi."
    }
}
