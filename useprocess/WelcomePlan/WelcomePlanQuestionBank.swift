import Foundation

@MainActor
enum WelcomePlanQuestionBank {

    /// Questionnaire plan personnalisé — 10 questions essentielles, posées dans le coach.
    static var all: [WelcomePlanQuestion] {
        [
            WelcomePlanQuestion(
                id: "bedtime",
                phase: .hormonesSleep,
                kind: .time,
                prompt: AppCopy.t(
                    "En général, tu te couches à quelle heure ?",
                    en: "What time do you usually go to bed?"
                )
            ),
            WelcomePlanQuestion(
                id: "wake_time",
                phase: .hormonesSleep,
                kind: .time,
                prompt: AppCopy.t(
                    "Et tu te réveilles à quelle heure ?",
                    en: "And what time do you usually wake up?"
                )
            ),
            WelcomePlanQuestion(
                id: "screen_before_bed",
                phase: .hormonesSleep,
                kind: .yesNo,
                prompt: AppCopy.t(
                    "Tu utilises ton téléphone ou un écran dans l'heure avant de dormir ?",
                    en: "Do you use your phone or a screen in the hour before bed?"
                )
            ),
            WelcomePlanQuestion(
                id: "stimulant_habits",
                phase: .hormonesSleep,
                kind: .multiChoice,
                prompt: AppCopy.t(
                    "Tu consommes régulièrement…",
                    en: "Do you regularly consume…"
                ),
                choices: [
                    .init(id: "alcohol", label: AppCopy.t("Alcool", en: "Alcohol")),
                    .init(id: "coffee", label: AppCopy.t("Café ou thé", en: "Coffee or tea")),
                    .init(id: "energy", label: AppCopy.t("Boissons énergisantes", en: "Energy drinks")),
                    .init(id: "none", label: AppCopy.t("Aucun de ces trois", en: "None of these"))
                ]
            ),
            WelcomePlanQuestion(
                id: "current_meals_count",
                phase: .nutrition,
                kind: .singleChoice,
                prompt: AppCopy.t(
                    "Aujourd'hui, tu manges combien de repas par jour ?",
                    en: "How many meals do you eat per day right now?"
                ),
                choices: [
                    .init(id: "1", label: AppCopy.t("1 repas", en: "1 meal")),
                    .init(id: "2", label: AppCopy.t("2 repas", en: "2 meals")),
                    .init(id: "3", label: AppCopy.t("3 repas", en: "3 meals")),
                    .init(id: "4", label: AppCopy.t("4 repas", en: "4 meals")),
                    .init(id: "5plus", label: AppCopy.t("5 repas ou plus", en: "5 meals or more"))
                ]
            ),
            WelcomePlanQuestion(
                id: "desk_job",
                phase: .postureFace,
                kind: .yesNo,
                prompt: AppCopy.t(
                    "Tu passes plus de 6 h par jour assis devant un écran ?",
                    en: "Do you spend more than 6 hours a day sitting in front of a screen?"
                )
            ),
            WelcomePlanQuestion(
                id: "forward_head",
                phase: .postureFace,
                kind: .yesNo,
                prompt: AppCopy.t(
                    "Tu as la tête qui part en avant sur téléphone ou ordi ?",
                    en: "Does your head drift forward when you're on your phone or computer?"
                )
            ),
            WelcomePlanQuestion(
                id: "mouth_breathing",
                phase: .postureFace,
                kind: .singleChoice,
                prompt: AppCopy.t(
                    "Tu respires plutôt par la bouche ou par le nez ?",
                    en: "Do you tend to breathe through your mouth or your nose?"
                ),
                choices: [
                    .init(id: "mouth", label: AppCopy.t("Par la bouche", en: "Through my mouth")),
                    .init(id: "nose", label: AppCopy.t("Par le nez", en: "Through my nose")),
                    .init(id: "mixed", label: AppCopy.t("Les deux selon le moment", en: "Both, depending on the moment"))
                ]
            ),
            WelcomePlanQuestion(
                id: "sessions_per_week",
                phase: .training,
                kind: .singleChoice,
                prompt: AppCopy.t(
                    "Combien de séances cardio par semaine tu peux tenir ? (idéal chaque jour · min. 3)",
                    en: "How many cardio sessions per week can you stick to? (ideal: every day · min. 3)"
                ),
                choices: [
                    .init(id: "1", label: "1"),
                    .init(id: "2", label: "2"),
                    .init(id: "3", label: "3"),
                    .init(id: "4", label: "4"),
                    .init(
                        id: "5plus",
                        label: AppCopy.t("5 ou plus / presque chaque jour", en: "5+ / almost every day")
                    )
                ]
            ),
            WelcomePlanQuestion(
                id: "primary_sport",
                phase: .training,
                kind: .singleChoice,
                prompt: AppCopy.t(
                    "Quel cardio tu pratiques ou veux pratiquer ?",
                    en: "What cardio do you do or want to do?"
                ),
                choices: [
                    .init(id: "running", label: AppCopy.t("Course / marche rapide", en: "Running / brisk walking")),
                    .init(id: "cardio", label: AppCopy.t("Cardio (vélo, rameur…)", en: "Cardio (bike, rower…)")),
                    .init(id: "swimming", label: AppCopy.t("Natation", en: "Swimming")),
                    .init(id: "team", label: AppCopy.t("Sports collectifs", en: "Team sports")),
                    .init(id: "other", label: AppCopy.t("Autre", en: "Other"))
                ]
            )
        ]
    }

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
        case .welcome: return AppCopy.t("Démarrage", en: "Getting started")
        case .profile: return AppCopy.t("Profil", en: "Profile")
        case .hormonesSleep: return AppCopy.t("Sommeil", en: "Sleep")
        case .nutrition: return AppCopy.t("Alimentation", en: "Nutrition")
        case .postureFace: return AppCopy.t("Posture", en: "Posture")
        case .training: return AppCopy.t("Cardio", en: "Cardio")
        case .psychology: return AppCopy.t("Régularité", en: "Consistency")
        case .closing: return AppCopy.t("Finalisation", en: "Wrap-up")
        }
    }

    static func choiceLabel(for questionId: String, choiceId: String) -> String {
        if choiceId == "yes" { return AppCopy.yes }
        if choiceId == "no" { return AppCopy.no }
        if choiceId == "continue" { return AppCopy.continueCTA }
        guard let question = all.first(where: { $0.id == questionId }),
              let choice = question.choices.first(where: { $0.id == choiceId || $0.label == choiceId }) else {
            return choiceId
        }
        return choice.label
    }
}
