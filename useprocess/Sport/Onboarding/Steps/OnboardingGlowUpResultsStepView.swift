//
//  OnboardingGlowUpResultsStepView.swift
//  Process
//
//  Aperçu glow-up Manny (avant / après) — affiché après « C’est parti » dans le chat Moss.
//

import SwiftUI

struct OnboardingGlowUpResultsStepView: View {
    @Environment(\.colorScheme) private var colorScheme

    let onContinue: () -> Void

    private let accentBlue = Color(red: 0.0, green: 0.478, blue: 1.0)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    comparisonCard
                    testimonialBlock
                    statsRow
                }
                .padding(.top, OnboardingConstants.mossChatContentTopInset)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            continueButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OnboardingTheme.screenBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            (
                Text(OnboardingCopy.t("De vrais résultats ", en: "Real glow-up "))
                    .foregroundStyle(OnboardingTheme.primaryText)
                + Text(OnboardingCopy.t("glow-up", en: "results"))
                    .foregroundStyle(accentBlue)
            )
            .font(.system(size: 30, weight: .bold))
            .fixedSize(horizontal: false, vertical: true)

            Text(OnboardingCopy.t(
                "Manny · 19 · fais glisser pour comparer",
                en: "Manny · 19 · drag to compare"
            ))
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(OnboardingTheme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comparisonCard: some View {
        BeforeAfterComparisonSlider(
            beforeImageName: "mannybloat",
            afterImageName: "mannyprime",
            durationWeeks: 6,
            playsIntroHint: true,
            beforeBadgeTitle: OnboardingCopy.t("Jour 1", en: "Day 1"),
            afterBadgeTitle: OnboardingCopy.t("Sem. 6", en: "Week 6"),
            desaturateBefore: true
        )
        .aspectRatio(0.82, contentMode: .fit)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 16, y: 8)
    }

    private var testimonialBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(OnboardingCopy.t(
                "« Mâchoire plus nette et peau plus claire dès la semaine 4 — juste en restant régulier. »",
                en: "“Sharper jawline and clearer skin by week 4 — just from staying consistent.”"
            ))
            .font(.system(size: 17, weight: .regular))
            .italic()
            .foregroundStyle(OnboardingTheme.primaryText)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(accentBlue)
                        .frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(OnboardingCopy.t(
                    "Utilisateur vérifié · parcours 6 semaines",
                    en: "Verified user · 6 week journey"
                ))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OnboardingTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(
                label: OnboardingCopy.t("UTILISATEURS", en: "USERS"),
                value: "120k+",
                style: .dark
            )
            statCard(
                label: OnboardingCopy.t("NOTE", en: "RATING"),
                value: "4.8",
                style: .light
            )
            statCard(
                label: OnboardingCopy.t("RÉSULTATS", en: "AVG RESULTS"),
                value: OnboardingCopy.t("6 sem.", en: "6 wks"),
                style: .blue
            )
        }
    }

    private enum StatCardStyle {
        case dark
        case light
        case blue
    }

    private func statCard(label: String, value: String, style: StatCardStyle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(labelColor(for: style))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(valueColor(for: style))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundColor(for: style))
        }
        .overlay {
            if style == .light {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(OnboardingTheme.borderStroke, lineWidth: 1)
            }
        }
    }

    private func backgroundColor(for style: StatCardStyle) -> Color {
        switch style {
        case .dark:
            return colorScheme == .dark ? Color.white.opacity(0.12) : .black
        case .light:
            return colorScheme == .dark ? Color.white.opacity(0.08) : .white
        case .blue:
            return accentBlue
        }
    }

    private func labelColor(for style: StatCardStyle) -> Color {
        switch style {
        case .dark:
            return colorScheme == .dark ? OnboardingTheme.mutedText : .white.opacity(0.72)
        case .light:
            return OnboardingTheme.mutedText
        case .blue:
            return .white.opacity(0.82)
        }
    }

    private func valueColor(for style: StatCardStyle) -> Color {
        switch style {
        case .dark, .blue:
            return .white
        case .light:
            return OnboardingTheme.primaryText
        }
    }

    private var continueButton: some View {
        Button {
            HapticManager.shared.impact(.medium)
            onContinue()
        } label: {
            Text(OnboardingCopy.continueCTAUpper)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
        }
        .onboardingPrimaryActionStyle()
        .padding(.horizontal, 34)
        .padding(.top, 8)
        .padding(.bottom, 50)
    }
}
