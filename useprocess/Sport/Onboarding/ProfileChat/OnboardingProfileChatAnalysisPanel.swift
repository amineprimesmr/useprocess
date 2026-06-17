//
//  OnboardingProfileChatAnalysisPanel.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatAnalysisPanel: View {
    let phaseLabel: String
    let displayedPercentage: Int
    let progress: Double
    let isVisible: Bool

    private let barHeight: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer(minLength: 0)
                Text("\(displayedPercentage)%")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: displayedPercentage)
            }

            Text(phaseLabel)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OnboardingTheme.narrativeText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: phaseLabel)

            GeometryReader { geometry in
                let width = geometry.size.width
                let fillWidth = width * min(max(progress, 0), 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(OnboardingTheme.subtleFill)
                        .overlay(
                            Capsule()
                                .strokeBorder(OnboardingTheme.softBorder, lineWidth: 1)
                        )

                    Capsule()
                        .fill(OnboardingTheme.analysisProgressFillGradient)
                        .frame(width: max(barHeight, fillWidth), height: barHeight)
                        .clipShape(Capsule())
                }
            }
            .frame(height: barHeight)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .animation(OnboardingProfileChatAnswerReveal.spring, value: isVisible)
    }
}
