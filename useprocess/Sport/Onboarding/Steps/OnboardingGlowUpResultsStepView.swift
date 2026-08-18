//
//  OnboardingGlowUpResultsStepView.swift
//  Process
//
//  Aperçu glow-up Manny (avant / après) — affiché après « C’est parti » dans le chat Moss.
//

import SwiftUI

struct OnboardingGlowUpResultsStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onContinue: () -> Void

    @State private var showHeadline = false
    @State private var showSubtext = false
    @State private var showComparison = false
    @State private var showTestimonial = false
    @State private var showStatUsers = false
    @State private var showStatRating = false
    @State private var showStatResults = false
    @State private var showContinueButton = false

    private let accentBlue = Color(red: 0.0, green: 0.478, blue: 1.0)

    var body: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OnboardingTheme.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            continueButton
                .opacity(showContinueButton ? 1 : 0.42)
                .allowsHitTesting(showContinueButton)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .onAppear {
            showContinueButton = false
            startRevealSequence()
        }
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
            .staggerReveal(showHeadline, reduceMotion: reduceMotion)

            Text(OnboardingCopy.t(
                "Manny · 19 · fais glisser pour comparer",
                en: "Manny · 19 · drag to compare"
            ))
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(OnboardingTheme.mutedText)
            .staggerReveal(showSubtext, reduceMotion: reduceMotion)
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
        .staggerReveal(showComparison, reduceMotion: reduceMotion)
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
        .staggerReveal(showTestimonial, reduceMotion: reduceMotion)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(
                label: OnboardingCopy.t("UTILISATEURS", en: "USERS"),
                value: "120k+",
                style: .dark
            )
            .staggerReveal(showStatUsers, reduceMotion: reduceMotion)

            statCard(
                label: OnboardingCopy.t("NOTE", en: "RATING"),
                value: "4.8",
                style: .light
            )
            .staggerReveal(showStatRating, reduceMotion: reduceMotion)

            statCard(
                label: OnboardingCopy.t("RÉSULTATS", en: "AVG RESULTS"),
                value: OnboardingCopy.t("6 sem.", en: "6 wks"),
                style: .blue
            )
            .staggerReveal(showStatResults, reduceMotion: reduceMotion)
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
        .background(OnboardingTheme.screenBackground.opacity(0.96))
        .accessibilityLabel(OnboardingCopy.continueCTAUpper)
    }

    // MARK: - Animation

    private func startRevealSequence() {
        showHeadline = false
        showSubtext = false
        showComparison = false
        showTestimonial = false
        showStatUsers = false
        showStatRating = false
        showStatResults = false
        showContinueButton = false

        if reduceMotion {
            revealAllImmediately()
            return
        }

        reveal(after: 0.05) { showHeadline = true }
        reveal(after: 0.14) { showSubtext = true }
        reveal(after: 0.26) { showComparison = true }
        reveal(after: 0.40) { showTestimonial = true }
        reveal(after: 0.54) { showStatUsers = true }
        reveal(after: 0.64) { showStatRating = true }
        reveal(after: 0.74) {
            showStatResults = true
            revealContinueButton()
        }
    }

    private func revealAllImmediately() {
        showHeadline = true
        showSubtext = true
        showComparison = true
        showTestimonial = true
        showStatUsers = true
        showStatRating = true
        showStatResults = true
        showContinueButton = true
    }

    private func reveal(after delay: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                action()
            }
        }
    }

    private func revealContinueButton() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
                showContinueButton = true
            }
            HapticManager.shared.impact(.soft)
        }
    }
}

private extension View {
    func staggerReveal(_ isVisible: Bool, reduceMotion: Bool) -> some View {
        modifier(GlowUpResultsStaggerReveal(isVisible: isVisible, reduceMotion: reduceMotion))
    }
}

private struct GlowUpResultsStaggerReveal: ViewModifier {
    let isVisible: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.97, anchor: .topLeading)
            .allowsHitTesting(isVisible || reduceMotion)
    }
}
