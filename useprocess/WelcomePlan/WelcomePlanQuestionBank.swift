import Foundation

enum WelcomePlanQuestionBank {

    static let all: [WelcomePlanQuestion] = [
        // MARK: Welcome
        WelcomePlanQuestion(
            id: "welcome_ready",
            phase: .welcome,
            kind: .singleChoice,
            prompt: "Quelques questions pour calibrer ton protocole. 100 % naturel, zéro pilule.",
            coachIntro: "Salut — je suis ton coach Process. On configure ton plan en quelques minutes.",
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
            coachIntro: "Dis-moi ce qui te dérange le plus aujourd'hui.",
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
        WelcomePlanQuestion(
            id: "motivation",
            phase: .profile,
            kind: .singleChoice,
            prompt: "Aujourd'hui, tu te sens plutôt…",
            choices: [
                .init(id: "high", label: "Très motivé"),
                .init(id: "medium", label: "Motivé mais pas régulier"),
                .init(id: "low", label: "J'ai besoin qu'on m'accompagne"),
                .init(id: "restart", label: "Je repars de zéro")
            ]
        ),

        // MARK: Hormones & sommeil
        WelcomePlanQuestion(
            id: "sleep_quality",
            phase: .hormonesSleep,
            kind: .singleChoice,
            prompt: "Comment tu dors en ce moment ?",
            coachIntro: "Le visage se répare la nuit. Sans sommeil profond, le reste ne marchera pas."
        ,
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
        WelcomePlanQuestion(
            id: "fatigue_peaks",
            phase: .hormonesSleep,
            kind: .multiChoice,
            prompt: "À quel moment tu es le plus cuit ?",
            choices: FatiguePeaks.allCases.map {
                .init(id: $0.rawValue, label: "\($0.emoji) \($0.rawValue)")
            }
        ),

        // MARK: Alimentation
        WelcomePlanQuestion(
            id: "nutrition_quality",
            phase: .nutrition,
            kind: .singleChoice,
            prompt: "Honnêtement, ton alimentation actuelle c'est plutôt…",
            coachIntro: "Ce que tu manges sculpte ton visage. Dense, naturel, digeste — pas de pilules."
        ,
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
            id: "sugar_frequency",
            phase: .nutrition,
            kind: .singleChoice,
            prompt: "Le sucre ajouté (sodas, desserts, céréales sucrées) ?",
            choices: [
                .init(id: "rare", label: "Rarement"),
                .init(id: "few_week", label: "Quelques fois par semaine"),
                .init(id: "daily", label: "Tous les jours"),
                .init(id: "cravings", label: "J'ai des fringales tout le temps")
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
            id: "cooking_frequency",
            phase: .nutrition,
            kind: .singleChoice,
            prompt: "Tu cuisines toi-même tes repas ?",
            choices: [
                .init(id: "daily", label: "Presque tous les jours"),
                .init(id: "often", label: "Souvent"),
                .init(id: "sometimes", label: "Parfois"),
                .init(id: "rarely", label: "Rarement")
            ]
        ),
        WelcomePlanQuestion(
            id: "dietary_restrictions",
            phase: .nutrition,
            kind: .multiChoice,
            prompt: "Tu as des restrictions alimentaires ?",
            choices: DietaryRestriction.allCases.filter {
                $0 != .halal && $0 != .kosher && $0 != .nutAllergy && $0 != .eggAllergy && $0 != .soyAllergy
            }.map {
                .init(id: $0.rawValue, label: $0.rawValue)
            }
        ),
        WelcomePlanQuestion(
            id: "nutrition_obstacles",
            phase: .nutrition,
            kind: .multiChoice,
            prompt: "Qu'est-ce qui t'empêche le plus de bien manger ?",
            choices: NutritionObstacle.allCases.map {
                .init(id: $0.rawValue, label: $0.rawValue)
            }
        ),
        WelcomePlanQuestion(
            id: "supplements_use",
            phase: .nutrition,
            kind: .singleChoice,
            prompt: "Tu prends des compléments alimentaires ou vitamines ?",
            choices: [
                .init(id: "none", label: "Non"),
                .init(id: "basic", label: "Multivitamines"),
                .init(id: "many", label: "Plusieurs produits"),
                .init(id: "want_stop", label: "Oui, j'arrête")
            ]
        ),

        // MARK: Posture & visage
        WelcomePlanQuestion(
            id: "desk_job",
            phase: .postureFace,
            kind: .yesNo,
            prompt: "Tu passes plus de 6 h par jour assis devant un écran ?",
            coachIntro: "La posture du cou influence ton maxillaire et ton visage."
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
        WelcomePlanQuestion(
            id: "tongue_posture",
            phase: .postureFace,
            kind: .singleChoice,
            prompt: "Tu pratiques le mewing (langue au palais) au repos ?",
            choices: [
                .init(id: "practice", label: "Oui, au quotidien"),
                .init(id: "aware", label: "J'en ai entendu parler"),
                .init(id: "no", label: "Non, c'est quoi ?")
            ]
        ),
        WelcomePlanQuestion(
            id: "chewing_habit",
            phase: .postureFace,
            kind: .singleChoice,
            prompt: "Tu mâches longtemps avant d'avaler (mastication lente) ?",
            choices: [
                .init(id: "always", label: "Oui, je prends mon temps"),
                .init(id: "sometimes", label: "Parfois"),
                .init(id: "fast", label: "Non, je mange vite")
            ]
        ),

        // MARK: Training
        WelcomePlanQuestion(
            id: "training_experience",
            phase: .training,
            kind: .singleChoice,
            prompt: "Ton niveau en musculation / sport ?",
            coachIntro: "L'entraînement adapte le corps — mais seulement si le sommeil et l'alimentation suivent."
        ,
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
        WelcomePlanQuestion(
            id: "cardio_preference",
            phase: .training,
            kind: .singleChoice,
            prompt: "Pour le cardio, tu préfères quoi ?",
            choices: [
                .init(id: "walking", label: "Marche / rando"),
                .init(id: "running", label: "Course"),
                .init(id: "cycling", label: "Vélo"),
                .init(id: "minimal", label: "Le minimum possible"),
                .init(id: "mixed", label: "Un peu de tout")
            ]
        ),

        // MARK: Psychologie
        WelcomePlanQuestion(
            id: "consistency_history",
            phase: .psychology,
            kind: .singleChoice,
            prompt: "Quand tu te lances dans une routine, tu tiens combien de temps en général ?",
            coachIntro: "Presque fini. La régularité compte plus que l'intensité."
        ,
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
            id: "social_support",
            phase: .psychology,
            kind: .yesNo,
            prompt: "Tu as quelqu'un qui te soutient dans ce changement ?"
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
            coachIntro: "J'ai ce qu'il me faut. Je génère ton Protocole Origine."
        ,
            choices: [
                .init(id: "yes", label: "Maintenant"),
                .init(id: "later", label: "Plus tard"),
                .init(id: "skip", label: "Non merci")
            ]
        ),
        WelcomePlanQuestion(
            id: "extra_notes",
            phase: .closing,
            kind: .text,
            prompt: "Un truc important que je devrais savoir ? (optionnel)",
            allowsSkip: true
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

    static func choiceLabel(for questionId: String, choiceId: String) -> String {
        guard let question = all.first(where: { $0.id == questionId }),
              let choice = question.choices.first(where: { $0.id == choiceId || $0.label == choiceId }) else {
            return choiceId
        }
        return choice.label
    }

    static func phaseTransitionMessage(for phase: WelcomePlanPhase) -> String? {
        switch phase {
        case .welcome: return nil
        case .profile: return "Ton profil."
        case .hormonesSleep: return "Sommeil et rythme."
        case .nutrition: return "Alimentation."
        case .postureFace: return "Posture et maxillaire."
        case .training: return "Entraînement."
        case .psychology: return "Régularité."
        case .closing: return nil
        }
    }
}
