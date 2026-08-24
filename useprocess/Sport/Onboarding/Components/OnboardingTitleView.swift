//
//  OnboardingTitleView.swift
//  Process
//
//  Composant standardisé pour les titres d'onboarding
//

import SwiftUI

struct OnboardingTitleView: View {
    let lines: [String]
    let opacity: Double

    init(_ title: String, opacity: Double = 1.0) {
        self.lines = [title]
        self.opacity = opacity
    }

    init(_ line1: String, _ line2: String, opacity: Double = 1.0) {
        self.lines = [line1, line2]
        self.opacity = opacity
    }

    private var displayLines: [String] {
        OnboardingCopy.titleLines(from: lines)
    }

    var body: some View {
        Text(displayLines.joined(separator: " "))
            .font(.system(size: 26, weight: .bold, design: .default))
            .foregroundStyle(OnboardingTheme.primaryText)
            .shadow(color: OnboardingTheme.titleShadow, radius: 2, x: 1, y: 1)
            .opacity(opacity)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: false)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 40)
            .padding(.trailing, 20)
    }

    /// Overlay titre fixe — laisse passer les taps (toggle, champs, boutons).
    func onboardingTitleOverlay() -> some View {
        VStack {
            self
                .padding(.top, OnboardingConstants.titleTopPadding)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
