import Foundation

/// Phrases courtes et personnalisées pour le chat Protocole Origine.
enum WelcomePlanCoachCopy {

    // MARK: - Transitions de phase

    static func phaseTransition(
        for phase: WelcomePlanPhase,
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?
    ) -> String? {
        switch phase {
        case .welcome, .closing:
            return nil
        case .profile:
            return profileLine("C'est parti.", profile: profile, named: { "C'est parti, \($0)." })
        case .hormonesSleep:
            return hormonesSleepTransition(answers: answers)
        case .nutrition:
            return nutritionTransition(answers: answers)
        case .postureFace:
            return postureTransition(answers: answers)
        case .training:
            return trainingTransition(answers: answers)
        case .psychology:
            return psychologyTransition(answers: answers)
        }
    }

    // MARK: - Intros question (hors transition de phase)

    static func coachIntro(
        for question: WelcomePlanQuestion,
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?,
        skipBecausePhaseTransition: Bool
    ) -> String? {
        if skipBecausePhaseTransition, isFirstQuestion(in: question.phase, questionId: question.id) {
            return nil
        }

        switch question.id {
        case "welcome_ready":
            return welcomeIntro(profile: profile)
        case "optional_face_scan":
            return closingIntro(answers: answers, profile: profile)
        default:
            return nil
        }
    }

    // MARK: - Private

    private static func isFirstQuestion(in phase: WelcomePlanPhase, questionId: String) -> Bool {
        questionId == firstQuestionID(in: phase)
    }

    private static func firstQuestionID(in phase: WelcomePlanPhase) -> String {
        switch phase {
        case .welcome: "welcome_ready"
        case .profile: "face_concerns"
        case .hormonesSleep: "sleep_quality"
        case .nutrition: "nutrition_quality"
        case .postureFace: "desk_job"
        case .training: "training_experience"
        case .psychology: "consistency_history"
        case .closing: "optional_face_scan"
        }
    }

    private static func welcomeIntro(profile: UnifiedUserProfile?) -> String? {
        profileLine(
            "Salut. On calibre ton protocole en 2 minutes.",
            profile: profile,
            named: { "Salut \($0). On calibre ton protocole en 2 minutes." }
        )
    }

    private static func hormonesSleepTransition(answers: [String: WelcomePlanAnswer]) -> String {
        let concerns = choices("face_concerns", in: answers)

        if concerns.contains("dark_circles") {
            return "Cernes notés — on regarde ton sommeil."
        }
        if concerns.contains("puffiness") {
            return "Gonflement — souvent lié au rythme et au sommeil."
        }
        if concerns.contains("weak_jaw") || concerns.contains("double_chin") {
            return "Mâchoire en jeu — le sommeil change tout."
        }
        if concerns.contains("acne") || concerns.contains("dull_skin") {
            return "Peau en cause — on commence par la nuit."
        }
        if choice("body_fat_feel", in: answers) == "soft" || choice("body_fat_feel", in: answers) == "high" {
            return "Avant tout : ton sommeil."
        }
        return "Bloc sommeil."
    }

    private static func nutritionTransition(answers: [String: WelcomePlanAnswer]) -> String {
        let sleep = choice("sleep_quality", in: answers) ?? ""
        if sleep.contains("Mauvais") || sleep.contains("Très mauvais") {
            return "Tu dors mal — l'assiette va t'aider."
        }
        if choice("screen_before_bed", in: answers) == "yes" {
            return "Écrans le soir — on ajuste aussi ta nourriture."
        }
        if choice("caffeine_afternoon", in: answers) == "yes" {
            return "Caféine tardive — on calibre l'alimentation."
        }
        if choice("fatigue_frequency", in: answers) == FatigueFrequency.often.rawValue ||
            choice("fatigue_frequency", in: answers) == FatigueFrequency.always.rawValue {
            return "Fatigue en journée — on densifie tes repas."
        }
        return "Côté assiette."
    }

    private static func postureTransition(answers: [String: WelcomePlanAnswer]) -> String {
        let concerns = choices("face_concerns", in: answers)
        if concerns.contains("asymmetry") || concerns.contains("weak_jaw") {
            return "Posture : ça impacte direct ton visage."
        }
        if choice("processed_food", in: answers) == "daily" || choice("processed_food", in: answers) == "most_meals" {
            return "Maintenant : posture et respiration."
        }
        if choices("animal_protein", in: answers).contains("none") {
            return "Posture — souvent le chaînon manquant."
        }
        return "Posture."
    }

    private static func trainingTransition(answers: [String: WelcomePlanAnswer]) -> String {
        let body = choice("body_fat_feel", in: answers)
        if body == "athletic" || body == "very_lean" {
            return "Bon profil — on structure tes séances."
        }
        if body == "soft" || body == "high" {
            return "On bouge, progressif et tenable."
        }
        if choice("forward_head", in: answers) == "yes" || choice("mouth_breathing", in: answers) == "yes" {
            return "Posture fragile — training adapté."
        }
        if choice("desk_job", in: answers) == "yes" {
            return "Bureau toute la journée — on compense au sport."
        }
        return "Séances et rythme."
    }

    private static func psychologyTransition(answers: [String: WelcomePlanAnswer]) -> String {
        let sessions = choice("sessions_per_week", in: answers)
        if sessions == "1" || sessions == "2" {
            return "Peu de séances — la régularité quotidienne compte."
        }
        let injuries = choices("injuries", in: answers)
        if injuries.contains(where: { $0 != "none" }) && !injuries.isEmpty {
            return "Blessures notées — on verrouille ta constance."
        }
        if choice("training_experience", in: answers) == ExperienceLevel.debutant.rawValue {
            return "Débutant — on ancre des habitudes simples."
        }
        return "Presque fini."
    }

    private static func closingIntro(
        answers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?
    ) -> String? {
        let concernCount = choices("face_concerns", in: answers).count
        if concernCount >= 3 {
            return profileLine(
                "J'ai tes priorités. Dernier choix.",
                profile: profile,
                named: { "\($0), j'ai tes priorités. Dernier choix." }
            )
        }
        if choice("consistency_history", in: answers) == "first_time" {
            return "Première vraie tentative — je te construis un plan réaliste."
        }
        return profileLine(
            "J'ai ce qu'il me faut.",
            profile: profile,
            named: { "Ok \($0), j'ai ce qu'il me faut." }
        )
    }

    private static func profileLine(
        _ fallback: String,
        profile: UnifiedUserProfile?,
        named: (String) -> String
    ) -> String {
        guard let name = firstName(from: profile) else { return fallback }
        return named(name)
    }

    private static func firstName(from profile: UnifiedUserProfile?) -> String? {
        let name = profile?.firstName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }

    private static func choices(_ id: String, in answers: [String: WelcomePlanAnswer]) -> [String] {
        answers[id]?.choiceIds ?? []
    }
}
