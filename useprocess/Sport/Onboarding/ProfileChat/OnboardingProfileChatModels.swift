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
    case profileSummary
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

@MainActor
enum OnboardingProfileChatQuestionBank {
    static func questions(for viewModel: OnboardingViewModel) -> [OnboardingProfileChatQuestion] {
        [
            introSwollenFaceQuestion(for: viewModel),
            .init(
                id: "intro_causes",
                prompt: OnboardingCopy.t("""
                Dans 94% des cas, il s’agit de :

                💧 rétention d’eau
                🔥 inflammation
                😰 cortisol
                🌀 lymphe qui circule mal…

                Tu n’as pas besoin de tout comprendre. Process est là pour ça.
                """, en: """
                In 94% of cases, it’s:

                💧 water retention
                🔥 inflammation
                😰 cortisol
                🌀 poor lymph circulation…

                You don’t need to understand it all. Process is here for that.
                """),
                kind: .infoContinue,
                continueLabel: OnboardingCopy.t("Et ensuite ?", en: "And then?")
            ),
            .init(
                id: "intro_next",
                prompt: OnboardingCopy.t("""
                On va identifier ce qui te concerne, puis scanner ton visage pour créer ton plan personnalisé.
                """, en: """
                We’ll figure out what applies to you, then scan your face to build your personalized plan.
                """),
                kind: .infoContinue,
                continueLabel: OnboardingCopy.t("C’est parti", en: "Let’s go")
            ),
            .init(
                id: "debloat_driver",
                prompt: OnboardingCopy.t(
                    "Ton visage est plus gonflé au réveil ?",
                    en: "Is your face more puffy when you wake up?"
                ),
                kind: .singleChoice,
                choices: debloatDriverChoices
            ),
            .init(
                id: "hydration_level",
                prompt: OnboardingCopy.t(
                    "Combien d’eau tu bois par jour ?",
                    en: "How much water do you drink per day?"
                ),
                kind: .singleChoice,
                choices: hydrationChoices
            ),
            .init(
                id: "junk_food",
                prompt: OnboardingCopy.t(
                    "À quelle fréquence tu manges de la malbouffe ?",
                    en: "How often do you eat junk food?"
                ),
                kind: .singleChoice,
                choices: junkFoodChoices
            ),
            .init(
                id: "sleep_hours",
                prompt: OnboardingCopy.t(
                    "Combien d’heures tu dors par nuit ?",
                    en: "How many hours do you sleep per night?"
                ),
                kind: .singleChoice,
                choices: sleepHoursChoices
            ),
            .init(
                id: "cardio_frequency",
                prompt: OnboardingCopy.t(
                    "Combien de fois tu fais du cardio dans la semaine ?",
                    en: "How many times a week do you do cardio?"
                ),
                kind: .singleChoice,
                choices: cardioFrequencyChoices
            ),
            profileSummaryQuestion(for: viewModel)
        ]
    }

    static func profileSummaryQuestion(for viewModel: OnboardingViewModel) -> OnboardingProfileChatQuestion {
        let nameLine: String
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            nameLine = OnboardingCopy.t(
                "Merci de me faire confiance, \(trimmed).",
                en: "Thanks for trusting me with this, \(trimmed)."
            )
        } else {
            nameLine = OnboardingCopy.t(
                "Merci de me faire confiance.",
                en: "Thanks for trusting me with this."
            )
        }

