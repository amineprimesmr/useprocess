import SwiftUI

enum WelcomePlanChatAnswerReveal {
    static let staggerDelay: UInt64 = 36_000_000
    static let initialDelay: UInt64 = 85_000_000

    static func orderedIDs(for question: WelcomePlanQuestion) -> [String] {
        switch question.kind {
        case .yesNo:
            return ["yes", "no"]
        case .singleChoice:
            return question.choices.map(\.id)
        case .multiChoice:
            return question.choices.map(\.id) + ["validate"]
        case .time:
            return ["time_picker", "time_continue"]
        case .text:
            if question.allowsSkip {
                return ["text_field", "skip", "send"]
            }
            return ["text_field", "send"]
        case .info:
            return ["continue"]
        }
    }
}
