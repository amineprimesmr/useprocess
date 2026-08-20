//
//  OnboardingProfileChatProfileSummarySection.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatProfileSummarySection: View {
    @Environment(\.colorScheme) private var colorScheme

    let sections: [OnboardingProfileSummarySection]
    let isRevealed: Bool
    var isContinueEnabled: Bool = true
    var onContinue: () -> Void = {}

    private let readyGreen = Color(red: 0.18, green: 0.72, blue: 0.44)
    private let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryContent
                .onboardingChatAnswerReveal(isRevealed: isRevealed)

            continueButton
                .id("profileSummaryCTA")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .processGlassEffect(in: cardShape, interactive: false)
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusPill

            VStack(alignment: .leading, spacing: 6) {
                Text(OnboardingCopy.t("Construit autour de toi", en: "Built around you"))
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                Text(OnboardingCopy.t(
                    "Tout ce que tu m’as dit, c’est verrouillé.",
                    en: "Everything you told me, locked in."
                ))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingTheme.mutedText)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(sections) { section in
                    summarySection(section)
                }
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(readyGreen)
                .frame(width: 8, height: 8)
            Text(OnboardingCopy.t("DASHBOARD PRÊT", en: "DASHBOARD READY"))
                .font(.system(size: 12, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(readyGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(readyGreen.opacity(0.12))
        )
    }

    private var continueButton: some View {
        Button(action: handleContinue) {
            Text(OnboardingCopy.t("Voir mon dashboard", en: "See my dashboard"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Capsule())
        }
        .onboardingPrimaryActionStyle()
        .disabled(!isContinueEnabled)
        .accessibilityLabel(OnboardingCopy.t("Voir mon dashboard", en: "See my dashboard"))
    }

    private func summarySection(_ section: OnboardingProfileSummarySection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(OnboardingTheme.mutedText)

            FlowLayout(spacing: 6) {
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private func handleContinue() {
        guard isContinueEnabled else { return }
        HapticManager.shared.impact(.medium)
        onContinue()
    }
}

/// Simple flow layout for summary chips (reuse Moss spacing conventions).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
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
