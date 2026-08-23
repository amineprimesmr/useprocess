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
    @State private var isContinuing = false

    private let accentBlue = Color(red: 0.0, green: 0.478, blue: 1.0)

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                header
                comparisonCard
                    .frame(maxWidth: .infinity)
                    .frame(height: comparisonHeight(in: geometry.size))
                    .padding(.top, 32)
                testimonialBlock
                    .padding(.top, 12)
                statsRow
                    .padding(.top, 60)
                Spacer(minLength: 0)
            }
            .padding(.top, OnboardingConstants.backOnlyContentTopInset)
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OnboardingTheme.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            continueButton
                .opacity(showContinueButton ? 1 : 0)
                .offset(y: showContinueButton ? 0 : 16)
                .allowsHitTesting(showContinueButton)
                .accessibilityHidden(!showContinueButton)
        }
        .onAppear {
            isContinuing = false
            showContinueButton = true
            startRevealSequence()
        }
        .onDisappear {
            isContinuing = false
        }
    }

    private func comparisonHeight(in size: CGSize) -> CGFloat {
        let reservedChrome = OnboardingConstants.backOnlyContentTopInset + 284
        let available = max(size.height - reservedChrome, 148)
        let fromWidth = (size.width - 48) * 1.06
        return min(available, fromWidth)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            (
                Text(OnboardingCopy.t("Le ", en: ""))
                    .foregroundStyle(OnboardingTheme.primaryText)
                + Text(OnboardingCopy.t("debloat", en: "Debloat"))
                    .foregroundStyle(accentBlue)
                + Text(OnboardingCopy.t(", ça se voit", en: " you can see"))
                    .foregroundStyle(OnboardingTheme.primaryText)
            )
            .font(.system(size: 24, weight: .bold))
            .fixedSize(horizontal: false, vertical: true)
            .staggerReveal(showHeadline, reduceMotion: reduceMotion)

            Text(OnboardingCopy.t(
                "Manny · 19 · fais glisser pour comparer",
                en: "Manny · 19 · drag to compare"
            ))
            .font(.system(size: 13, weight: .regular))
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
            afterBadgeTitle: OnboardingCopy.t("Semaine 6", en: "Week 6"),
            desaturateBefore: true
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 16, y: 8)
        .staggerReveal(showComparison, reduceMotion: reduceMotion)
    }

    private var testimonialBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(OnboardingCopy.t(
                "« Mâchoire plus nette et peau plus claire dès la semaine 4 — juste en restant régulier. »",
                en: "“Sharper jawline and clearer skin by week 4 — just from staying consistent.”"
            ))
            .font(.system(size: 14, weight: .regular))
            .italic()
            .foregroundStyle(OnboardingTheme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(3)

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
                value: "+10k",
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
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(valueColor(for: style))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
            guard !isContinuing else { return }
            isContinuing = true
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
        .disabled(isContinuing)
        .padding(.horizontal, 34)
        .padding(.top, 8)
        .padding(.bottom, 34)
        .contentShape(Rectangle())
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
        reveal(after: 0.74) { showStatResults = true }
        showContinueButton = true
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