        return .init(
            id: "profile_summary",
            promptBlocks: [
                OnboardingCopy.t(
                    "85 % des utilisateurs se sentent plus confiants après seulement 4 semaines. Le reste suit.",
                    en: "85% of users feel more confident after just 4 weeks. Everything else starts to follow."
                ),
                nameLine,
                OnboardingCopy.t(
                    "J’ai verrouillé tes réponses — ton dashboard est prêt 🙌",
                    en: "I've locked your answers in — your dashboard is ready 🙌"
                )
            ],
            kind: .profileSummary
        )
    }

    /// Conservé pour compat sauvegarde / analytics.
    static func faceScanQuestion(for viewModel: OnboardingViewModel) -> OnboardingProfileChatQuestion {
        profileSummaryQuestion(for: viewModel)
    }

    static func introSwollenFaceQuestion(for viewModel: OnboardingViewModel) -> OnboardingProfileChatQuestion {
        .init(
            id: "intro_swollen_face",
            promptBlocks: [
                introSwollenFaceOpeningLine(for: viewModel),
                OnboardingCopy.t(
                    "C’est surtout du liquide retenue qui s’accumule sous ta peau.",
                    en: "It’s mostly retained fluid building up under your skin."
                )
            ],
            kind: .infoContinue,
            continueLabel: OnboardingCopy.t("C’est quoi ce liquide ?", en: "What is that fluid?")
        )
    }

    private static func introSwollenFaceOpeningLine(for viewModel: OnboardingViewModel) -> String {
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            return OnboardingCopy.t(
                "\(trimmed), un visage gonflé, ce n’est presque jamais de la graisse.",
                en: "\(trimmed), a puffy face is almost never fat."
            )
        }
        return OnboardingCopy.t(
            "Un visage gonflé, ce n’est presque jamais de la graisse.",
            en: "A puffy face is almost never fat."
        )
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
        case "face_scan_offer", "profile_summary":
            return profileSummaryQuestion(for: viewModel)
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
            return OnboardingCopy.t("C’est quoi ce liquide ?", en: "What is that fluid?")
        case "intro_causes":
            return OnboardingCopy.t("Et ensuite ?", en: "And then?")
        case "intro_next":
            return OnboardingCopy.t("C’est parti", en: "Let’s go")

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

        case "face_scan_offer", "profile_summary":
            guard viewModel.completedProfileChatQuestionIDs.contains(questionID)
                || viewModel.completedProfileChatQuestionIDs.contains("face_scan_offer") else { return nil }
            return OnboardingCopy.t("Emmène-moi →", en: "Take me there →")

        case "sport_pick":
            guard let sport = OnboardingDataModel.shared.selectedSports.first else { return nil }
            return OnboardingSportCatalog.localizedName(sport)

        default:
            return nil
        }
    }

    // MARK: - Choices

    private static var debloatDriverChoices: [OnboardingProfileChatChoice] {
        [
            .init(
                id: OnboardingDebloatDriver.sleep.rawValue,
                label: OnboardingCopy.t("Oui, tous les matins", en: "Yes, every morning")
            ),
            .init(
                id: OnboardingDebloatDriver.sedentary.rawValue,
                label: OnboardingCopy.t("Oui, certains jours", en: "Yes, some days")
            ),
            .init(
                id: OnboardingDebloatDriver.stress.rawValue,
                label: OnboardingCopy.t("Surtout en fin de journée", en: "Mostly later in the day")
            ),
            .init(
                id: OnboardingDebloatDriver.unknown.rawValue,
                label: OnboardingCopy.t("Non, pas vraiment", en: "No, not really")
            )
        ]
    }

    private static var hydrationChoices: [OnboardingProfileChatChoice] {
        [
            .init(id: HydrationLevel.poor.rawValue, label: OnboardingCopy.t("Moins d’1 L", en: "Less than 1 L")),
            .init(id: HydrationLevel.good.rawValue, label: OnboardingCopy.t("Environ 1 L", en: "About 1 L")),
            .init(id: HydrationLevel.veryGood.rawValue, label: OnboardingCopy.t("1,5 à 2 L", en: "1.5 to 2 L")),
            .init(id: HydrationLevel.excellent.rawValue, label: OnboardingCopy.t("Plus de 2 L", en: "More than 2 L"))
        ]
    }

    private static var junkFoodChoices: [OnboardingProfileChatChoice] {
        [
            .init(id: NutritionQuality.veryPoor.rawValue, label: OnboardingCopy.t("Tous les jours", en: "Every day")),
            .init(
                id: NutritionQuality.poor.rawValue,
                label: OnboardingCopy.t("Plusieurs fois par semaine", en: "Several times a week")
            ),
            .init(
                id: NutritionQuality.average.rawValue,
                label: OnboardingCopy.t("1 à 2 fois par semaine", en: "1 to 2 times a week")
            ),
            .init(id: NutritionQuality.excellent.rawValue, label: OnboardingCopy.t("Rarement", en: "Rarely"))
        ]
    }

    /// `id` = heures moyennes stockées dans `SleepProfile.averageSleepHours`.
    private static var sleepHoursChoices: [OnboardingProfileChatChoice] {
        [
            .init(id: "4.5", label: OnboardingCopy.t("Moins de 5 h", en: "Less than 5 hrs")),
            .init(id: "5.5", label: OnboardingCopy.t("5 à 6 h", en: "5 to 6 hrs")),
            .init(id: "6.5", label: OnboardingCopy.t("6 à 7 h", en: "6 to 7 hrs")),
            .init(id: "7.5", label: OnboardingCopy.t("7 à 8 h", en: "7 to 8 hrs")),
            .init(id: "8.5", label: OnboardingCopy.t("Plus de 8 h", en: "More than 8 hrs"))
        ]
    }

    private static var cardioFrequencyChoices: [OnboardingProfileChatChoice] {
        [
            .init(id: "0-2", label: OnboardingCopy.t("Presque jamais", en: "Almost never")),
            .init(id: "1-2", label: OnboardingCopy.t("1 à 2 fois", en: "1 to 2 times")),
            .init(id: "3-4", label: OnboardingCopy.t("3 à 4 fois", en: "3 to 4 times")),
            .init(id: "5+", label: OnboardingCopy.t("5 fois ou plus", en: "5 times or more"))
        ]
    }

    /// Migre les anciennes sauvegardes `face_scan_offer` vers `profile_summary`.
    static func normalizedCompletedQuestionIDs(_ ids: Set<String>) -> Set<String> {
        var normalized = ids
        if normalized.contains("face_scan_offer") {
            normalized.insert("profile_summary")
        }
        return normalized
    }
}
