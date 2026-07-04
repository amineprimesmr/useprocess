//
//  OnboardingProfileChatPlanCreationPanel.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatPlanCreationPanel: View {
    let progress: Double
    let displayedPercentage: Int
    let isVisible: Bool

    private let barHeight: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Création de ton plan personnalisé…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(OnboardingTheme.bodyText)

                Spacer(minLength: 0)

                Text("\(displayedPercentage)%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(OnboardingTheme.mutedText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            GeometryReader { geometry in
                let clamped = min(max(progress, 0), 1)
                let fillWidth = max(barHeight, geometry.size.width * clamped)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(OnboardingTheme.analysisProgressTrack)

                    Capsule(style: .continuous)
                        .fill(OnboardingTheme.analysisProgressFillGradient)
                        .frame(width: fillWidth, height: barHeight)
                }
            }
            .frame(height: barHeight)
        }
        .padding(.top, 6)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: isVisible)
        .animation(.easeInOut(duration: 0.28), value: progress)
    }
}
