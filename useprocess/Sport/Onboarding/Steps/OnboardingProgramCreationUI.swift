//
//  OnboardingProgramCreationUI.swift
//  useprocess
//

import SwiftUI

enum OnboardingProgramCreationPalette {
    static var background: Color { OnboardingTheme.screenBackground }
    static let accent = Color(hex: "aeb2fa")
    static var barTrack: Color { OnboardingTheme.analysisProgressTrack }
    static var subtitle: Color { OnboardingTheme.primaryText }
    static var hint: Color { OnboardingTheme.mutedText }
}

// MARK: - Background

struct OnboardingProgramCreationBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double

    var body: some View {
        ZStack {
            OnboardingProgramCreationPalette.background

            RadialGradient(
                colors: [
                    OnboardingProgramCreationPalette.accent.opacity(colorScheme == .dark ? 0.12 : 0.18),
                    OnboardingProgramCreationPalette.accent.opacity(colorScheme == .dark ? 0.04 : 0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.36),
                startRadius: 20,
                endRadius: 300
            )

            RadialGradient(
                colors: [
                    Color(red: 0.18, green: 0.14, blue: 0.32).opacity(colorScheme == .dark ? 0.28 : 0.12),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.58),
                startRadius: 0,
                endRadius: 240
            )
            .opacity((colorScheme == .dark ? 0.25 : 0.14) + progress * 0.2)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Hero percentage

struct OnboardingProgramCreationHeroPercentage: View {
    @Environment(\.colorScheme) private var colorScheme

    let value: Int

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: -5) {
            Text("\(value)")
                .font(.system(size: 78, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: percentageGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .contentTransition(.numericText(countsDown: false))
                .animation(.snappy(duration: 0.26), value: value)

            Text("%")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(percentSymbolColor)
                .baselineOffset(6)
        }
        .monospacedDigit()
    }

    private var percentageGradient: [Color] {
        if colorScheme == .dark {
            return [Color.white, Color.white.opacity(0.92), Color(white: 0.58)]
        }
        return [
            Color.primary,
            Color.primary.opacity(0.9),
            Color.primary.opacity(0.62)
        ]
    }

    private var percentSymbolColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.88)
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

    private let barHeight: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                barRow(label: label, progress: progresses[safe: index] ?? 0)
            }
        }
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
                        .fill(OnboardingTheme.analysisProgressFillGradient)
                        .frame(width: fillWidth, height: barHeight)
                        .shadow(
                            color: OnboardingProgramCreationPalette.accent.opacity(0.22),
                            radius: 6,
                            x: 0,
                            y: 0
                        )
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
