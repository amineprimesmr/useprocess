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
        .ios26SafeAnimation(.spring(response: 0.34, dampingFraction: 0.88), value: clampedProgress)
    }

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }
}

struct OnboardingSegmentedProgressBar: View {
    let segmentCount: Int
    let completedSegments: Int
    let activeSegmentProgress: Double
    var height: CGFloat = 5
    var cornerRadius: CGFloat = 3
    var spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<max(segmentCount, 1), id: \.self) { index in
                OnboardingProgressBar(
                    progress: progress(for: index),
                    height: height,
                    cornerRadius: cornerRadius
                )
            }
        }
    }

    private func progress(for index: Int) -> Double {
        if index < completedSegments { return 1 }
        if index == completedSegments { return min(max(activeSegmentProgress, 0), 1) }
        return 0
    }
}
