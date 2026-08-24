//
//  OnboardingProfileChatAnswerReveal.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatAnswerRevealModifier: ViewModifier {
    let isRevealed: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 12)
            .scaleEffect(isRevealed ? 1 : 0.96, anchor: .topLeading)
            .allowsHitTesting(isRevealed)
            .accessibilityHidden(!isRevealed)
    }
}

extension View {
    func onboardingChatAnswerReveal(isRevealed: Bool) -> some View {
        modifier(OnboardingProfileChatAnswerRevealModifier(isRevealed: isRevealed))
    }
}
