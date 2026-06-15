import Foundation

struct ProfileSummaryItem: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String?
    var isEditable: Bool = false

    var displayValue: String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Non renseigné"
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

enum UserProfileOnboardingSummary {

    static func sections(from profile: UnifiedUserProfile?) -> [ProfileSummarySection] {
        guard let profile else { return [] }

        var result: [ProfileSummarySection] = []

        result.append(identitySection(profile))
        result.append(measurementsSection(profile))
        result.append(goalsSection(profile))
        result.append(sportSection(profile))
        result.append(nutritionSection(profile))
        result.append(sleepSection(profile))

        if let face = OnboardingFaceMarkersStore.load() {
            result.append(faceScanSection(face))
        }

        return result.filter { !$0.rows.isEmpty }
    }

    // MARK: - Sections

    private static func identitySection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        var rows: [ProfileSummaryItem] = [
            .init(id: "firstName", label: "Prénom", value: profile.firstName, isEditable: true),
            .init(id: "age", label: "Âge", value: profile.age > 0 ? profile.ageFormatted : nil),
            .init(id: "gender", label: "Genre", value: profile.gender.displayName),
            .init(id: "birthDate", label: "Date de naissance", value: profile.birthDateFormatted)
        ]

        if let email = profile.email, !email.isEmpty {
            rows.append(.init(id: "email", label: "E-mail", value: email))
        }

        rows.append(.init(id: "memberSince", label: "Membre depuis", value: profile.downloadDateFormatted))

