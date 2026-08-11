import Foundation

/// Étapes du tutoriel accueil — ordre : scan → eau → repas → circuit → training → série.
enum PlanHomeTutorialStep: String, CaseIterable, Identifiable {
    case faceScan
    case hydration
    case nutrition
    case faceRoutine
    case training
    case streakTab

    var id: String { rawValue }

    static let homeRevealOrder: [PlanHomeSectionKind] = [
        .faceScan,
        .nutrition,
        .faceRoutine,
        .training
    ]

    var focus: PlanHomeTutorialFocus? {
        switch self {
        case .faceScan: .faceScan
        case .hydration: .hydration
        case .nutrition: .meals
        case .faceRoutine: .faceRoutine
        case .training: .training
        case .streakTab: nil
        }
    }

    var homeSection: PlanHomeSectionKind? {
        switch self {
        case .faceScan: .faceScan
        case .hydration, .nutrition: .nutrition
        case .faceRoutine: .faceRoutine
        case .training: .training
        case .streakTab: nil
        }
    }

    var revealThroughSection: PlanHomeSectionKind? {
        switch self {
        case .faceScan: .faceScan
        case .hydration, .nutrition: .nutrition
        case .faceRoutine: .faceRoutine
        case .training: .training
        case .streakTab: nil
        }
    }

    var isTabStep: Bool {
        self == .streakTab
    }

    var mainTab: ProcessMainSection? {
        switch self {
        case .streakTab: .statistics
        default: .plan
        }
    }

    @MainActor
    var title: String {
        switch self {
        case .faceScan:
            AppCopy.t("Scan analyse", en: "Scan analysis")
        case .hydration:
            AppCopy.t("Hydratation", en: "Hydration")
        case .nutrition:
            AppCopy.t("Repas debloat du jour", en: "Today's debloat meals")
        case .faceRoutine:
            AppCopy.t("Circuit lymphatique", en: "Lymphatic circuit")
        case .training:
            AppCopy.t("Cardio et Circuit", en: "Cardio & Circuit")
        case .streakTab:
            AppCopy.t("Série", en: "Streak")
        }
    }

    @MainActor
    var message: String {
        switch self {
        case .faceScan:
            AppCopy.t(
                "Photographie ton visage pour mesurer ton debloat. Process compare tes scans et te montre ta progression visuelle jour après jour.",
                en: "Photograph your face to track debloat. Process compares your scans and shows your visual progress day after day."
            )
        case .hydration:
            AppCopy.t(
                "Suis ton eau du jour, ajoute des verres en un tap et lance le timer hydratation — il continue dans la Dynamic Island.",
                en: "Track daily water intake, log glasses in one tap, and start the hydration timer — it lives in your Dynamic Island."
            )
        case .nutrition:
            AppCopy.t(
                "Tes repas anti-inflammatoires personnalisés. Swipe pour parcourir chaque repas et voir ce qui t'aide à dégonfler.",
                en: "Your personalized anti-inflammatory meals. Swipe through each meal to see what helps you debloat."
            )
        case .faceRoutine:
            AppCopy.t(
                "Drainage lymphatique guidé pour réduire le gonflement du visage. Quelques minutes par jour suffisent.",
                en: "Guided lymphatic drainage to reduce facial puffiness. Just a few minutes a day."
            )
        case .training:
            AppCopy.t(
                "Cardio et circuits adaptés à ton programme debloat. Lance une séance quand tu es prêt.",
                en: "Cardio and circuits tailored to your debloat program. Start a session when you're ready."
            )
        case .streakTab:
            AppCopy.t(
                "Suis ta régularité, valide tes jours et garde ta série active. Chaque jour compte pour ton debloat.",
                en: "Track consistency, validate your days, and keep your streak alive. Every day counts for your debloat."
            )
        }
    }

    var focusesHydrationCarousel: Bool {
        self == .hydration
    }

    var scrollAnchorID: String? {
        focus?.scrollAnchorID
    }
}
