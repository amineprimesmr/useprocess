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
    @State private var showBentoPresence = false
    @State private var showBentoAttraction = false

    private let accent = Color(red: 0.22, green: 0.47, blue: 0.98)
    private let testimonialAvatars = ["leo", "lucas", "imran"]
    private let cardShape = RoundedRectangle(cornerRadius: 24, style: .continuous)
    private let bentoShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

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
            return "mannyprime-leverage"
        }
    }

    private var contentTopInset: CGFloat {
        OnboardingConstants.headerBackButtonTopPadding
            + OnboardingConstants.backButtonSize
            + 24
    }

    var body: some View {
        ZStack {
            OnboardingTheme.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                        .padding(.bottom, 64)

                    sectionLabel
                        .padding(.bottom, 14)

                    testimonialCard
                        .padding(.bottom, 14)

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
            OnboardingTheme.hostingBackgroundUIColor
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
        .background(OnboardingTheme.screenBackground.opacity(0.96))
        .accessibilityLabel(OnboardingCopy.continueCTA)
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(userFirstName),")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
                    .staggerReveal(showGreeting, reduceMotion: reduceMotion)

                headlineText
                    .staggerReveal(showHeadline, reduceMotion: reduceMotion)

                Text(OnboardingCopy.t(
                    "Un visage plus net, et on te prend plus au sérieux. Avant même que tu parles.",
                    en: "A sharper face, and people take you more seriously — before you even speak."
                ))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(OnboardingTheme.bodyText)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
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
            .frame(width: 112, height: 124, alignment: .top)
            .offset(y: -22)
            .frame(width: 112, height: 124)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.55), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.10), radius: 16, y: 8)
            .staggerReveal(showPortrait, reduceMotion: reduceMotion)
            .accessibilityHidden(true)
    }

    // MARK: - Why it matters

    private var sectionLabel: some View {
        Text(OnboardingCopy.t("CE QUE ÇA CHANGE", en: "WHAT CHANGES"))
            .font(.system(size: 12, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(accent)
            .staggerReveal(showSectionLabel, reduceMotion: reduceMotion)
    }

    private var testimonialCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 0) {
                overlappingAvatars
                Text(OnboardingCopy.t(
                    "+10k utilisateurs",
                    en: "+10k users"
                ))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OnboardingTheme.mutedText)
                .padding(.leading, 10)
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
        .processGlassEffect(in: cardShape, interactive: false)
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
                            .strokeBorder(
                                OnboardingTheme.screenBackground,
                                lineWidth: 2
                            )
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
            + Text(OnboardingCopy.t("En trois semaines, les gens ", en: "Three weeks in, people "))
                .foregroundStyle(OnboardingTheme.primaryText)
            + Text(OnboardingCopy.t("me regardent autrement.", en: "look at me differently."))
                .foregroundStyle(accent)
            + Text("”")
                .foregroundStyle(OnboardingTheme.primaryText)
        )
        .font(.system(size: 22, weight: .bold))
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Bento

    private var bentoGrid: some View {
        HStack(alignment: .top, spacing: 14) {
            bentoPrimaryCard
                .frame(maxWidth: .infinity)
                .frame(minHeight: 236)
                .staggerReveal(showBentoLeft, reduceMotion: reduceMotion)

            VStack(spacing: 18) {
                bentoSecondaryCard(
                    title: OnboardingCopy.t("Présence", en: "Presence"),
                    subtitle: OnboardingCopy.t("On t’écoute davantage.", en: "People listen more."),
                    icon: "person.wave.2"
                )
                .frame(height: 104)
                .staggerReveal(showBentoPresence, reduceMotion: reduceMotion)

                bentoSecondaryCard(
                    title: OnboardingCopy.t("Attirance", en: "Attraction"),
                    subtitle: OnboardingCopy.t("Plus de regards, plus d’intérêt.", en: "More looks, more interest."),
                    icon: "heart.fill"
                )
                .frame(height: 104)
                .staggerReveal(showBentoAttraction, reduceMotion: reduceMotion)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var bentoPrimaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            bentoIcon(systemName: "eye")
            Spacer(minLength: 0)
            Text(OnboardingCopy.t("Première impression", en: "First impression"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OnboardingTheme.primaryText)
            Text(OnboardingCopy.t(
                "On te juge en 3 secondes. Ton visage parle avant toi.",
                en: "They judge you in 3 seconds. Your face speaks first."
            ))
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(OnboardingTheme.bodyText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .processGlassEffect(in: bentoShape, interactive: false)
    }

    private func bentoSecondaryCard(
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            bentoIcon(systemName: icon)
            Spacer(minLength: 0)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(OnboardingTheme.primaryText)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OnboardingTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .processGlassEffect(in: bentoShape, interactive: false)
    }

    private func bentoIcon(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.14))
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
        }
        .padding(.bottom, 10)
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
        showBentoPresence = false
        showBentoAttraction = false

        if reduceMotion {
            revealAllImmediately()
            return
        }

        reveal(after: 0.08) { showGreeting = true }
        reveal(after: 0.18) { showHeadline = true }
        reveal(after: 0.30) {
            showSubtext = true
            showPortrait = true
        }
        reveal(after: 0.44) { showSectionLabel = true }
        reveal(after: 0.52) { showTestimonial = true }
        reveal(after: 0.68) { showBentoLeft = true }
        reveal(after: 0.80) { showBentoPresence = true }
        reveal(after: 0.92) {
            showBentoAttraction = true
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
        showBentoPresence = true
        showBentoAttraction = true
        markCompleted()
    }

    private func reveal(after delay: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
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
