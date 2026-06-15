//
//  OnboardingProgressBar.swift
//  useprocess
//

import SwiftUI

struct OnboardingProgressBar: View {
    /// Progression normalisée entre 0 et 1.
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.18))

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .frame(height: 4)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: clampedProgress)
    }

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }
}
