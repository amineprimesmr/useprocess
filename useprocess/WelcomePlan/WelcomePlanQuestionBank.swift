import Foundation

enum WelcomePlanQuestionBank {

    static let all: [WelcomePlanQuestion] = [
        // MARK: Welcome
        WelcomePlanQuestion(
            id: "welcome_ready",
            phase: .welcome,
            kind: .singleChoice,
            prompt: "Quelques questions pour calibrer ton protocole.",
            choices: [
                .init(id: "start", label: "Commencer")
            ]
        ),

        // MARK: Profil visage
        WelcomePlanQuestion(
            id: "face_concerns",
            phase: .profile,
            kind: .multiChoice,
            prompt: "Qu'est-ce qui te dérange le plus sur ton visage ou ton corps en ce moment ?",
            choices: [
                .init(id: "dark_circles", label: "Cernes"),
                .init(id: "puffiness", label: "Visage gonflé"),
                .init(id: "acne", label: "Acné"),
                .init(id: "weak_jaw", label: "Menton reculé"),
                .init(id: "double_chin", label: "Double menton"),
                .init(id: "dull_skin", label: "Peau terne"),
                .init(id: "asymmetry", label: "Asymétrie")
            ]
        ),
        WelcomePlanQuestion(
            id: "body_fat_feel",
            phase: .profile,
            kind: .singleChoice,
            prompt: "Globalement, tu te sens plutôt…",
            choices: [
                .init(id: "very_lean", label: "Très sec"),
                .init(id: "athletic", label: "Athlétique"),
                .init(id: "normal", label: "Normal"),
                .init(id: "soft", label: "Un peu de gras"),
                .init(id: "high", label: "Gras visible")
            ]
        ),

        // MARK: Hormones & sommeil
        WelcomePlanQuestion(
            id: "sleep_quality",
            phase: .hormonesSleep,
            kind: .singleChoice,
            prompt: "Comment tu dors en ce moment ?",
            choices: OnboardingSleepQuality.allCases.map {
                .init(id: $0.rawValue, label: "\($0.emoji) \($0.rawValue)")
            }
        ),
        WelcomePlanQuestion(
            id: "bedtime",
            phase: .hormonesSleep,
            kind: .time,
            prompt: "En général, tu te couches à quelle heure ?"
        ),
        WelcomePlanQuestion(
            id: "wake_time",
            phase: .hormonesSleep,
            kind: .time,
            prompt: "Et tu te réveilles à quelle heure ?"
        ),
        WelcomePlanQuestion(
            id: "screen_before_bed",
            phase: .hormonesSleep,
            kind: .yesNo,
            prompt: "Tu utilises ton téléphone ou un écran dans l'heure avant de dormir ?"
        ),
        WelcomePlanQuestion(
            id: "morning_sunlight",
            phase: .hormonesSleep,
            kind: .singleChoice,
            prompt: "Tu prends du soleil ou de la lumière naturelle le matin ?",
            choices: [
                .init(id: "daily_15", label: "Régulièrement"),
                .init(id: "sometimes", label: "De temps en temps"),
                .init(id: "rarely", label: "Rarement"),
                .init(id: "never", label: "Jamais")
            ]
        ),
        WelcomePlanQuestion(
            id: "caffeine_afternoon",
            phase: .hormonesSleep,
            kind: .yesNo,
            prompt: "Tu bois du café, thé ou boisson énergisante après 14 h ?"
        ),
        WelcomePlanQuestion(
            id: "alcohol_frequency",
            phase: .hormonesSleep,
            kind: .singleChoice,
            prompt: "Tu bois de l'alcool à quelle fréquence ?",
            choices: [
                .init(id: "never", label: "Jamais"),
                .init(id: "rare", label: "Rarement"),
                .init(id: "weekly", label: "Chaque semaine"),
                .init(id: "often", label: "3 fois par semaine ou plus")
            ]
        ),
        WelcomePlanQuestion(
            id: "fatigue_frequency",
            phase: .hormonesSleep,
            kind: .singleChoice,
            prompt: "Tu te sens fatigué pendant la journée ?",
            choices: FatigueFrequency.allCases.map {
                .init(id: $0.rawValue, label: "\($0.emoji) \($0.rawValue)")
            }
        ),

        // MARK: Alimentation
        WelcomePlanQuestion(
            id: "nutrition_quality",
            phase: .nutrition,
            kind: .singleChoice,
            prompt: "Honnêtement, ton alimentation actuelle c'est plutôt…",
            choices: NutritionQuality.allCases.map {
                .init(id: $0.rawValue, label: "\($0.emoji) \($0.comment)")
            }
        ),
        WelcomePlanQuestion(
            id: "processed_food",
            phase: .nutrition,
            kind: .singleChoice,
            prompt: "Tu manges des plats industriels, fast-food ou snacks transformés ?",
            choices: [
                .init(id: "rare", label: "Presque jamais"),
                .init(id: "few_week", label: "Quelques fois par semaine"),
                .init(id: "daily", label: "Presque tous les jours"),
                .init(id: "most_meals", label: "À la plupart de mes repas")
            ]
        ),
        WelcomePlanQuestion(
            id: "animal_protein",
            phase: .nutrition,
            kind: .multiChoice,
            prompt: "Quels aliments protéinés tu manges régulièrement ?",
            choices: [
                .init(id: "red_meat", label: "Viande rouge"),
                .init(id: "organs", label: "Abats (foie, cœur…)"),
                .init(id: "eggs", label: "Œufs"),
                .init(id: "fish", label: "Poisson"),
                .init(id: "poultry", label: "Volaille"),
                .init(id: "raw_dairy", label: "Laitiers (fromage, lait…)"),
                .init(id: "none", label: "Peu ou pas de produits animaux")
            ]
        ),
        WelcomePlanQuestion(
            id: "hydration_level",
            phase: .nutrition,
            kind: .singleChoice,
            prompt: "Tu bois assez d'eau dans la journée ?",
            choices: HydrationLevel.allCases.map {
                .init(id: $0.rawValue, label: $0.rawValue)
            }
        ),
        WelcomePlanQuestion(
            id: "current_meals_count",
            phase: .nutrition,
            kind: .singleChoice,
            prompt: "Aujourd'hui, tu manges combien de repas par jour ?",
            coachIntro: "Compte petit-déjeuner, déjeuner et dîner — pas les grignotages isolés.",
            choices: [
                .init(id: "1", label: "1 repas"),
                .init(id: "2", label: "2 repas"),
                .init(id: "3", label: "3 repas"),
                .init(id: "4", label: "4 repas"),
                .init(id: "5plus", label: "5 repas ou plus")
            ]
        ),
        WelcomePlanQuestion(
            id: "target_meals_count",
            phase: .nutrition,
            kind: .singleChoice,
            prompt: "Quelle structure repas pour ton protocole debloat ?",
            coachIntro: "On configure ton journal et les créneaux IA — 3 options, une seule à choisir.",
            choices: NutritionPlanType.allCases.map { planType in
                .init(id: "\(planType.targetMealsPerDay)", label: planType.label, detail: planType.subtitle)
            }
        ),

        // MARK: Posture & visage
        WelcomePlanQuestion(
            id: "desk_job",
            phase: .postureFace,
            kind: .yesNo,
            prompt: "Tu passes plus de 6 h par jour assis devant un écran ?"
        ),
        WelcomePlanQuestion(
            id: "forward_head",
            phase: .postureFace,
            kind: .yesNo,
            prompt: "Tu as la tête qui part en avant sur téléphone ou ordi ?"
        ),
        WelcomePlanQuestion(
            id: "mouth_breathing",
            phase: .postureFace,
            kind: .yesNo,
            prompt: "Tu respires par la bouche le jour ou la nuit ?"
        ),

        // MARK: Training
        WelcomePlanQuestion(
            id: "training_experience",
            phase: .training,
            kind: .singleChoice,
            prompt: "Ton niveau en musculation / sport ?",
            choices: ExperienceLevel.allCases.map {
                .init(id: $0.rawValue, label: $0.rawValue)
            }
        ),
        WelcomePlanQuestion(
            id: "sessions_per_week",
            phase: .training,
            kind: .singleChoice,
            prompt: "Combien de séances par semaine tu peux vraiment tenir ?",
            choices: [
                .init(id: "1", label: "1"),
                .init(id: "2", label: "2"),
                .init(id: "3", label: "3"),
                .init(id: "4", label: "4"),
                .init(id: "5plus", label: "5 ou plus")
            ]
        ),
        WelcomePlanQuestion(
            id: "training_location",
            phase: .training,
            kind: .singleChoice,
            prompt: "Tu t'entraînes principalement où ?",
            choices: [
                .init(id: TrainingLocation.home.rawValue, label: "À la maison"),
                .init(id: TrainingLocation.gym.rawValue, label: "En salle de sport"),
                .init(id: TrainingLocation.outdoor.rawValue, label: "Dehors"),
                .init(id: TrainingLocation.mixed.rawValue, label: "Un mix des trois")
            ]
        ),
        WelcomePlanQuestion(
            id: "injuries",
            phase: .training,
            kind: .multiChoice,
            prompt: "Tu as des blessures ou douleurs en ce moment ?",
            choices: [
                .init(id: "none", label: "Non, rien"),
                .init(id: "lower_back", label: "Bas du dos"),
                .init(id: "knees", label: "Genoux"),
                .init(id: "shoulders", label: "Épaules"),
                .init(id: "neck", label: "Nuque"),
                .init(id: "other", label: "Autre")
            ]
        ),

        // MARK: Psychologie
        WelcomePlanQuestion(
            id: "consistency_history",
            phase: .psychology,
            kind: .singleChoice,
            prompt: "Quand tu te lances dans une routine, tu tiens combien de temps en général ?",
            choices: [
                .init(id: "weeks", label: "Quelques semaines"),
                .init(id: "months", label: "Quelques mois"),
                .init(id: "long", label: "6 mois ou plus"),
                .init(id: "first_time", label: "C'est ma première vraie tentative")
            ]
        ),
        WelcomePlanQuestion(
            id: "biggest_barrier",
            phase: .psychology,
            kind: .singleChoice,
            prompt: "C'est quoi ton plus gros frein au quotidien ?",
            choices: [
                .init(id: "time", label: "Le manque de temps"),
                .init(id: "motivation", label: "La motivation"),
                .init(id: "knowledge", label: "Je ne sais pas quoi faire"),
                .init(id: "social", label: "Les sorties / l'entourage"),
                .init(id: "stress", label: "Le stress / la charge mentale")
            ]
        ),
        WelcomePlanQuestion(
            id: "commit_plan",
            phase: .psychology,
            kind: .yesNo,
            prompt: "Tu es prêt à t'engager sur la durée de ton protocole — les bases d'abord, pas de raccourci ?"
        ),

        // MARK: Closing
        WelcomePlanQuestion(
            id: "optional_face_scan",
            phase: .closing,
            kind: .singleChoice,
            prompt: "Tu veux faire un scan visage maintenant pour calibrer ton plan ?",
            choices: [
                .init(id: "yes", label: "Maintenant"),
                .init(id: "later", label: "Plus tard"),
                .init(id: "skip", label: "Non merci")
            ]
        )
    ]

