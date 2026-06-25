//
//  OnboardingProgramCreationUI.swift
//  useprocess
//

import SwiftUI

enum OnboardingProgramCreationPalette {
    static let background = Color.black
    static let accent = Color(hex: "aeb2fa")
    static let barTrack = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let subtitle = Color.white.opacity(0.88)
    static let hint = Color.white.opacity(0.42)
}

// MARK: - Background

struct OnboardingProgramCreationBackground: View {
    let progress: Double

    var body: some View {
        ZStack {
            OnboardingProgramCreationPalette.background

            RadialGradient(
                colors: [
                    OnboardingProgramCreationPalette.accent.opacity(0.12),
                    OnboardingProgramCreationPalette.accent.opacity(0.04),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.36),
                startRadius: 20,
                endRadius: 300
            )

            RadialGradient(
                colors: [
                    Color(red: 0.18, green: 0.14, blue: 0.32).opacity(0.28),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.58),
                startRadius: 0,
                endRadius: 240
            )
            .opacity(0.25 + progress * 0.2)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Hero percentage

struct OnboardingProgramCreationHeroPercentage: View {
    let value: Int

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: -5) {
            Text("\(value)")
                .font(.system(size: 78, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.92),
                            Color(white: 0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .contentTransition(.numericText(countsDown: false))
                .animation(.snappy(duration: 0.26), value: value)

            Text("%")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .baselineOffset(6)
        }
        .monospacedDigit()
    }
}

// MARK: - Badge (assets Reward/)

struct OnboardingProgramCreationBadge: View {
    enum Style: Equatable {
        case scienceApproved
        case programsGenerated
        case download
    }

    let style: Style

    private var assetName: String {
        switch style {
        case .scienceApproved:
            return "rewardScience"
        case .programsGenerated:
            return "rewardProgram"
        case .download:
            return "rewardDL"
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 336)
            .frame(height: 106)
            .accessibilityHidden(true)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}

// MARK: - Progress bars

struct OnboardingProgramCreationProgressBars: View {
    let labels: [String]
    let progresses: [Double]
    let showsSecondBar: Bool

    private let barHeight: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            barRow(label: labels[0], progress: progresses[safe: 0] ?? 0)

            if showsSecondBar, labels.count > 1 {
                barRow(label: labels[1], progress: progresses[safe: 1] ?? 0)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.88), value: showsSecondBar)
        .animation(.easeInOut(duration: 0.35), value: progresses)
    }

    private func barRow(label: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OnboardingProgramCreationPalette.subtitle)

            GeometryReader { geometry in
                let width = geometry.size.width
                let clamped = min(max(progress, 0), 1)
                let fillWidth = max(barHeight, width * clamped)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(OnboardingProgramCreationPalette.barTrack)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    OnboardingProgramCreationPalette.accent,
                                    OnboardingProgramCreationPalette.accent.opacity(0.88),
                                    Color(red: 0.68, green: 0.52, blue: 0.98)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: barHeight)
                        .shadow(color: OnboardingProgramCreationPalette.accent.opacity(0.28), radius: 6, x: 0, y: 0)
                }
            }
            .frame(height: barHeight)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
