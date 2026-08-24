//
//  OnboardingProfileChatDepthStyle.swift
//  useprocess
//

import SwiftUI

enum OnboardingProfileChatDepthStyle {
    static let chatAccentViolet = Color(hex: "aeb2fa")
    static let answerFontSize: CGFloat = 19
    static let scrollableChoiceThreshold = 5

    static func shouldScrollAnswers(choiceCount: Int) -> Bool {
        choiceCount >= scrollableChoiceThreshold
    }
}

struct OnboardingChatScrollableAnswerStack<Content: View>: View {
    let choiceCount: Int
    let maxHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if OnboardingProfileChatDepthStyle.shouldScrollAnswers(choiceCount: choiceCount) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: MossAnswerChipMetrics.stackSpacing) {
                    content()
                }
            }
            .frame(maxHeight: maxHeight)
        } else {
            VStack(alignment: .leading, spacing: MossAnswerChipMetrics.stackSpacing) {
                content()
            }
        }
    }
}
