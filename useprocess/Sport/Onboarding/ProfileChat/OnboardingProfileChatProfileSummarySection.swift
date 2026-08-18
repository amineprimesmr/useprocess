//
//  OnboardingProfileChatProfileSummarySection.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatProfileSummarySection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let sections: [OnboardingProfileSummarySection]
    let isRevealed: Bool
    var isContinueEnabled: Bool = true
    var onContinue: () -> Void = {}

    private let readyGreen = Color(red: 0.18, green: 0.72, blue: 0.44)
    private let cardRadius: CGFloat = 24
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            Button(action: handleContinue) {
                cardContent
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardShape.fill(OnboardingTheme.cardBackground))
                    .overlay {
                        cardShape.strokeBorder(
                            Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06),
                            lineWidth: 1
                        )
                    }
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.07),
                        radius: 16,
                        y: 6
                    )
                    .contentShape(cardShape)
            }
            .buttonStyle(.processPlain)
            .accessibilityLabel(
                OnboardingCopy.t("Emmène-moi", en: "Take me there")
            )

            ProfileSummaryTravelingBeam(cornerRadius: cardRadius, reduceMotion: reduceMotion)
                .allowsHitTesting(false)
        }
        .onboardingChatAnswerReveal(isRevealed: isRevealed)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            statusPill

            VStack(alignment: .leading, spacing: 6) {
                Text(OnboardingCopy.t("Construit autour de toi", en: "Built around you"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                Text(OnboardingCopy.t(
                    "Tout ce que tu m’as dit, c’est verrouillé.",
                    en: "Everything you told me, locked in."
                ))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingTheme.mutedText)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(sections) { section in
                    summarySection(section)
                }
            }

            continueRow
                .padding(.top, 6)
        }
    }

    private var statusPill: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(readyGreen)
                .frame(width: 7, height: 7)
            Text(OnboardingCopy.t("DASHBOARD PRÊT", en: "DASHBOARD READY"))
                .font(.system(size: 11, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(readyGreen)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(readyGreen.opacity(colorScheme == .dark ? 0.16 : 0.10))
        )
    }

    private var continueRow: some View {
        Text(OnboardingCopy.t("Emmène-moi →", en: "Take me there →"))
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                OnboardingTheme.filledButtonBackground(for: colorScheme),
                in: Capsule(style: .continuous)
            )
            .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
    }

    private func summarySection(_ section: OnboardingProfileSummarySection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(OnboardingTheme.mutedText)

            FlowLayout(spacing: 8) {
                ForEach(section.chips) { chip in
                    summaryChip(chip)
                }
            }
        }
    }

    private func summaryChip(_ chip: OnboardingProfileSummaryChip) -> some View {
        HStack(spacing: 6) {
            Text(chip.emoji)
            Text(chip.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(OnboardingTheme.screenBackground.opacity(colorScheme == .dark ? 0.48 : 0.88))
        )
    }

    private func handleContinue() {
        guard isContinueEnabled else { return }
        HapticManager.shared.impact(.medium)
        onContinue()
    }
}

/// Arc lumineux court qui circule — le reste du contour reste invisible.
private struct ProfileSummaryTravelingBeam: View {
    var cornerRadius: CGFloat
    var reduceMotion: Bool

    private let lineWidth: CGFloat = 2.2
    private let rotationPeriod: Double = 4.6

    private static let glow = Color(red: 0.38, green: 0.58, blue: 1.0)

    var body: some View {
        TimelineView(.periodic(from: .now, by: reduceMotion ? 120 : 1.0 / 30.0)) { timeline in
            let angle: Angle = {
                guard !reduceMotion else { return .degrees(48) }
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let progress = elapsed.truncatingRemainder(dividingBy: rotationPeriod) / rotationPeriod
                return .degrees(progress * 360)
            }()

            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            shape
                .strokeBorder(beamGradient(angle: angle), lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
    }

    private func beamGradient(angle: Angle) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.44),
                .init(color: Self.glow.opacity(0.28), location: 0.47),
                .init(color: .white.opacity(0.88), location: 0.495),
                .init(color: .white, location: 0.505),
                .init(color: Self.glow, location: 0.52),
                .init(color: Self.glow.opacity(0.28), location: 0.55),
                .init(color: .clear, location: 0.58),
                .init(color: .clear, location: 1.0)
            ]),
            center: .center,
            angle: angle
        )
    }
}

/// Simple flow layout for summary chips (reuse Moss spacing conventions).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