        return .init(id: "identity", title: "Identité", rows: rows)
    }

    private static func measurementsSection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        var rows: [ProfileSummaryItem] = []

        if profile.height > 0 {
            rows.append(.init(id: "height", label: "Taille", value: profile.heightFormatted))
        }
        if profile.weight > 0 {
            rows.append(.init(id: "weight", label: "Poids actuel", value: profile.weightFormatted))
        }
        if let ideal = profile.idealWeight, ideal > 0 {
            rows.append(.init(id: "idealWeight", label: "Poids idéal", value: profile.idealWeightFormatted))
        }
        if profile.height > 0, profile.weight > 0 {
            rows.append(
                .init(
                    id: "bmi",
                    label: "IMC",
                    value: String(format: "%.1f — %@", profile.bmi, profile.bmiCategory.displayName)
                )
            )
        }

        return .init(id: "measurements", title: "Mensurations", rows: rows)
    }

    private static func goalsSection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        var rows: [ProfileSummaryItem] = []

        if let weightGoal = profile.weightGoal {
            rows.append(.init(id: "weightGoal", label: "Objectif poids", value: weightGoal.rawValue))
        }
        if let goalPace = profile.goalPace {
            rows.append(.init(id: "goalPace", label: "Rythme souhaité", value: goalPace.rawValue))
        }
        if let deadline = profile.goalDeadline, deadline.hasDeadline {
            rows.append(.init(id: "deadline", label: "Échéance", value: deadline.displayText))
            if let days = deadline.daysRemaining {
                rows.append(.init(id: "deadlineDays", label: "Jours restants", value: "\(max(0, days)) j"))
            }
        }
        if let mainGoal = profile.mainGoal {
            rows.append(.init(id: "mainGoal", label: "Objectif principal", value: mainGoal.rawValue))
        }

        return .init(id: "goals", title: "Objectifs", rows: rows)
    }

    private static func sportSection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        var rows: [ProfileSummaryItem] = []

        if !profile.sports.isEmpty {
            rows.append(.init(id: "sports", label: "Sports pratiqués", value: profile.sportsList))
        }
        if let level = profile.experienceLevel {
            rows.append(.init(id: "experience", label: "Niveau d'expérience", value: level.rawValue))
        }
        if let years = profile.yearsOfExperience, years > 0 {
            rows.append(.init(id: "years", label: "Années de pratique", value: "\(years) an\(years > 1 ? "s" : "")"))
        }

        rows.append(.init(id: "activity", label: "Niveau d'activité", value: profile.activityLevel.displayName))

        if let sessions = profile.sessionsPerWeek, sessions > 0 {
            rows.append(.init(id: "sessions", label: "Séances / semaine", value: "\(sessions)"))
        }
        if let duration = profile.sessionDuration, duration > 0 {
            rows.append(.init(id: "duration", label: "Durée séance", value: "\(duration) min"))
        }
        if let location = profile.trainingLocation {
            rows.append(.init(id: "location", label: "Lieu d'entraînement", value: location.rawValue))
        }
        if let equipment = profile.availableEquipment, !equipment.isEmpty {
            let list = equipment.map(\.rawValue).joined(separator: ", ")
            rows.append(.init(id: "equipment", label: "Équipement", value: list))
        }

        return .init(id: "sport", title: "Sport & entraînement", rows: rows)
    }

    private static func nutritionSection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        guard let nutrition = profile.nutritionProfile else {
            return .init(id: "nutrition", title: "Nutrition", rows: [])
        }

        var rows: [ProfileSummaryItem] = []

        if let quality = nutrition.nutritionQuality {
            rows.append(.init(id: "nutritionQuality", label: "Alimentation actuelle", value: quality.rawValue))
        }
        if let experience = nutrition.weightManagementExperience {
            rows.append(.init(id: "weightExperience", label: "Expérience poids", value: experience.rawValue))
        }
        if let hydration = nutrition.hydrationLevel {
            rows.append(.init(id: "hydration", label: "Hydratation", value: hydration.rawValue))
        }
        if let hardest = nutrition.hardestMeal {
            rows.append(.init(id: "hardestMeal", label: "Repas le plus difficile", value: hardest.rawValue))
        }

        let restrictions = nutrition.dietaryRestrictions
            .filter { $0 != .none }
            .map(\.rawValue)
        if !restrictions.isEmpty {
            rows.append(.init(id: "restrictions", label: "Restrictions", value: restrictions.joined(separator: ", ")))
        }

        if let obstacles = nonEmptyJoined(nutrition.nutritionObstacles.map(\.rawValue)) {
            rows.append(.init(id: "obstacles", label: "Obstacles alimentaires", value: obstacles))
        }

        return .init(id: "nutrition", title: "Nutrition", rows: rows)
    }

    private static func sleepSection(_ profile: UnifiedUserProfile) -> ProfileSummarySection {
        guard let sleep = profile.sleepProfile else {
            return .init(id: "sleep", title: "Sommeil", rows: [])
        }

        var rows: [ProfileSummaryItem] = []

        if let quality = sleep.sleepQuality {
            rows.append(.init(id: "sleepQuality", label: "Qualité du sommeil", value: quality.rawValue))
        }
        if let fatigue = sleep.fatigueFrequency {
            rows.append(.init(id: "fatigue", label: "Fréquence de fatigue", value: fatigue.rawValue))
        }
        if !sleep.fatiguePeaks.isEmpty {
            let peaks = sleep.fatiguePeaks.map(\.rawValue).joined(separator: ", ")
            rows.append(.init(id: "fatiguePeaks", label: "Pics de fatigue", value: peaks))
        }
        if let hours = sleep.averageSleepHours, hours > 0 {
            rows.append(.init(id: "sleepHours", label: "Sommeil moyen", value: String(format: "%.1f h / nuit", hours)))
        }

        rows.append(
            .init(
                id: "chronotype",
                label: "Chronotype",
                value: profile.preferences.chronotype.displayName
            )
        )

        return .init(id: "sleep", title: "Sommeil & énergie", rows: rows)
    }

    private static func faceScanSection(_ face: FaceWellnessMarkers) -> ProfileSummarySection {
        .init(
            id: "faceScan",
            title: "Scan visage (onboarding)",
            rows: [
                .init(id: "skinClarity", label: "Clarté de peau", value: scoreLabel(face.skinClarityScore)),
                .init(id: "underEye", label: "Fatigue sous les yeux", value: scoreLabel(face.underEyeFatigueScore)),
                .init(id: "puffiness", label: "Gonflement", value: scoreLabel(face.puffinessScore)),
                .init(id: "jawTension", label: "Tension mâchoire", value: scoreLabel(face.jawTensionScore)),
                .init(id: "symmetry", label: "Symétrie faciale", value: scoreLabel(face.facialSymmetryScore))
            ]
        )
    }

    // MARK: - Helpers

    private static func scoreLabel(_ score: Int) -> String {
        "\(score)/100"
    }

    private static func nonEmptyJoined(_ values: [String]) -> String? {
        let filtered = values.filter { !$0.isEmpty }
        guard !filtered.isEmpty else { return nil }
        return filtered.joined(separator: ", ")
    }
}
