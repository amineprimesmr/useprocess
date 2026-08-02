import Foundation

enum WelcomePlanQuestionBank {

    /// Questionnaire plan personnalisé — 10 questions essentielles, posées dans le coach.
    static let all: [WelcomePlanQuestion] = [
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
            id: "stimulant_habits",
            phase: .hormonesSleep,
            kind: .multiChoice,
            prompt: "Tu consommes régulièrement…",
            choices: [
                .init(id: "alcohol", label: "Alcool"),
                .init(id: "coffee", label: "Café ou thé"),
                .init(id: "energy", label: "Boissons énergisantes"),
                .init(id: "none", label: "Aucun de ces trois")
            ]
        ),
        WelcomePlanQuestion(
            id: "current_meals_count",
            phase: .nutrition,
            kind: .singleChoice,
            prompt: "Aujourd'hui, tu manges combien de repas par jour ?",
            choices: [
                .init(id: "1", label: "1 repas"),
                .init(id: "2", label: "2 repas"),
                .init(id: "3", label: "3 repas"),
                .init(id: "4", label: "4 repas"),
                .init(id: "5plus", label: "5 repas ou plus")
            ]
        ),
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
            kind: .singleChoice,
            prompt: "Tu respires plutôt par la bouche ou par le nez ?",
            choices: [
                .init(id: "mouth", label: "Par la bouche"),
                .init(id: "nose", label: "Par le nez"),
                .init(id: "mixed", label: "Les deux selon le moment")
            ]
        ),
        WelcomePlanQuestion(
            id: "sessions_per_week",
            phase: .training,
            kind: .singleChoice,
            prompt: "Combien de séances cardio par semaine tu peux tenir ? (idéal chaque jour · min. 3)",
            choices: [
                .init(id: "1", label: "1"),
                .init(id: "2", label: "2"),
                .init(id: "3", label: "3"),
                .init(id: "4", label: "4"),
                .init(id: "5plus", label: "5 ou plus / presque chaque jour")
            ]
        ),
        WelcomePlanQuestion(
            id: "primary_sport",
            phase: .training,
            kind: .singleChoice,
            prompt: "Quel cardio tu pratiques ou veux pratiquer ?",
            choices: [
                .init(id: "running", label: "Course / marche rapide"),
                .init(id: "cardio", label: "Cardio (vélo, rameur…)"),
                .init(id: "swimming", label: "Natation"),
                .init(id: "team", label: "Sports collectifs"),
                .init(id: "other", label: "Autre")
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
        case .hormonesSleep: return "Sommeil"
        case .nutrition: return "Alimentation"
        case .postureFace: return "Posture"
        case .training: return "Cardio"
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
