//
//  OnboardingProfileChatDepthStyle.swift
//  useprocess
//

import SwiftUI

enum OnboardingProfileChatDepthStyle {
    static let userAnswerColor = Color(red: 0.58, green: 0.78, blue: 0.66)
    static let activeFontSize: CGFloat = 21
    static let answerFontSize: CGFloat = 18
    static let messageSpacing: CGFloat = 20
    static let maxVisibleMessages = 5
    static let historySpring = Animation.spring(response: 0.56, dampingFraction: 0.88)

    struct Appearance: Equatable {
        let opacity: Double
        let blur: CGFloat
        let scale: CGFloat
        let fontSize: CGFloat
        let color: Color
        let isHidden: Bool
    }

    static func appearance(
        distanceFromActive: Int,
        role: OnboardingProfileChatRole
    ) -> Appearance {
        if distanceFromActive >= maxVisibleMessages {
            return .init(opacity: 0, blur: 0, scale: 1, fontSize: activeFontSize, color: .clear, isHidden: true)
        }

        switch role {
        case .user:
            return userAppearance(distance: distanceFromActive)
        case .assistant:
            return assistantAppearance(distance: distanceFromActive)
        }
    }

    private static func userAppearance(distance: Int) -> Appearance {
        switch distance {
        case 0:
            return .init(opacity: 0.94, blur: 0, scale: 1, fontSize: activeFontSize, color: userAnswerColor, isHidden: false)
        case 1:
            return .init(opacity: 0.78, blur: 0.25, scale: 0.98, fontSize: 20, color: userAnswerColor.opacity(0.92), isHidden: false)
        case 2:
            return .init(opacity: 0.52, blur: 1.2, scale: 0.96, fontSize: 19, color: userAnswerColor.opacity(0.72), isHidden: false)
        case 3:
            return .init(opacity: 0.32, blur: 2.2, scale: 0.94, fontSize: 18, color: userAnswerColor.opacity(0.52), isHidden: false)
        default:
            return .init(opacity: 0.18, blur: 3.5, scale: 0.92, fontSize: 17, color: userAnswerColor.opacity(0.38), isHidden: false)
        }
    }

    private static func assistantAppearance(distance: Int) -> Appearance {
        switch distance {
        case 0:
            return .init(
                opacity: 1,
                blur: 0,
                scale: 1,
                fontSize: activeFontSize,
                color: OnboardingTheme.primaryText,
                isHidden: false
            )
        case 1:
            return .init(
                opacity: 0.62,
                blur: 0.6,
                scale: 0.972,
                fontSize: 20,
                color: OnboardingTheme.mutedText,
                isHidden: false
            )
        case 2:
            return .init(
                opacity: 0.44,
                blur: 1.6,
                scale: 0.948,
                fontSize: 19,
                color: OnboardingTheme.mutedText.opacity(0.9),
                isHidden: false
            )
        case 3:
            return .init(
                opacity: 0.28,
                blur: 2.8,
                scale: 0.928,
                fontSize: 18,
                color: OnboardingTheme.mutedText.opacity(0.82),
                isHidden: false
            )
        default:
            return .init(
                opacity: 0.16,
                blur: 4,
                scale: 0.91,
                fontSize: 17,
                color: OnboardingTheme.mutedText.opacity(0.72),
                isHidden: false
            )
        }
    }
}

struct ActiveMessageTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}
