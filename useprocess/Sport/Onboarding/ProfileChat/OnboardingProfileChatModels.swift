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
    /// Blocs assistant affichés séquentiellement (2 bulles distinctes dans le fil).
    let promptBlocks: [String]?
    let kind: OnboardingProfileChatQuestionKind
    let choices: [OnboardingProfileChatChoice]
    let allowsSkip: Bool
    let detailText: String?
    /// Label du bouton pour `.infoContinue` (défaut : Continuer).
    let continueLabel: String?

    var assistantPresentationBlocks: [String] {
        if let promptBlocks, !promptBlocks.isEmpty { return promptBlocks }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return [prompt]
    }

    init(
        id: String,
        prompt: String = "",
        promptBlocks: [String]? = nil,
        kind: OnboardingProfileChatQuestionKind,
        choices: [OnboardingProfileChatChoice] = [],
        allowsSkip: Bool = false,
        detailText: String? = nil,
        continueLabel: String? = nil
    ) {
        self.id = id
        if let promptBlocks, !promptBlocks.isEmpty {
            self.promptBlocks = promptBlocks
            self.prompt = promptBlocks.joined(separator: "\n\n")
        } else {
            self.promptBlocks = nil
            self.prompt = prompt
        }
        self.kind = kind
        self.choices = choices
        self.allowsSkip = allowsSkip
        self.detailText = detailText
        self.continueLabel = continueLabel
    }
}

enum OnboardingProfileChatQuestionBank {
    static func questions(for viewModel: OnboardingViewModel) -> [OnboardingProfileChatQuestion] {
        [
            introSwollenFaceQuestion(for: viewModel),
            .init(
                id: "intro_causes",
                prompt: """
                Dans 94% des cas, il s’agit de :

                - rétention d’eau
                - inflammation
                - cortisol
                - lymphe qui circule mal…

                Tu n’as pas besoin de tout comprendre maintenant. Process est là pour ça.
                """,
                kind: .infoContinue,
                continueLabel: "Et ensuite ?"
            ),
            .init(
                id: "intro_next",
                prompt: """
                On va identifier ce qui te concerne, puis scanner ton visage pour créer ton plan personnalisé.
                """,
                kind: .infoContinue,
                continueLabel: "C’est parti"
            ),
            .init(
                id: "debloat_driver",
                prompt: "Ton visage est plus gonflé au réveil ?",
                kind: .singleChoice,
                choices: debloatDriverChoices
            ),
            .init(
                id: "hydration_level",
                prompt: "Combien d’eau tu bois par jour ?",
                kind: .singleChoice,
                choices: hydrationChoices
            ),
            .init(
                id: "junk_food",
                prompt: "À quelle fréquence tu manges de la malbouffe ?",
                kind: .singleChoice,
                choices: junkFoodChoices
            ),
            .init(
                id: "sleep_hours",
                prompt: "Combien d’heures tu dors par nuit ?",
                kind: .singleChoice,
                choices: sleepHoursChoices
            ),
            .init(
                id: "cardio_frequency",
                prompt: "Combien de fois tu fais du cardio dans la semaine ?",
                kind: .singleChoice,
                choices: cardioFrequencyChoices
            ),
            faceScanQuestion(for: viewModel)
        ]
    }

    static func faceScanQuestion(for viewModel: OnboardingViewModel) -> OnboardingProfileChatQuestion {
        .init(
            id: "face_scan_offer",
            prompt: faceScanPrompt(for: viewModel),
            kind: .faceScanOffer
        )
    }

    static func introSwollenFaceQuestion(for viewModel: OnboardingViewModel) -> OnboardingProfileChatQuestion {
        .init(
            id: "intro_swollen_face",
            promptBlocks: [
                introSwollenFaceOpeningLine(for: viewModel),
                "C’est surtout du liquide retenue qui s’accumule sous ta peau."
            ],
            kind: .infoContinue,
            continueLabel: "C’est quoi ce liquide ?"
        )
    }