    static func activeQuestions(answers: [String: WelcomePlanAnswer]) -> [WelcomePlanQuestion] {
        all.filter { question in
            guard let rule = question.skipWhen else { return true }
            guard let answer = answers[rule.questionId] else { return true }
            let matches = rule.choiceIds.contains(where: { answer.choiceIds.contains($0) })
            return rule.matchAny ? !matches : matches
        }
    }

    static func configurationProgress(answers: [String: WelcomePlanAnswer], isComplete: Bool) -> Double {
        guard !isComplete else { return 1 }
        let questions = activeQuestions(answers: answers)
        guard !questions.isEmpty else { return 0 }
        let answered = questions.filter { answers[$0.id] != nil }.count
        return Double(answered) / Double(questions.count)
    }

    static func isFullyAnswered(answers: [String: WelcomePlanAnswer]) -> Bool {
        let questions = activeQuestions(answers: answers)
        guard !questions.isEmpty else { return false }
        return questions.allSatisfy { answers[$0.id] != nil }
    }

    static func configurationStepLabel(answers: [String: WelcomePlanAnswer], isComplete: Bool) -> String {
        let questions = activeQuestions(answers: answers)
        guard !questions.isEmpty else { return "0 / 0" }
        if isComplete { return "\(questions.count) / \(questions.count)" }
        let answered = questions.filter { answers[$0.id] != nil }.count
        return "\(answered) / \(questions.count)"
    }

    static func phaseLabel(for phase: WelcomePlanPhase) -> String {
        switch phase {
        case .welcome: return "Démarrage"
        case .profile: return "Profil"
        case .hormonesSleep: return "Sommeil & hormones"
        case .nutrition: return "Alimentation"
        case .postureFace: return "Posture"
        case .training: return "Entraînement"
        case .psychology: return "Régularité"
        case .closing: return "Finalisation"
        }
    }

    static func choiceLabel(for questionId: String, choiceId: String) -> String {
        guard let question = all.first(where: { $0.id == questionId }),
              let choice = question.choices.first(where: { $0.id == choiceId || $0.label == choiceId }) else {
            return choiceId
        }
        return choice.label
    }
}
