//
//  OnboardingProfileSummaryBuilder.swift
//  useprocess
//

import Foundation

struct OnboardingProfileSummaryChip: Identifiable, Equatable {
    let id: String
    let emoji: String
    let label: String
}

struct OnboardingProfileSummarySection: Identifiable, Equatable {
    let id: String
    let title: String
    let chips: [OnboardingProfileSummaryChip]
}

@MainActor
enum OnboardingProfileSummaryBuilder {
    static func sections(for viewModel: OnboardingViewModel) -> [OnboardingProfileSummarySection] {
        [
            gettingInYourWaySection(for: viewModel),
            yourGoalsSection(for: viewModel),
            howYouWantToFeelSection(for: viewModel),
            yourWhySection(for: viewModel)
        ]
    }

    private static func gettingInYourWaySection(for viewModel: OnboardingViewModel) -> OnboardingProfileSummarySection {
        let chip: OnboardingProfileSummaryChip
        if let driver = viewModel.onboardingDebloatDrivers.first,
           let match = debloatDriverLabel(for: driver) {
            chip = .init(id: "debloat_driver", emoji: "🤔", label: match)
        } else {
            chip = .init(
                id: "debloat_driver_default",
                emoji: "🤔",
                label: OnboardingCopy.t(
                    "Je ne sais pas quoi améliorer",
                    en: "I'm unsure what to improve"
                )
            )
        }

        return .init(
            id: "getting_in_your_way",
            title: OnboardingCopy.t("Ce qui te freine", en: "Getting in your way"),
            chips: [chip]
        )
    }

    private static func yourGoalsSection(for viewModel: OnboardingViewModel) -> OnboardingProfileSummarySection {
        var chips: [OnboardingProfileSummaryChip] = [
            .init(
                id: "goal_debloat",
                emoji: "💎",
                label: OnboardingCopy.t("Visage moins gonflé", en: "Less puffy face")
            ),
            .init(
                id: "goal_profile",
                emoji: "👤",
                label: OnboardingCopy.t("Profil plus net", en: "Sharper side profile")
            )
        ]

        if let hydration = viewModel.nutritionProfile.hydrationLevel,
           let label = hydrationSummaryLabel(for: hydration) {
            chips = [
                .init(id: "goal_hydration", emoji: "💧", label: label),
                chips[0]
            ]
        }

        return .init(
            id: "your_goals",
            title: OnboardingCopy.t("Tes objectifs", en: "Your goals"),
            chips: chips
        )
    }

    private static func howYouWantToFeelSection(for viewModel: OnboardingViewModel) -> OnboardingProfileSummarySection {
        let label: String
        switch viewModel.selectedTrainingFrequency {
        case "0-2", "1-2":
            label = OnboardingCopy.t(
                "Plus énergique au quotidien",
                en: "More energy day to day"
            )
        default:
            label = OnboardingCopy.t(
                "Confiant dans toutes les situations",
                en: "Confident in any situation"
            )
        }

        return .init(
            id: "how_you_want_to_feel",
            title: OnboardingCopy.t("Comment tu veux te sentir", en: "How you want to feel"),
            chips: [.init(id: "feel", emoji: "😎", label: label)]
        )
    }

    private static func yourWhySection(for viewModel: OnboardingViewModel) -> OnboardingProfileSummarySection {
        .init(
            id: "your_why",
            title: OnboardingCopy.t("Ton pourquoi", en: "Your why"),
            chips: [
                .init(
                    id: "why",
                    emoji: "💪",
                    label: OnboardingCopy.t("Confiance", en: "Confidence")
                )
            ]
        )
    }

    private static func debloatDriverLabel(for driver: OnboardingDebloatDriver) -> String? {
        switch driver {
        case .sleep:
            return OnboardingCopy.t("Gonflement au réveil", en: "Puffiness when I wake up")
        case .nutrition:
            return OnboardingCopy.t("Gonflement lié à l’alimentation", en: "Food-related puffiness")
        case .sedentary:
            return OnboardingCopy.t("Gonflement certains jours", en: "Puffiness some days")
        case .stress:
            return OnboardingCopy.t("Gonflement en fin de journée", en: "Puffiness later in the day")
        case .unknown:
            return OnboardingCopy.t("Pas de gonflement marqué", en: "No major puffiness")
        }
    }

    private static func hydrationSummaryLabel(for level: HydrationLevel) -> String? {
        switch level {
        case .veryPoor, .poor:
            return OnboardingCopy.t("Mieux m’hydrater", en: "Hydrate better")
        case .average, .good:
            return OnboardingCopy.t("Boire plus d’eau", en: "Drink more water")
        case .veryGood, .excellent:
            return OnboardingCopy.t("Garder mes bonnes habitudes", en: "Keep my good habits")
        }
    }
}
