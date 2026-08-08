//
//  OnboardingMossChatHelpers.swift
//  useprocess
//
//  Pont entre la banque de questions Process et le moteur Moss.
//

import Foundation

@MainActor
enum OnboardingMossChatHelpers {
    /// Questions à réponses (hors intros info) — affichent `(x/x)` dans le prompt.
    static func isNumberedAnswerQuestion(_ question: OnboardingProfileChatQuestion) -> Bool {
        switch question.kind {
        case .singleChoice, .multiChoice, .yesNo:
            return true
        default:
            return false
        }
    }

    static func answerProgress(
        for question: OnboardingProfileChatQuestion,
        in questions: [OnboardingProfileChatQuestion]
    ) -> (current: Int, total: Int)? {
        guard isNumberedAnswerQuestion(question) else { return nil }
        let numbered = questions.filter(isNumberedAnswerQuestion)
        guard let index = numbered.firstIndex(where: { $0.id == question.id }) else { return nil }
        return (index + 1, numbered.count)
    }

    static func mossLines(
        for question: OnboardingProfileChatQuestion,
        emotionalFirstBlock: Bool = false,
        progress: (current: Int, total: Int)? = nil
    ) -> [MossLine] {
        var blocks = question.assistantPresentationBlocks
        if let progress, isNumberedAnswerQuestion(question), !blocks.isEmpty {
            let suffix = " (\(progress.current)/\(progress.total))"
            let last = blocks.count - 1
            let trimmed = blocks[last].trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.contains(suffix) {
                blocks[last] = trimmed + suffix
            }
        }

        return blocks.enumerated().map { index, text in
            let profile: MossTypingProfile = text.count > 120 ? .explanatory : .standard
            let emotional = emotionalFirstBlock && index == 0
            return MossLine(
                lineID(questionID: question.id, blockIndex: index),
                text,
                profile: profile,
                emotional: emotional
            )
        }
    }

    static func lineID(questionID: String, blockIndex: Int) -> String {
        "process.chat.\(questionID).\(blockIndex)"
    }

    static func replaySavedConversation(
        engine: MossConversationEngine,
        questions: [OnboardingProfileChatQuestion],
        completedIDs: Set<String>,
        viewModel: OnboardingViewModel
    ) {
        engine.reset()
        for question in questions where completedIDs.contains(question.id) {
            let resolved = OnboardingProfileChatQuestionBank.resolvedQuestion(question, for: viewModel)
            let progress = answerProgress(for: resolved, in: questions)
            engine.speak(mossLines(for: resolved, progress: progress), instant: true)
            if let answer = OnboardingProfileChatQuestionBank.savedAnswerDisplay(
                for: resolved.id,
                viewModel: viewModel
            ) {
                engine.userReplied(answer)
            }
        }
    }
}
