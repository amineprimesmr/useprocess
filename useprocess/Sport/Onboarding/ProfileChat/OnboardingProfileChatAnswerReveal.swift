//
//  OnboardingProfileChatAnswerReveal.swift
//  useprocess
//

import SwiftUI

enum OnboardingProfileChatAnswerReveal {
    static let staggerDelay: UInt64 = 58_000_000
    static let initialDelay: UInt64 = 140_000_000
    static let spring = Animation.spring(response: 0.44, dampingFraction: 0.86)

    static func orderedIDs(for question: OnboardingProfileChatQuestion) -> [String] {
        switch question.kind {
        case .infoContinue:
            return ["continue"]
        case .yesNo:
            return ["yes", "no"]
        case .singleChoice where question.id == "sport_pick":
            return OnboardingSportCatalog.featuredChoices.map(\.id) + ["sport_search"]
        case .singleChoice:
            return question.choices.map(\.id)
        case .multiChoice:
            return question.choices.map(\.id) + ["validate"]
        case .faceScanOffer:
            return ["scan", "later_hint"]
        case .analysisProgress:
            return ["analysis_progress", "analysis_detail"]
        }
    }
}

struct OnboardingProfileChatAnswerRevealModifier: ViewModifier {
    let isRevealed: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 12)
            .scaleEffect(isRevealed ? 1 : 0.96, anchor: .topLeading)
            .allowsHitTesting(isRevealed)
    }
}

extension View {
    func onboardingChatAnswerReveal(isRevealed: Bool) -> some View {
        modifier(OnboardingProfileChatAnswerRevealModifier(isRevealed: isRevealed))
    }
}
