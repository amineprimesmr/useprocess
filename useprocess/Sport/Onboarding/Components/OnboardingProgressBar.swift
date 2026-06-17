//
//  OnboardingProgressBar.swift
//  useprocess
//

import SwiftUI

struct OnboardingProgressBar: View {
    /// Progression normalisée entre 0 et 1.
    let progress: Double
    var height: CGFloat = 4
    var cornerRadius: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(OnboardingTheme.progressTrack)

                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(OnboardingTheme.progressFill)
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: clampedProgress)
    }

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }
}
