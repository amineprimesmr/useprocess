//
//  OnboardingProfileChatProfileSummarySection.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatProfileSummarySection: View {
    @Environment(\.colorScheme) private var colorScheme

    let sections: [OnboardingProfileSummarySection]
    let isSubmitting: Bool
    let isRevealed: Bool
    let onContinue: () -> Void

    private let readyGreen = Color(red: 0.18, green: 0.72, blue: 0.44)
    private let cardShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            summaryCard

            Button {
                guard !isSubmitting else { return }
                HapticManager.shared.impact(.medium)
                onContinue()
            } label: {
                Text(OnboardingCopy.t("Emmène-moi →", en: "Take me there →"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .onboardingPrimaryActionStyle()
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.55 : 1)
        }
        .onboardingChatAnswerReveal(isRevealed: isRevealed)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            HStack(spacing: 8) {
                Circle()
                    .fill(readyGreen)
                    .frame(width: 8, height: 8)
                Text(OnboardingCopy.t("DASHBOARD PRÊT", en: "DASHBOARD READY"))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(readyGreen)
            }

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

            VStack(alignment: .leading, spacing: Theme.Space.m) {
                ForEach(sections) { section in
                    summarySection(section)
                }
            }
        }
        .padding(20)
        .background(
            cardShape.fill(OnboardingTheme.cardBackground)
        )
        .overlay {
            cardShape.strokeBorder(
                Color.black.opacity(colorScheme == .dark ? 0.12 : 0.06),
                lineWidth: 1
            )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
            radius: 18,
            y: 8
        )
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(OnboardingTheme.screenBackground.opacity(colorScheme == .dark ? 0.55 : 0.92))
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.black.opacity(colorScheme == .dark ? 0.14 : 0.08), lineWidth: 1)
        }
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
