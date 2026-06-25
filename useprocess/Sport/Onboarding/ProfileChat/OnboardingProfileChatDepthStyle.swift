//
//  OnboardingProfileChatDepthStyle.swift
//  useprocess
//

import SwiftUI

enum OnboardingProfileChatDepthStyle {
    static let userAnswerColor = Color(red: 0.58, green: 0.78, blue: 0.66)
    static let activeFontSize: CGFloat = 21
    static let answerFontSize: CGFloat = 18
    static let messageSpacing: CGFloat = 18
    static let maxVisibleMessages = 5
    static let historySpring = Animation.spring(response: 0.56, dampingFraction: 0.88)
    static let scrollableChoiceThreshold = 5

    static func shouldScrollAnswers(choiceCount: Int) -> Bool {
        choiceCount >= scrollableChoiceThreshold
    }

    static func answersScrollMaxHeight(
        screenHeight: CGFloat,
        contentTopPadding: CGFloat,
        historySlotHeight: CGFloat,
        slotSpacing: CGFloat,
        bottomPadding: CGFloat,
        activeMessageHeight: CGFloat = 96
    ) -> CGFloat {
        let reserved = contentTopPadding + historySlotHeight + slotSpacing + activeMessageHeight + bottomPadding + 24
        return max(180, screenHeight - reserved)
    }

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
                opacity: 0.58,
                blur: 1.1,
                scale: 0.972,
                fontSize: 20,
                color: OnboardingTheme.mutedText,
                isHidden: false
            )
        case 2:
            return .init(
                opacity: 0.38,
                blur: 2.4,
                scale: 0.948,
                fontSize: 19,
                color: OnboardingTheme.mutedText.opacity(0.9),
                isHidden: false
            )
        case 3:
            return .init(
                opacity: 0.22,
                blur: 4.2,
                scale: 0.928,
                fontSize: 18,
                color: OnboardingTheme.mutedText.opacity(0.82),
                isHidden: false
            )
        default:
            return .init(
                opacity: 0.11,
                blur: 6,
                scale: 0.91,
                fontSize: 17,
                color: OnboardingTheme.mutedText.opacity(0.72),
                isHidden: false
            )
        }
    }
}

struct OnboardingChatAmbientHeader: View {
    var topInset: CGFloat = 0
    var compact: Bool = false

    @State private var isBreathing = false
    @State private var haloShift: CGFloat = -14

    private var headerHeight: CGFloat {
        compact ? 176 : 318
    }

    private var logoSize: CGFloat {
        compact ? 72 : 104
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.44, green: 0.68, blue: 0.57).opacity(0.72), location: 0),
                    .init(color: Color(red: 0.24, green: 0.42, blue: 0.34).opacity(0.42), location: 0.26),
                    .init(color: .black.opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: headerHeight)
            .overlay(alignment: .top) {
                RadialGradient(
                    colors: [
                        Color(red: 0.72, green: 0.93, blue: 0.78).opacity(0.34),
                        Color(red: 0.40, green: 0.72, blue: 0.58).opacity(0.18),
                        .clear
                    ],
                    center: .top,
                    startRadius: 12,
                    endRadius: compact ? 170 : 260
                )
                .frame(height: headerHeight)
                .offset(y: haloShift)
                .blur(radius: compact ? 20 : 34)
            }
            .mask(
                LinearGradient(
                    colors: [.black, .black.opacity(0.86), .black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Image("caochiaicon")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .shadow(color: Color(red: 0.64, green: 0.88, blue: 0.72).opacity(0.26), radius: 26, x: 0, y: 0)
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
                .scaleEffect(isBreathing ? 1.035 : 0.985)
                .offset(y: topInset + (compact ? 44 : 116))
                .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: isBreathing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .onAppear {
            isBreathing = true
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                haloShift = 8
            }
        }
    }
}

struct OnboardingChatScrollableAnswerStack<Content: View>: View {
    let choiceCount: Int
    let maxHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if OnboardingProfileChatDepthStyle.shouldScrollAnswers(choiceCount: choiceCount) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
            }
            .frame(maxHeight: maxHeight)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
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