    private static func introSwollenFaceOpeningLine(for viewModel: OnboardingViewModel) -> String {
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            return "\(trimmed), un visage gonflé, ce n’est presque jamais de la graisse."
        }
        return "Un visage gonflé, ce n’est presque jamais de la graisse."
    }

    /// Conservé pour compat.
    static func openingLine(for viewModel: OnboardingViewModel) -> String? { nil }

    static func resolvedQuestion(
        _ question: OnboardingProfileChatQuestion,
        for viewModel: OnboardingViewModel
    ) -> OnboardingProfileChatQuestion {
        switch question.id {
        case "intro_swollen_face":
            return introSwollenFaceQuestion(for: viewModel)
        case "face_scan_offer":
            return faceScanQuestion(for: viewModel)
        default:
            return question
        }
    }

    /// Réponse utilisateur persistée — pour reconstruire l'historique après relance.
    static func savedAnswerDisplay(
        for questionID: String,
        viewModel: OnboardingViewModel
    ) -> String? {
        switch questionID {
        case "intro_swollen_face":
            return "C’est quoi ce liquide ?"
        case "intro_causes":
            return "Et ensuite ?"
        case "intro_next":
            return "C’est parti"

        case "debloat_driver":
            guard let driver = viewModel.onboardingDebloatDrivers.first else { return nil }
            return debloatDriverChoices.first(where: { $0.id == driver.rawValue })?.label

        case "hydration_level":
            guard let level = viewModel.nutritionProfile.hydrationLevel,
                  let match = hydrationChoices.first(where: { $0.id == level.rawValue }) else { return nil }
            return match.label

        case "junk_food":
            guard let quality = viewModel.nutritionProfile.nutritionQuality,
                  let match = junkFoodChoices.first(where: { $0.id == quality.rawValue }) else { return nil }
            return match.label

        case "sleep_hours":
            guard let hours = viewModel.sleepProfile.averageSleepHours,
                  let match = sleepHoursChoices.first(where: {
                      abs((Double($0.id) ?? -1) - hours) < 0.01
                  }) else { return nil }
            return match.label

        case "cardio_frequency":
            guard let frequency = viewModel.selectedTrainingFrequency,
                  let match = cardioFrequencyChoices.first(where: { $0.id == frequency }) else { return nil }
            return match.label

        case "face_scan_offer":
            guard viewModel.completedProfileChatQuestionIDs.contains(questionID) else { return nil }
            return "Lancer le scan"

        case "sport_pick":
            guard let sport = OnboardingDataModel.shared.selectedSports.first else { return nil }
            return OnboardingSportCatalog.nameWithoutEmoji(sport)

        default:
            return nil
        }
    }

    // MARK: - Choices

    private static let debloatDriverChoices: [OnboardingProfileChatChoice] = [
        .init(id: OnboardingDebloatDriver.sleep.rawValue, label: "Oui, tous les matins"),
        .init(id: OnboardingDebloatDriver.sedentary.rawValue, label: "Oui, certains jours"),
        .init(id: OnboardingDebloatDriver.stress.rawValue, label: "Surtout en fin de journée"),
        .init(id: OnboardingDebloatDriver.unknown.rawValue, label: "Non, pas vraiment")
    ]

    private static let hydrationChoices: [OnboardingProfileChatChoice] = [
        .init(id: HydrationLevel.poor.rawValue, label: "Moins d’1 L"),
        .init(id: HydrationLevel.good.rawValue, label: "Environ 1 L"),
        .init(id: HydrationLevel.veryGood.rawValue, label: "1,5 à 2 L"),
        .init(id: HydrationLevel.excellent.rawValue, label: "Plus de 2 L")
    ]

    private static let junkFoodChoices: [OnboardingProfileChatChoice] = [
        .init(id: NutritionQuality.veryPoor.rawValue, label: "Tous les jours"),
        .init(id: NutritionQuality.poor.rawValue, label: "Plusieurs fois par semaine"),
        .init(id: NutritionQuality.average.rawValue, label: "1 à 2 fois par semaine"),
        .init(id: NutritionQuality.excellent.rawValue, label: "Rarement")
    ]

    /// `id` = heures moyennes stockées dans `SleepProfile.averageSleepHours`.
    private static let sleepHoursChoices: [OnboardingProfileChatChoice] = [
        .init(id: "4.5", label: "Moins de 5 h"),
        .init(id: "5.5", label: "5 à 6 h"),
        .init(id: "6.5", label: "6 à 7 h"),
        .init(id: "7.5", label: "7 à 8 h"),
        .init(id: "8.5", label: "Plus de 8 h")
    ]

    private static let cardioFrequencyChoices: [OnboardingProfileChatChoice] = [
        .init(id: "0-2", label: "Presque jamais"),
        .init(id: "1-2", label: "1 à 2 fois"),
        .init(id: "3-4", label: "3 à 4 fois"),
        .init(id: "5+", label: "5 fois ou plus")
    ]

    private static func faceScanPrompt(for viewModel: OnboardingViewModel) -> String {
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            return "\(trimmed), on a ce qu’il faut. Scannons maintenant ton visage pour mesurer le gonflement."
        }
        return "On a ce qu’il faut. Scannons maintenant ton visage pour mesurer le gonflement."
    }
}
