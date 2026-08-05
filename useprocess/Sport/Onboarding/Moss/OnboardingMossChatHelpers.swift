//
//  OnboardingMossChatHelpers.swift
//  useprocess
//
//  Pont entre la banque de questions Process et le moteur Moss.
//

import Foundation

@MainActor
enum OnboardingMossChatHelpers {
    static func mossLines(
        for question: OnboardingProfileChatQuestion,
        emotionalFirstBlock: Bool = false
    ) -> [MossLine] {
        question.assistantPresentationBlocks.enumerated().map { index, text in
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
            engine.speak(mossLines(for: resolved), instant: true)
            if let answer = OnboardingProfileChatQuestionBank.savedAnswerDisplay(
                for: resolved.id,
                viewModel: viewModel
            ) {
                engine.userReplied(answer)
            }
        }
    }
}
