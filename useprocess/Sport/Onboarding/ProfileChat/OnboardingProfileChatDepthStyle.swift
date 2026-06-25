//
//  OnboardingProfileChatDepthStyle.swift
//  useprocess
//

import SwiftUI

enum OnboardingProfileChatDepthStyle {
    static let chatAccentViolet = Color(hex: "aeb2fa")
    static let userAnswerColor = chatAccentViolet
    static let activeFontSize: CGFloat = 21
    static let answerFontSize: CGFloat = 19
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

/// Triangle inversé : bord haut pleine largeur, pointe vers le bas au centre (forme « pique »).
private struct OnboardingChatAmbientPeakShape: Shape {
    var peakDepthRatio: CGFloat = 0.98

    func path(in rect: CGRect) -> Path {
        let peakY = min(rect.maxY, rect.height * peakDepthRatio)
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.midX, y: peakY))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.closeSubpath()
        return path
    }
}

struct OnboardingChatAmbientHeader: View {
    var topInset: CGFloat = 0
    var compact: Bool = false
    var showsLogo: Bool = true

    @State private var isBreathing = false

    private static let ambientViolet = OnboardingProfileChatDepthStyle.chatAccentViolet

    private var baseHeaderHeight: CGFloat {
        compact ? 300 : 380
    }

    private var logoSize: CGFloat {
        compact ? 50 : 64
    }

    private func logoTopOffset(safeTop: CGFloat) -> CGFloat {
        let anchor = topInset > 0 ? topInset : safeTop
        return anchor + (compact ? 6 : 2)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE. d MMM"
        return formatter.string(from: Date()).lowercased()
    }

    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top

            ZStack(alignment: .top) {
                topPurpleSpike(safeTop: safeTop)

                if showsLogo {
                    VStack(spacing: 10) {
                        Image("caochiaicon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: logoSize, height: logoSize)
                            .shadow(color: Self.ambientViolet.opacity(0.14), radius: 12, x: 0, y: 0)
                            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
                            .scaleEffect(isBreathing ? 1.02 : 0.992)
                            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: isBreathing)

                        if compact {
                            Text(formattedDate)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.primary.opacity(0.55))
                        }
                    }
                    .offset(y: logoTopOffset(safeTop: safeTop))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .onAppear {
            isBreathing = true
        }
    }

    private func topPurpleSpike(safeTop: CGFloat) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = baseHeaderHeight + safeTop
            let sideHaloWidth = width * 0.62
            let sideHaloHeight = height * 0.92
            let sideHaloEndY = compact ? 0.78 : 0.84

            ZStack(alignment: .top) {
                OnboardingChatAmbientPeakShape(peakDepthRatio: compact ? 0.96 : 0.98)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Self.ambientViolet.opacity(0.13), location: 0),
                                .init(color: Self.ambientViolet.opacity(0.09), location: 0.22),
                                .init(color: Self.ambientViolet.opacity(0.055), location: 0.48),
                                .init(color: Self.ambientViolet.opacity(0.028), location: 0.68),
                                .init(color: Self.ambientViolet.opacity(0.012), location: 0.84),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: height)
                    .frame(maxWidth: .infinity)
                    .blur(radius: compact ? 22 : 30)

                sideHaloGradient(
                    startPoint: .topLeading,
                    endPoint: UnitPoint(x: 0.5, y: sideHaloEndY),
                    width: sideHaloWidth,
                    height: sideHaloHeight,
                    alignment: .leading
                )

                sideHaloGradient(
                    startPoint: .topTrailing,
                    endPoint: UnitPoint(x: 0.5, y: sideHaloEndY),
                    width: sideHaloWidth,
                    height: sideHaloHeight,
                    alignment: .trailing
                )

                RadialGradient(
                    colors: [
                        Self.ambientViolet.opacity(0.055),
                        Self.ambientViolet.opacity(0.025),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.06),
                    startRadius: 0,
                    endRadius: width * 0.58
                )
                .frame(width: width, height: height * 0.82)
                .frame(maxWidth: .infinity)
                .blur(radius: compact ? 18 : 24)
            }
            .offset(y: -safeTop)
            .compositingGroup()
            .blur(radius: compact ? 7 : 10)
            .mask(ambientFeatherMask)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: baseHeaderHeight, alignment: .top)
    }

    private func sideHaloGradient(
        startPoint: UnitPoint,
        endPoint: UnitPoint,
        width: CGFloat,
        height: CGFloat,
        alignment: Alignment
    ) -> some View {
        LinearGradient(
            stops: [
                .init(color: Self.ambientViolet.opacity(0.09), location: 0),
                .init(color: Self.ambientViolet.opacity(0.045), location: 0.45),
                .init(color: .clear, location: 1)
            ],
            startPoint: startPoint,
            endPoint: endPoint
        )
        .frame(width: width, height: height)
        .frame(maxWidth: .infinity, alignment: alignment)
        .blur(radius: compact ? 20 : 26)
    }

    private var ambientFeatherMask: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.42),
                    .init(color: .black.opacity(0.82), location: 0.66),
                    .init(color: .black.opacity(0.48), location: 0.82),
                    .init(color: .black.opacity(0.18), location: 0.93),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.55), .black, .black.opacity(0.55), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .blendMode(.multiply)
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
