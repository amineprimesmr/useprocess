import Foundation

struct ProfileSummaryItem: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String?
    var isEditable: Bool = false

    @MainActor
    var displayValue: String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AppCopy.t("Non renseigné", en: "Not provided")
        }
        return value
    }

    var isPlaceholder: Bool {
        value == nil || value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
    }
}

struct ProfileSummarySection: Identifiable, Hashable {
    let id: String
    let title: String
    let rows: [ProfileSummaryItem]
}

@MainActor
enum UserProfileOnboardingSummary {

    static func sections(from profile: UnifiedUserProfile?) -> [ProfileSummarySection] {
        guard let profile else { return [] }

        var result: [ProfileSummarySection] = []

        result.append(identitySection(profile))
        result.append(measurementsSection(profile))
        result.append(goalsSection(profile))
        result.append(nutritionSection(profile))
        result.append(sleepSection(profile))

        return result.filter { !$0.rows.isEmpty }
    }

    // MARK: - Sections

    private static func identitySection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        var rows: [ProfileSummaryItem] = [
            .init(id: "firstName", label: AppCopy.t("Prénom", en: "First Name"), value: profile.firstName, isEditable: true),
            .init(id: "age", label: AppCopy.t("Âge", en: "Age"), value: profile.age > 0 ? profile.ageFormatted : nil),
            .init(id: "gender", label: AppCopy.t("Genre", en: "Gender"), value: profile.gender.displayName)
        ]

        if let email = profile.email, !email.isEmpty {
            rows.append(.init(id: "email", label: "E-mail", value: email))
        }

        rows.append(.init(id: "memberSince", label: AppCopy.t("Membre depuis", en: "Member Since"), value: profile.downloadDateFormatted))

        return .init(id: "identity", title: AppCopy.t("Identité", en: "Identity"), rows: rows)
    }

    private static func measurementsSection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        var rows: [ProfileSummaryItem] = []

        if profile.height > 0 {
            rows.append(.init(id: "height", label: AppCopy.t("Taille", en: "Height"), value: profile.heightFormatted))
        }
        if profile.weight > 0 {
            rows.append(.init(id: "weight", label: AppCopy.t("Poids actuel", en: "Current Weight"), value: profile.weightFormatted))
        }
        if let ideal = profile.idealWeight, ideal > 0 {
            rows.append(.init(id: "idealWeight", label: AppCopy.t("Poids idéal", en: "Ideal Weight"), value: profile.idealWeightFormatted))
        }
        if profile.height > 0, profile.weight > 0 {
            rows.append(
                .init(
                    id: "bmi",
                    label: AppCopy.t("IMC", en: "BMI"),
                    value: String(format: "%.1f — %@", profile.bmi, profile.bmiCategory.displayName)
                )
            )
        }

        return .init(id: "measurements", title: AppCopy.t("Mensurations", en: "Measurements"), rows: rows)
    }

    private static func goalsSection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        var rows: [ProfileSummaryItem] = []

        if let weightGoal = profile.weightGoal {
            rows.append(.init(id: "weightGoal", label: AppCopy.t("Focus debloat", en: "Debloat Focus"), value: weightGoal.title))
        }
        if let goalPace = profile.goalPace {
            rows.append(.init(id: "goalPace", label: AppCopy.t("Rythme souhaité", en: "Desired Pace"), value: goalPace.title))
        }
        if let deadline = profile.goalDeadline, deadline.hasDeadline {
            rows.append(.init(id: "deadline", label: AppCopy.t("Échéance", en: "Deadline"), value: deadline.displayText))
            if let days = deadline.daysRemaining {
                rows.append(.init(id: "deadlineDays", label: AppCopy.t("Jours restants", en: "Days Remaining"), value: "\(max(0, days)) \(AppCopy.t("j", en: "d"))"))
            }
        }
        if let mainGoal = profile.mainGoal {
            rows.append(.init(id: "mainGoal", label: AppCopy.t("Objectif principal", en: "Main Goal"), value: mainGoal.title))
        }

        return .init(id: "goals", title: AppCopy.t("Objectifs", en: "Goals"), rows: rows)
    }

    private static func nutritionSection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        guard let nutrition = profile.nutritionProfile else {
            return .init(id: "nutrition", title: AppCopy.t("Nutrition", en: "Nutrition"), rows: [])
        }

        var rows: [ProfileSummaryItem] = []

        if let quality = nutrition.nutritionQuality {
            rows.append(.init(id: "nutritionQuality", label: AppCopy.t("Alimentation actuelle", en: "Current Diet"), value: quality.title))
        }
        if let experience = nutrition.weightManagementExperience {
            rows.append(.init(id: "weightExperience", label: AppCopy.t("Expérience poids", en: "Weight Management Experience"), value: experience.title))
        }
        if let hydration = nutrition.hydrationLevel {
            rows.append(.init(id: "hydration", label: AppCopy.t("Hydratation", en: "Hydration"), value: hydration.title))
        }
        if let hardest = nutrition.hardestMeal {
            rows.append(.init(id: "hardestMeal", label: AppCopy.t("Repas le plus difficile", en: "Most Difficult Meal"), value: hardest.title))
        }

        let restrictions = nutrition.dietaryRestrictions
            .filter { $0 != .none }
            .map(\.title)
        if !restrictions.isEmpty {
            rows.append(.init(id: "restrictions", label: AppCopy.t("Restrictions", en: "Restrictions"), value: restrictions.joined(separator: ", ")))
        }

        if let obstacles = nonEmptyJoined(nutrition.nutritionObstacles.map(\.title)) {
            rows.append(.init(id: "obstacles", label: AppCopy.t("Obstacles alimentaires", en: "Food Obstacles"), value: obstacles))
        }

        return .init(id: "nutrition", title: AppCopy.t("Nutrition", en: "Nutrition"), rows: rows)
    }

    private static func sleepSection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        guard let sleep = profile.sleepProfile else {
            return .init(id: "sleep", title: AppCopy.t("Sommeil", en: "Sleep"), rows: [])
        }

        var rows: [ProfileSummaryItem] = []

        if let quality = sleep.sleepQuality {
            rows.append(.init(id: "sleepQuality", label: AppCopy.t("Qualité du sommeil", en: "Sleep Quality"), value: quality.title))
        }
        if let fatigue = sleep.fatigueFrequency {
            rows.append(.init(id: "fatigue", label: AppCopy.t("Fréquence de fatigue", en: "Fatigue Frequency"), value: fatigue.title))
        }
        if !sleep.fatiguePeaks.isEmpty {
            let peaks = sleep.fatiguePeaks.map(\.title).joined(separator: ", ")
            rows.append(.init(id: "fatiguePeaks", label: AppCopy.t("Pics de fatigue", en: "Fatigue Peaks"), value: peaks))
        }
        if let hours = sleep.averageSleepHours, hours > 0 {
            rows.append(.init(id: "sleepHours", label: AppCopy.t("Sommeil moyen", en: "Average Sleep"), value: String(format: "%.1f h / %@", hours, AppCopy.t("nuit", en: "night"))))
        }

        rows.append(
            .init(
                id: "chronotype",
                label: AppCopy.t("Chronotype", en: "Chronotype"),
                value: profile.preferences.chronotype.displayName
            )
        )

        return .init(id: "sleep", title: AppCopy.t("Sommeil & énergie", en: "Sleep & Energy"), rows: rows)
    }

    // MARK: - Helpers

    private static func nonEmptyJoined(_ values: [String]) -> String? {
        let filtered = values.filter { !$0.isEmpty }
        guard !filtered.isEmpty else { return nil }
        return filtered.joined(separator: ", ")
    }
}
