//
//  FaceLeverageIntroStepView.swift
//  useprocess
//
//  Page valeur « ton visage est ton levier » — entre prénom et animation Moss.
//

import SwiftUI

struct FaceLeverageIntroStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var viewModel: OnboardingViewModel
    var onContinue: () -> Void
    var onValidationChanged: ((Bool) -> Void)?

    @State private var showGreeting = false
    @State private var showHeadline = false
    @State private var showSubtext = false
    @State private var showPortrait = false
    @State private var showSectionLabel = false
    @State private var showTestimonial = false
    @State private var showBentoLeft = false
    @State private var showBentoStatus = false
    @State private var showBentoDating = false

    private let accent = Color(red: 0.22, green: 0.47, blue: 0.98)
    private let testimonialAvatars = ["leo", "lucas", "imran"]

    private var userFirstName: String {
        let trimmed = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if OnboardingViewModel.isRealUserFirstName(trimmed) {
            return trimmed
        }
        return OnboardingCopy.t("Toi", en: "You")
    }

    private var portraitAssetName: String {
        switch viewModel.selectedGender {
        case .female:
            return "avaprime"
        default:
            return "imranprime"
        }
    }

    private var contentTopInset: CGFloat {
        OnboardingConstants.headerBackButtonTopPadding
            + OnboardingConstants.backButtonSize
            + 6
    }

    var body: some View {
        ZStack {
            OnboardingTheme.faceLeverageIntroBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                        .padding(.bottom, 24)

                    sectionLabel
                        .padding(.bottom, 12)

                    testimonialCard
                        .padding(.bottom, 16)

                    bentoGrid
                }
                .padding(.horizontal, 24)
                .padding(.top, contentTopInset)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            continueButton
                .opacity(viewModel.isFaceLeverageIntroCompleted ? 1 : 0)
                .allowsHitTesting(viewModel.isFaceLeverageIntroCompleted)
                .accessibilityHidden(!viewModel.isFaceLeverageIntroCompleted)
        }
        .onAppear {
            viewModel.isFaceLeverageIntroCompleted = true
            onValidationChanged?(true)
            startRevealSequence()
        }
        .onDisappear {
            viewModel.isFaceLeverageIntroCompleted = false
            onValidationChanged?(false)
        }
        .processRestoreOpaqueUIKitHostingBackground(
            OnboardingTheme.faceLeverageIntroBackgroundUIColor
        )
    }

    private var continueButton: some View {
        Button {
            guard viewModel.isFaceLeverageIntroCompleted else { return }
            HapticManager.shared.impact(.medium)
            onContinue()
        } label: {
            Text(OnboardingCopy.continueCTA)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OnboardingTheme.filledButtonText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .onboardingPrimaryActionStyle()
        .padding(.horizontal, 34)
        .padding(.top, 8)
        .padding(.bottom, 34)
        .background(OnboardingTheme.faceLeverageIntroBackground.opacity(0.96))
        .accessibilityLabel(OnboardingCopy.continueCTA)
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(userFirstName),")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .staggerReveal(showGreeting, reduceMotion: reduceMotion)

                headlineText
                    .staggerReveal(showHeadline, reduceMotion: reduceMotion)

                Text(OnboardingCopy.t(
                    "Un meilleur visage penche chaque interaction en ta faveur.",
                    en: "Better looks tilt every interaction in your favor."
                ))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
                .staggerReveal(showSubtext, reduceMotion: reduceMotion)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            portrait
        }
    }

    private var headlineText: some View {
        (
            Text(OnboardingCopy.t("Ton visage est ", en: "Your face is "))
                .foregroundStyle(OnboardingTheme.primaryText)
            + Text(OnboardingCopy.t("ton levier.", en: "your leverage."))
                .foregroundStyle(accent)
        )
        .font(.system(size: 30, weight: .bold))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var portrait: some View {
        Image(portraitAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: 108, height: 118)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.06), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 14, y: 8)
            .staggerReveal(showPortrait, reduceMotion: reduceMotion)
            .accessibilityHidden(true)
    }

    // MARK: - Why it matters

    private var sectionLabel: some View {
        Text(OnboardingCopy.t("POURQUOI C’EST IMPORTANT", en: "WHY IT MATTERS"))
            .font(.system(size: 12, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(accent)
            .staggerReveal(showSectionLabel, reduceMotion: reduceMotion)
    }

    private var testimonialCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 0) {
                overlappingAvatars
                Text(OnboardingCopy.t(
                    "120k+ utilisateurs déjà dans le programme",
                    en: "120k+ users already on the program"
                ))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OnboardingTheme.mutedText)
                .padding(.leading, 8)
            }

            quoteText

            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }
                Text(OnboardingCopy.t("4,9 • 2 100 avis", en: "4.9 • 2,100 reviews"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OnboardingTheme.mutedText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(OnboardingTheme.cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.07), radius: 18, y: 8)
        .staggerReveal(showTestimonial, reduceMotion: reduceMotion)
    }

    private var overlappingAvatars: some View {
        HStack(spacing: -10) {
            ForEach(Array(testimonialAvatars.enumerated()), id: \.offset) { index, name in
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(OnboardingTheme.cardBackground, lineWidth: 2)
                    }
                    .zIndex(Double(testimonialAvatars.count - index))
            }
        }
        .accessibilityHidden(true)
    }

    private var quoteText: some View {
        (
            Text("“")
                .foregroundStyle(OnboardingTheme.primaryText)
            + Text(OnboardingCopy.t("Trois semaines plus tard, les gens ", en: "Three weeks in and people "))
                .foregroundStyle(OnboardingTheme.primaryText)
            + Text(OnboardingCopy.t("me traitent différemment.", en: "treat me differently."))
                .foregroundStyle(accent)
            + Text("”")
                .foregroundStyle(OnboardingTheme.primaryText)
        )
        .font(.system(size: 24, weight: .bold))
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Bento

    private var bentoGrid: some View {
        HStack(alignment: .top, spacing: 12) {
            bentoPrimaryCard
                .frame(maxWidth: .infinity)
                .frame(minHeight: 228)
                .staggerReveal(showBentoLeft, reduceMotion: reduceMotion)

            VStack(spacing: 12) {
                bentoSecondaryCard(
                    title: OnboardingCopy.t("Statut", en: "Status"),
                    subtitle: OnboardingCopy.t("Mène la pièce.", en: "Lead the room."),
                    icon: "star",
                    style: .light
                )
                .frame(height: 108)
                .staggerReveal(showBentoStatus, reduceMotion: reduceMotion)

                bentoSecondaryCard(
                    title: OnboardingCopy.t("Dating", en: "Dating"),
                    subtitle: OnboardingCopy.t("Plus de matchs.", en: "More matches."),
                    icon: "heart.fill",
                    style: .accent
                )
                .frame(height: 108)
                .staggerReveal(showBentoDating, reduceMotion: reduceMotion)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var bentoPrimaryCard: some View {
        bentoCardShell(style: .dark) {
            VStack(alignment: .leading, spacing: 0) {
                bentoIcon(systemName: "person.crop.circle", style: .dark)
                Spacer(minLength: 0)
                Text(OnboardingCopy.t("Premières impressions", en: "First impressions"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text(OnboardingCopy.t(
                    "Les gens jugent avant que tu parles.",
                    en: "People judge before you speak."
                ))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.68))
                .padding(.top, 4)
            }
        }
    }

    private enum BentoCardStyle {
        case dark
        case light
        case accent
    }

    private func bentoSecondaryCard(
        title: String,
        subtitle: String,
        icon: String,
        style: BentoCardStyle
    ) -> some View {
        bentoCardShell(style: style) {
            VStack(alignment: .leading, spacing: 0) {
                bentoIcon(systemName: icon, style: style)
                Spacer(minLength: 0)
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(style == .accent ? .white : OnboardingTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        style == .accent
                            ? Color.white.opacity(0.78)
                            : OnboardingTheme.mutedText
                    )
                    .padding(.top, 3)
            }
        }
    }

    private func bentoCardShell<Content: View>(
        style: BentoCardStyle,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(background(for: style))
            }
            .overlay {
                if style == .light {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1)
                }
            }
    }

    private func background(for style: BentoCardStyle) -> Color {
        switch style {
        case .dark:
            return colorScheme == .dark ? Color(white: 0.12) : .black
        case .light:
            return OnboardingTheme.cardBackground
        case .accent:
            return accent
        }
    }

    private func bentoIcon(systemName: String, style: BentoCardStyle) -> some View {
        ZStack {
            Circle()
                .fill(
                    style == .dark
                        ? Color.white.opacity(0.12)
                        : (style == .accent ? Color.white.opacity(0.18) : accent.opacity(0.12))
                )
                .frame(width: 34, height: 34)
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                    style == .dark || style == .accent
                        ? .white
                        : accent
                )
        }
        .padding(.bottom, 12)
    }

    // MARK: - Animation

    private func startRevealSequence() {
        showGreeting = false
        showHeadline = false
        showSubtext = false
        showPortrait = false
        showSectionLabel = false
        showTestimonial = false
        showBentoLeft = false
        showBentoStatus = false
        showBentoDating = false

        if reduceMotion {
            revealAllImmediately()
            return
        }

        reveal(after: 0.05) { showGreeting = true }
        reveal(after: 0.14) { showHeadline = true }
        reveal(after: 0.24) {
            showSubtext = true
            showPortrait = true
        }
        reveal(after: 0.36) { showSectionLabel = true }
        reveal(after: 0.44) { showTestimonial = true }
        reveal(after: 0.58) { showBentoLeft = true }
        reveal(after: 0.68) { showBentoStatus = true }
        reveal(after: 0.78) {
            showBentoDating = true
            markCompleted()
        }
    }

    private func revealAllImmediately() {
        showGreeting = true
        showHeadline = true
        showSubtext = true
        showPortrait = true
        showSectionLabel = true
        showTestimonial = true
        showBentoLeft = true
        showBentoStatus = true
        showBentoDating = true
        markCompleted()
    }

    private func reveal(after delay: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                action()
            }
        }
    }

    private func markCompleted() {
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.12)) {
            viewModel.isFaceLeverageIntroCompleted = true
            onValidationChanged?(true)
            HapticManager.shared.impact(.soft)
        }
    }
}

private extension View {
    func staggerReveal(_ isVisible: Bool, reduceMotion: Bool) -> some View {
        modifier(FaceLeverageStaggerReveal(isVisible: isVisible, reduceMotion: reduceMotion))
    }
}

private struct FaceLeverageStaggerReveal: ViewModifier {
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
