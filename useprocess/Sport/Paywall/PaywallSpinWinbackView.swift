import SwiftUI
import UIKit

// MARK: - Segments

private struct PaywallSpinSegment: Identifiable, Equatable {
    enum Kind: Equatable {
        case percent(Int)
        case jackpot(Int)
        case lifetime
    }

    let id: String
    let kind: Kind
    let tint: Color

    var isJackpot: Bool {
        switch kind {
        case .jackpot, .lifetime: return true
        case .percent: return false
        }
    }

    var isFivePercent: Bool {
        if case .percent(5) = kind { return true }
        return false
    }

    var labelText: String {
        switch kind {
        case .percent(let value), .jackpot(let value):
            return "\(value)%"
        case .lifetime:
            return SubscriptionConfiguration.winbackJackpotTitle
        }
    }
}

private enum PaywallSpinPhase: Equatable {
    case readyFirst
    case spinningFirst
    case lost
    case readySecond
    case spinningSecond
    case won
}

enum PaywallSpinWinbackPresentation: Equatable {
    /// Roue complète puis page offre.
    case spinWheel
    /// Page offre uniquement (ex. quick action « Accès à vie offert »).
    case offerOnly
}

// MARK: - Vue principale

struct PaywallSpinWinbackView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    let presentation: PaywallSpinWinbackPresentation
    let analyticsSource: String?
    let onClaimed: () -> Void

    @State private var phase: PaywallSpinPhase = .readyFirst
    @State private var rotation: Double = 0
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showOfferCard: Bool
    @State private var showWinReveal = false
    @State private var showSpinAgainSheet = false
    @State private var winRevealNumberVisible = false
    @State private var winRevealSubtitleVisible = false
    @State private var confettiBurst = false
    @State private var offerEntranceConfetti = false
    @State private var rewardHeroAppeared: Bool
    @State private var offerCountdownEndDate = Date().addingTimeInterval(180)
    @State private var lastTickIndex = -1
    @State private var spinTask: Task<Void, Never>?
    @State private var revealTask: Task<Void, Never>?

    init(
        presentation: PaywallSpinWinbackPresentation = .spinWheel,
        analyticsSource: String? = nil,
        onClaimed: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.analyticsSource = analyticsSource
        self.onClaimed = onClaimed
        let startsOnOffer = presentation == .offerOnly
        _showOfferCard = State(initialValue: startsOnOffer)
        _rewardHeroAppeared = State(initialValue: startsOnOffer)
    }

    /// Couleurs type référence : gris clair / menthe / jaune jackpot.
    private static let colorLight = Color(red: 0.86, green: 0.90, blue: 0.90)
    private static let colorMint = Color(red: 0.55, green: 0.78, blue: 0.74)
    private static let colorJackpot = Color(red: 0.93, green: 0.82, blue: 0.38)
    private static let discountHighlight = Color(red: 0.95, green: 0.42, blue: 0.48)

    private var winJackpotTitle: String {
        OnboardingCopy.t(SubscriptionConfiguration.winbackJackpotTitle, en: "LIFETIME")
    }

    private var isTrialRetentionOffer: Bool {
        false
    }

    private var trialDays: Int {
        if isTrialRetentionOffer {
            return SubscriptionConfiguration.retentionQuickActionTrialDays
        }
        return subscriptionService.trialInfo(for: .annual).days
    }

    private var trialAnnualStrikethroughPrice: String {
        subscriptionService.winbackCompareAtDisplayPrice
    }

    private var lifetimeOfferPrice: String {
        subscriptionService.winbackLifetimeDisplayPrice
    }

    /// Prix mensuel barré (ex. « 23€/mois ») — ancre visuelle vs lifetime.
    private var monthlyStrikethroughLabel: String {
        subscriptionService.displayProduct(for: .monthly).paywallPrimaryMonthlyPriceLabel
    }

    /// Ordre type image : 5, jackpot à vie, 5, 10, 5, 25, 5, 10
    private var segments: [PaywallSpinSegment] {
        return [
            .init(id: "0", kind: .percent(5), tint: Self.colorLight),
            .init(id: "1", kind: .lifetime, tint: Self.colorJackpot),
            .init(id: "2", kind: .percent(5), tint: Self.colorLight),
            .init(id: "3", kind: .percent(10), tint: Self.colorMint),
            .init(id: "4", kind: .percent(5), tint: Self.colorLight),
            .init(id: "5", kind: .percent(25), tint: Self.colorMint),
            .init(id: "6", kind: .percent(5), tint: Self.colorLight),
            .init(id: "7", kind: .percent(10), tint: Self.colorMint),
        ]
    }

    private var fivePercentIndex: Int {
        segments.indices.first(where: { segments[$0].isFivePercent }) ?? 0
    }

    private var jackpotIndex: Int {
        segments.firstIndex(where: \.isJackpot) ?? 1
    }

    private var isSpinning: Bool {
        phase == .spinningFirst || phase == .spinningSecond
    }

    private var canSpin: Bool {
        (phase == .readyFirst || phase == .readySecond) && !showSpinAgainSheet
    }

    var body: some View {
        ZStack {
            backdrop

            Group {
                if showOfferCard {
                    rewardLayout
                } else {
                    spinningLayout
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .regularWidthContainer(maxWidth: AdaptiveScreenLayout.paywallMaxWidth)
            .opacity(showSpinAgainSheet ? 0.28 : 1)
            .blur(radius: showSpinAgainSheet ? 5 : 0)
            .animation(.easeOut(duration: 0.28), value: showSpinAgainSheet)
            .allowsHitTesting(!showSpinAgainSheet)

            if showSpinAgainSheet {
                Color.black.opacity(0.52)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(20)
                    .allowsHitTesting(true)

                spinAgainSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(30)
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: showSpinAgainSheet)
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: showOfferCard)
        .alert(AppCopy.t("Achat", en: "Purchase"), isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button(AppCopy.t("OK", en: "OK"), role: .cancel) {}
        } message: {
            if let purchaseError { Text(purchaseError) }
        }
        .onAppear {
            ProcessPreAccessHomeSwipeCoordinator.shared.retentionSurface = .spinWinback
            if presentation == .offerOnly {
                offerCountdownEndDate = Date().addingTimeInterval(180)
                let source = analyticsSource ?? "offer_only"
                ProcessAnalytics.trackPaywallViewed(source: source)
                ProcessAnalytics.trackSpinOfferShown(source: source)
            } else {
                ProcessAnalytics.trackSpinWheelViewed(
                    source: analyticsSource ?? "paywall_cancel_or_exit"
                )
            }
        }
        .onChange(of: showOfferCard) { _, isShowing in
            guard isShowing, presentation == .spinWheel else { return }
            ProcessAnalytics.trackSpinOfferShown(source: "spin_wheel")
        }
        .onChange(of: showSpinAgainSheet) { _, isShowing in
            if isShowing {
                ProcessAnalytics.trackSpinAgainSheetShown()
            }
        }
        .onChange(of: showWinReveal) { _, isShowing in
            if isShowing {
                ProcessAnalytics.trackSpinWinRevealShown(jackpotTitle: winJackpotTitle)
            }
        }
        .task {
            await subscriptionService.loadSubscriptions()
            guard presentation == .offerOnly else { return }
            await subscriptionService.checkSubscriptionStatus()
            if subscriptionService.subscriptionStatus.isActive {
                onClaimed()
            }
        }
        .onChange(of: subscriptionService.subscriptionStatus) { oldValue, newValue in
            guard presentation == .offerOnly else { return }
            if newValue.isActive, !oldValue.isActive {
                isPurchasing = false
                onClaimed()
            }
        }
        .onAppear {
            if analyticsSource == "marketing_notif_spin" {
                ProcessPreAccessHomeSwipeCoordinator.shared.retentionSurface = .spinWinback
            }
        }
        .onDisappear {
            spinTask?.cancel()
            revealTask?.cancel()
            if ProcessPreAccessHomeSwipeCoordinator.shared.retentionSurface == .spinWinback {
                // Paywall parent remet `.paywall` via onChange ; deep-link notif → `.none`.
                ProcessPreAccessHomeSwipeCoordinator.shared.retentionSurface =
                    analyticsSource == "marketing_notif_spin" ? .none : .paywall
            }
        }
        // Cover plein écran : garde un deferral local (le root AppShell est en dessous).
        .processRequireDoubleHomeSwipe {
            ProcessPreAccessHomeSwipeCoordinator.shared.handleFirstSwipe()
        }
    }

    /// Page finale — offre unique, structure alignée sur `PaywallView`.
    private var rewardLayout: some View {
        VStack(spacing: 0) {
            Text(OnboardingCopy.t("Ton offre unique", en: "Your one-time offer"))
                .font(PaywallBevelTheme.paywallHeroTitleFont(size: 31))
                .tracking(PaywallBevelTheme.paywallHeroTitleTracking)
                .foregroundStyle(PaywallBevelTheme.paywallTitleColor(for: colorScheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, max(2, OnboardingConstants.backOnlyContentTopInset - 56))

            rewardOfferHero
                .padding(.horizontal, 40)
                .padding(.top, 16)

            rewardInlinePricing
                .padding(.top, 22)

            rewardOfferFooterCopy
                .padding(.top, 16)
                .padding(.horizontal, 32)

            Spacer(minLength: 20)
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

            PaywallSpinOfferCountdown(endDate: offerCountdownEndDate)
                .padding(.top, 8)
                .padding(.bottom, 18)

            rewardBottomSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            ZStack {
                PaywallSpinFallingConfetti()
                if offerEntranceConfetti {
                    PaywallSpinConfetti()
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onAppear {
            offerCountdownEndDate = Date().addingTimeInterval(180)
            offerEntranceConfetti = true
            if presentation == .offerOnly {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                    rewardHeroAppeared = true
                }
            } else {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                    rewardHeroAppeared = true
                }
            }
        }
    }

    private var rewardInlinePricing: some View {
        Group {
            if isTrialRetentionOffer {
                Text(trialAnnualStrikethroughPrice)
                    .font(PaywallBevelTheme.paywallHeroTitleFont(size: 26))
                    .foregroundStyle(PaywallBevelTheme.planSecondaryPrice(for: colorScheme).opacity(0.72))
                    .strikethrough(
                        true,
                        color: PaywallBevelTheme.planSecondaryPrice(for: colorScheme).opacity(0.55)
                    )
            } else {
                VStack(spacing: 6) {
                    Text(monthlyStrikethroughLabel)
                        .font(PaywallBevelTheme.paywallHeroTitleFont(size: 34))
                        .tracking(PaywallBevelTheme.paywallHeroTitleTracking)
                        .foregroundStyle(PaywallBevelTheme.planSecondaryPrice(for: colorScheme).opacity(0.62))
                        .strikethrough(
                            true,
                            color: PaywallBevelTheme.planSecondaryPrice(for: colorScheme).opacity(0.5)
                        )

                    Text(
                        OnboardingCopy.t(
                            "\(lifetimeOfferPrice) à vie",
                            en: "\(lifetimeOfferPrice) lifetime"
                        )
                    )
                    .font(PaywallBevelTheme.paywallHeroSubtitleFont(size: 22))
                    .foregroundStyle(PaywallBevelTheme.planPrimaryPrice(for: colorScheme))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(rewardHeroAppeared ? 1 : 0)
    }

    private var rewardOfferFooterCopy: some View {
        VStack(spacing: 8) {
            Text(OnboardingCopy.t(
                "Si tu fermes cette offre, elle disparaît.",
                en: "If you close this offer, it’s gone."
            ))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))

            Text(
                isTrialRetentionOffer
                    ? OnboardingCopy.t(
                        "Accès illimité au coach, aux scans et à ton plan pendant \(trialDays) jours.",
                        en: "Unlimited coach, scans, and your plan for \(trialDays) days."
                    )
                    : OnboardingCopy.t(
                        "Accès premium à vie — paiement unique, sans abonnement.",
                        en: "Lifetime premium access — one payment, no subscription."
                    )
            )
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
        }
        .multilineTextAlignment(.center)
        .opacity(rewardHeroAppeared ? 1 : 0)
    }

    private var rewardOfferHero: some View {
        let heroShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return ZStack {
            PaywallSpinOfferStars()

            VStack(spacing: 6) {
                Text(
                    isTrialRetentionOffer
                        ? OnboardingCopy.t("\(trialDays) JOURS", en: "\(trialDays) DAYS")
                        : OnboardingCopy.t("ACCÈS", en: "ACCESS")
                )
                    .font(PaywallBevelTheme.paywallHeroTitleFont(size: 32))
                    .tracking(PaywallBevelTheme.paywallHeroTitleTracking)
                    .foregroundStyle(PaywallBevelTheme.paywallTitleColor(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(
                    isTrialRetentionOffer
                        ? OnboardingCopy.t("OFFERTS", en: "FREE")
                        : winJackpotTitle
                )
                    .font(PaywallBevelTheme.paywallHeroTitleFont(size: 32))
                    .tracking(PaywallBevelTheme.paywallHeroTitleTracking)
                    .foregroundStyle(PaywallBevelTheme.paywallTitleColor(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 36)
            .padding(.horizontal, 30)
            .frame(maxWidth: 280)
            .background {
                heroShape.fill(.clear)
            }
            .modifier(PaywallSpinLiquidGlassCard(shape: heroShape))
            .scaleEffect(rewardHeroAppeared ? 1 : 0.88)
            .opacity(rewardHeroAppeared ? 1 : 0)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 176)
    }

    private var spinningLayout: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, max(2, OnboardingConstants.backOnlyContentTopInset - 34))

            Spacer(minLength: 4)

            ZStack {
                if confettiBurst {
                    PaywallSpinConfetti()
                        .allowsHitTesting(false)
                }

                if showWinReveal {
                    winRevealOverlay
                        .transition(.opacity)
                } else {
                    wheelStack
                        .padding(.horizontal, 18)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showWinReveal)

            Spacer(minLength: 8)

            bottomArea
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Bas : carte plan + CTA + disclaimer (même repères que `PaywallView.bottomSection`).
    private var rewardBottomSection: some View {
        VStack(spacing: 14) {
            offerCard

            PaywallBevelContinueButton(
                title: rewardClaimButtonTitle,
                isLoading: isPurchasing,
                isEnabled: !isPurchasing && (
                    isTrialRetentionOffer
                        ? subscriptionService.hasLiveAnnualProduct
                        : subscriptionService.hasLiveLifetimeProduct
                )
            ) {
                Task { await claimOffer() }
            }

            Text(
                isTrialRetentionOffer
                    ? OnboardingCopy.t(
                        "Sans engagement, annulable à tout moment.",
                        en: "No commitment — cancel anytime."
                    )
                    : OnboardingCopy.t(
                        "Paiement unique — accès à vie, sans renouvellement.",
                        en: "One-time payment — lifetime access, no renewal."
                    )
            )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 44)
        .padding(.top, 2)
    }

    // MARK: - Chrome

    private var backdrop: some View {
        PaywallBevelBackdrop()
            .ignoresSafeArea()
    }

    private var header: some View {
        Group {
            if phase == .won && showWinReveal {
                Color.clear
                    .frame(height: 0)
            } else {
                Text(spinHeaderCopy)
                    .font(PaywallBevelTheme.paywallHeroTitleFont(size: 34))
                    .tracking(PaywallBevelTheme.paywallHeroTitleTracking)
                    .foregroundStyle(PaywallBevelTheme.paywallTitleColor(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                    .minimumScaleFactor(0.86)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: phase)
        .opacity(showWinReveal && !showOfferCard ? 0 : 1)
    }

    private var spinHeaderCopy: String {
        switch phase {
        case .readyFirst, .spinningFirst:
            return OnboardingCopy.t(
                "Tourne la roue\npour débloquer une remise",
                en: "Spin the wheel\nto unlock a discount"
            )
        case .lost, .readySecond, .spinningSecond:
            return OnboardingCopy.t(
                "Encore un tour\npour débloquer une remise",
                en: "One more spin\nto unlock a discount"
            )
        case .won:
            return ""
        }
    }

    // MARK: - Roue

    private var wheelSize: CGFloat { 348 }

    private var wheelStack: some View {
        ZStack(alignment: .top) {
            // Ombre douce sous la roue — pas de glow
            Ellipse()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.5 : 0.16))
                .frame(width: wheelSize * 0.88, height: 48)
                .blur(radius: 16)
                .offset(y: wheelSize + 28)

            // Épaisseur / extrude 3D
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.06), Color(white: 0.16)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: wheelSize, height: wheelSize)
                .overlay {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.55), lineWidth: 1)
                }
                .offset(y: 14)
                .padding(.top, 18)

            PaywallSpinWheelDisk(segments: segments, rotation: rotation)
                .frame(width: wheelSize, height: wheelSize)
                .padding(.top, 18)

            PaywallSpinMapPin()
                .frame(width: 32, height: 40)
                .offset(y: -2)
                .zIndex(2)
        }
        .frame(height: wheelSize + 58)
        .accessibilityHidden(true)
    }

    // MARK: - Sheets

    private var spinAgainSheet: some View {
        // Fond charcoal fixe → textes toujours clairs (évite gris-sur-gris en mode clair).
        let sheetBackground = Color(red: 0.14, green: 0.14, blue: 0.16)
        let titleColor = Color.white
        let bodyColor = Color.white.opacity(0.78)

        return VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Text("💎")
                        .font(.system(size: 30))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(OnboardingCopy.t("Retente ta chance", en: "Try again"))
                            .font(PaywallBevelTheme.paywallHeroTitleFont(size: 26))
                            .tracking(PaywallBevelTheme.paywallHeroTitleTracking)
                            .foregroundStyle(titleColor)

                        Text(OnboardingCopy.t(
                            "Tu es tombé sur 5%.\nL’accès à vie est encore sur la roue — retente avant que l’offre disparaisse.",
                            en: "You landed on 5%.\nLifetime access is still on the wheel — spin again before the offer disappears."
                        ))
                            .font(PaywallBevelTheme.paywallHeroSubtitleFont(size: 16))
                            .foregroundStyle(bodyColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    beginSecondSpinFromSheet()
                } label: {
                    Text(OnboardingCopy.t("Tourner encore", en: "Spin again"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.10, blue: 0.12))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                        }
                }
                .buttonStyle(PaywallSpinPressStyle())
                .padding(.top, 8)
            }
            .padding(.horizontal, 26)
            .padding(.top, 30)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: 32,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 32,
                    style: .continuous
                )
                .fill(sheetBackground)
                .shadow(color: .black.opacity(0.4), radius: 28, y: -10)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func beginSecondSpinFromSheet() {
        HapticManager.shared.impact(.medium)
        ProcessAnalytics.trackSpinAgainTapped()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            showSpinAgainSheet = false
            phase = .readySecond
        }
        // Tourne direct après fermeture du sheet — pas besoin de re-taper le CTA.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard phase == .readySecond, !showSpinAgainSheet else { return }
            startSpin()
        }
    }

    private var winRevealOverlay: some View {
        VStack(spacing: 14) {
            Text(winJackpotTitle)
                .font(PaywallBevelTheme.paywallHeroTitleFont(size: 84))
                .tracking(PaywallBevelTheme.paywallHeroTitleTracking)
                .foregroundStyle(PaywallBevelTheme.paywallProTitleGradient(for: colorScheme))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .opacity(winRevealNumberVisible ? 1 : 0)
                .scaleEffect(winRevealNumberVisible ? 1 : 0.88)
                .blur(radius: winRevealNumberVisible ? 0 : 6)
                .animation(.spring(response: 0.52, dampingFraction: 0.78), value: winRevealNumberVisible)

            Text(OnboardingCopy.t(
                "à \(lifetimeOfferPrice) — accès premium",
                en: "for \(lifetimeOfferPrice) — premium access"
            ))
                .font(PaywallBevelTheme.paywallHeroSubtitleFont(size: 18))
                .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                .multilineTextAlignment(.center)
                .opacity(winRevealSubtitleVisible ? 1 : 0)
                .offset(y: winRevealSubtitleVisible ? 0 : 10)
                .animation(.easeOut(duration: 0.38), value: winRevealSubtitleVisible)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
        .offset(y: -18)
    }

    // MARK: - Bas

    @ViewBuilder
    private var bottomArea: some View {
        if phase == .readyFirst || phase == .readySecond || isSpinning {
            spinButton
                .animation(.spring(response: 0.45, dampingFraction: 0.86), value: phase)
        }
    }

    private var spinButton: some View {
        Button {
            startSpin()
        } label: {
            Text(
                isSpinning
                    ? OnboardingCopy.t("La roue tourne…", en: "The wheel is spinning…")
                    : OnboardingCopy.t("Tourner la roue", en: "Spin the wheel")
            )
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(paywallCTATextColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.92 : 0.94))
                }
        }
        .buttonStyle(PaywallSpinPressStyle())
        .disabled(isSpinning || !canSpin)
        .opacity(isSpinning ? 0.55 : 1)
    }

    private var paywallCTATextColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var rewardClaimButtonTitle: String {
        if isTrialRetentionOffer {
            return subscriptionService.trialInfo(for: .annual).ctaTitle(
                fallback: OnboardingCopy.t("Commencer mon essai", en: "Start my trial")
            )
        }
        return OnboardingCopy.t("Réclamer mon offre", en: "Claim my offer")
    }

    private var offerCard: some View {
        let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return VStack(alignment: .leading, spacing: 10) {
            if isTrialRetentionOffer {
                Text(OnboardingCopy.t("ESSAI GRATUIT", en: "FREE TRIAL"))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(Self.discountHighlight)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(OnboardingCopy.t("Accès premium", en: "Premium access"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(PaywallBevelTheme.titleText(for: colorScheme))

                        Text(trialAnnualStrikethroughPrice)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                            .strikethrough(
                                true,
                                color: PaywallBevelTheme.subtitleText(for: colorScheme).opacity(0.7)
                            )
                    }

                    Spacer(minLength: 8)

                    Text(OnboardingCopy.t(
                        "\(trialDays) j. gratuits",
                        en: "\(trialDays) free days"
                    ))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(PaywallBevelTheme.planPrimaryPrice(for: colorScheme))
                }
            } else {
                Text(OnboardingCopy.t("-80% POUR TOUJOURS", en: "-80% FOREVER"))
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(Self.discountHighlight)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(OnboardingCopy.t("Accès à vie", en: "Lifetime access"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(PaywallBevelTheme.titleText(for: colorScheme))

                        Text(OnboardingCopy.t(
                            "Paiement unique · sans abonnement",
                            en: "One payment · no subscription"
                        ))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme).opacity(0.9))
                    }

                    Spacer(minLength: 8)

                    Text(lifetimeOfferPrice)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(PaywallBevelTheme.planPrimaryPrice(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            cardShape.fill(.clear)
        }
        .modifier(PaywallSpinLiquidGlassCard(shape: cardShape))
    }

    // MARK: - Spin logic

    private func startSpin() {
        guard canSpin else { return }
        HapticManager.shared.impact(.medium)

        let isFirst = phase == .readyFirst
        ProcessAnalytics.trackSpinStarted(attempt: isFirst ? 1 : 2)
        let targetIndex = isFirst ? fivePercentIndex : jackpotIndex
        phase = isFirst ? .spinningFirst : .spinningSecond

        // 1er tour plus lent + freinage ; 2e encore plus de suspense
        let extraSpins = isFirst ? 7 : 11
        let duration = isFirst ? 5.6 : 6.8
        let controlPoints: (Double, Double, Double, Double) = isFirst
            ? (0.10, 0.78, 0.06, 1.0)
            : (0.05, 0.92, 0.08, 1.0)

        let segmentAngle = 360.0 / Double(segments.count)
        // Arrêt décalé dans la part — pas pile au centre.
        let landingOffset = Double.random(in: 0.14...0.86)
        let targetAngle = (Double(targetIndex) + landingOffset) * segmentAngle
        let landing = (360.0 - targetAngle).truncatingRemainder(dividingBy: 360)
        let currentMod = rotation.truncatingRemainder(dividingBy: 360)
        let deltaToLanding = (landing - currentMod + 360).truncatingRemainder(dividingBy: 360)
        let finalRotation = rotation + Double(extraSpins) * 360 + deltaToLanding

        // Léger dépassement puis rebond — effet roue physique.
        let overshoot = Double.random(in: 4.5...10.5) * (Bool.random() ? 1 : -1)
        let overshootRotation = finalRotation + overshoot
        let spinDuration = duration * 0.93
        let settleDuration = 0.38

        lastTickIndex = currentSegmentIndex(for: rotation)
        spinTask?.cancel()
        spinTask = Task { @MainActor in
            await runWheelTickHaptics(
                from: rotation,
                until: overshootRotation,
                duration: spinDuration,
                controlPoints: controlPoints
            )
        }

        withAnimation(.timingCurve(
            controlPoints.0,
            controlPoints.1,
            controlPoints.2,
            controlPoints.3,
            duration: spinDuration
        )) {
            rotation = overshootRotation
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(spinDuration))
            guard !Task.isCancelled else { return }

            await runWheelSettleHaptics()
            withAnimation(.spring(response: 0.44, dampingFraction: 0.56)) {
                rotation = finalRotation
            }

            try? await Task.sleep(for: .seconds(settleDuration))
            guard !Task.isCancelled else { return }
            finishSpin(isFirst: isFirst)
        }
    }

    private func finishSpin(isFirst: Bool) {
        spinTask?.cancel()
        if isFirst {
            ProcessAnalytics.trackSpinFinished(attempt: 1, result: "lost_5_percent")
            HapticManager.shared.notification(.warning)
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                phase = .lost
                showSpinAgainSheet = true
            }
        } else {
            ProcessAnalytics.trackSpinFinished(attempt: 2, result: "won_jackpot")
            HapticManager.shared.notification(.success)
            confettiBurst = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                phase = .won
                showWinReveal = true
            }
            runWinRevealSequence()
        }
    }

    private func runWinRevealSequence() {
        revealTask?.cancel()
        winRevealNumberVisible = false
        winRevealSubtitleVisible = false

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
                winRevealNumberVisible = true
            }
            HapticManager.shared.notification(.success)

            try? await Task.sleep(for: .milliseconds(620))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.38)) {
                winRevealSubtitleVisible = true
            }

            try? await Task.sleep(for: .milliseconds(980))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                showOfferCard = true
            }
        }
    }

    private func currentSegmentIndex(for degrees: Double) -> Int {
        let segmentAngle = 360.0 / Double(segments.count)
        let normalized = (360.0 - degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        return Int(normalized / segmentAngle) % segments.count
    }

    /// Vibrations calées sur chaque frontière de segment (comme une vraie roue).
    private func runWheelTickHaptics(
        from start: Double,
        until target: Double,
        duration: Double,
        controlPoints: (Double, Double, Double, Double)
    ) async {
        let segmentAngle = 360.0 / Double(segments.count)
        let totalDelta = target - start
        guard totalDelta > 0.5 else { return }

        let tick = UIImpactFeedbackGenerator(style: .rigid)
        tick.prepare()
        let heavyTick = UIImpactFeedbackGenerator(style: .heavy)
        heavyTick.prepare()

        // Prochaine frontière après le départ (chaque +45° = un cran sous le pin)
        var nextBoundary = (floor(start / segmentAngle) + 1.0) * segmentAngle
        let startDate = Date()
        var lastFire = Date.distantPast
        let minInterval: TimeInterval = 0.022

        while nextBoundary <= target + 0.01, !Task.isCancelled {
            let progress = min(1, (nextBoundary - start) / totalDelta)
            let t = Self.timeForEasedProgress(
                progress,
                x1: controlPoints.0,
                y1: controlPoints.1,
                x2: controlPoints.2,
                y2: controlPoints.3
            )
            let fireAt = startDate.addingTimeInterval(t * duration)
            let wait = fireAt.timeIntervalSinceNow
            if wait > 0.001 {
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled else { return }

            let sinceLast = Date().timeIntervalSince(lastFire)
            if sinceLast >= minInterval {
                let intensity = 0.42 + 0.58 * progress
                if progress < 0.72 {
                    tick.impactOccurred(intensity: CGFloat(min(1, intensity)))
                    tick.prepare()
                } else {
                    heavyTick.impactOccurred(intensity: CGFloat(min(1, 0.72 + intensity * 0.28)))
                    heavyTick.prepare()
                }
                lastFire = Date()
                lastTickIndex = currentSegmentIndex(for: nextBoundary)
            }

            nextBoundary += segmentAngle
        }
    }

    private func runWheelSettleHaptics() async {
        HapticManager.shared.rigidImpact()
        try? await Task.sleep(for: .milliseconds(85))
        guard !Task.isCancelled else { return }
        HapticManager.shared.impact(.medium)
        try? await Task.sleep(for: .milliseconds(105))
        guard !Task.isCancelled else { return }
        HapticManager.shared.rigidImpact()
    }

    /// Inverse d’une courbe `cubic-bezier` : trouve `t` tel que eased(t) ≈ progress.
    private static func timeForEasedProgress(
        _ eased: Double,
        x1: Double,
        y1: Double,
        x2: Double,
        y2: Double
    ) -> Double {
        let target = min(1, max(0, eased))
        var lo = 0.0
        var hi = 1.0
        for _ in 0..<20 {
            let mid = (lo + hi) * 0.5
            let value = cubicBezierProgress(mid, x1: x1, y1: y1, x2: x2, y2: y2)
            if value < target {
                lo = mid
            } else {
                hi = mid
            }
        }
        return (lo + hi) * 0.5
    }

    /// Évalue une courbe CSS `cubic-bezier(x1,y1,x2,y2)` pour un progrès temporel `t`.
    private static func cubicBezierProgress(
        _ t: Double,
        x1: Double,
        y1: Double,
        x2: Double,
        y2: Double
    ) -> Double {
        var u = t
        for _ in 0..<6 {
            let x = bezierSample(u, a: x1, b: x2)
            let dx = bezierDerivative(u, a: x1, b: x2)
            guard abs(dx) > 1e-6 else { break }
            u -= (x - t) / dx
            u = min(1, max(0, u))
        }
        return bezierSample(u, a: y1, b: y2)
    }

    private static func bezierSample(_ u: Double, a: Double, b: Double) -> Double {
        let oneMinus = 1 - u
        return 3 * oneMinus * oneMinus * u * a
            + 3 * oneMinus * u * u * b
            + u * u * u
    }

    private static func bezierDerivative(_ u: Double, a: Double, b: Double) -> Double {
        let oneMinus = 1 - u
        return 3 * oneMinus * oneMinus * a
            + 6 * oneMinus * u * (b - a)
            + 3 * u * u * (1 - b)
    }

    @MainActor
    private func claimOffer() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        let source = analyticsSource ?? "spin_wheel"
        let plan = "winback_lifetime"
        let offer = SubscriptionConfiguration.winbackOfferID

        ProcessAnalytics.trackSpinOfferCTATapped(source: source)
        ProcessAnalytics.trackPurchaseStarted(plan: plan, offer: offer, source: source)

        do {
            if !subscriptionService.canPurchase {
                await subscriptionService.loadSubscriptions()
            }
            try await subscriptionService.purchaseWinbackLifetime()
            await subscriptionService.checkSubscriptionStatus()
            if subscriptionService.subscriptionStatus.isActive {
                ProcessAnalytics.trackPurchaseCompleted(plan: plan, offer: offer, source: source)
                ProcessMarketingNotificationService.shared.handlePurchaseSuccess(plan: plan)
                onClaimed()
            }
        } catch SubscriptionError.userCancelled {
            ProcessAnalytics.trackPurchaseCancelled(plan: plan, offer: offer, source: source)
            return
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            ProcessAnalytics.trackPurchaseFailed(
                plan: plan,
                error: message,
                offer: offer,
                source: source
            )
            purchaseError = message
        }
    }
}

// MARK: - Disque 3D

private struct PaywallSpinWheelDisk: View {
    let segments: [PaywallSpinSegment]
    let rotation: Double

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let segmentAngle = 360.0 / Double(segments.count)

            ZStack {
                // Anneau extérieur (relief)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.22),
                                Color(white: 0.08),
                                Color(white: 0.18),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.45), radius: 14, y: 10)

                // Plateau intérieur
                Circle()
                    .fill(Color(white: 0.12))
                    .padding(7)

                Canvas { context, canvasSize in
                    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    let radius = min(canvasSize.width, canvasSize.height) / 2 - 10

                    for (index, segment) in segments.enumerated() {
                        let startDeg = -90.0 + Double(index) * segmentAngle
                        let endDeg = startDeg + segmentAngle

                        var wedge = Path()
                        wedge.move(to: center)
                        wedge.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(startDeg),
                            endAngle: .degrees(endDeg),
                            clockwise: false
                        )
                        wedge.closeSubpath()
                        context.fill(wedge, with: .color(segment.tint))

                        // Dégradé 3D sur chaque part
                        context.fill(
                            wedge,
                            with: .linearGradient(
                                Gradient(colors: [
                                    .white.opacity(0.28),
                                    .clear,
                                    .black.opacity(0.18),
                                ]),
                                startPoint: CGPoint(x: center.x, y: center.y - radius),
                                endPoint: CGPoint(x: center.x, y: center.y + radius * 0.35)
                            )
                        )
                    }

                    for index in 0..<segments.count {
                        let deg = (-90.0 + Double(index) * segmentAngle) * .pi / 180
                        var line = Path()
                        line.move(to: center)
                        line.addLine(to: CGPoint(
                            x: center.x + CGFloat(cos(deg)) * radius,
                            y: center.y + CGFloat(sin(deg)) * radius
                        ))
                        context.stroke(line, with: .color(.black.opacity(0.12)), lineWidth: 1.5)
                    }
                }
                .padding(8)

                // Labels
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    ZStack {
                        Group {
                            if case .lifetime = segment.kind {
                                Text(segment.labelText)
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.15))
                                    .multilineTextAlignment(.center)
                                    .frame(width: 52)
                            } else if segment.isJackpot {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.15))
                            } else {
                                Text(segment.labelText)
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.15))
                            }
                        }
                        .offset(y: -size * 0.30)
                    }
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees((Double(index) + 0.5) * segmentAngle))
                }

                // Biseau intérieur
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.35),
                                .black.opacity(0.35),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .padding(8)

                // Moyeu + icône app
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 78, height: 78)
                        .shadow(color: .black.opacity(0.45), radius: 8, y: 4)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 78, height: 78)

                    Image("ProcessAppIcon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipShape(Circle())
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .rotationEffect(.degrees(rotation))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Pointeur pin

private struct PaywallSpinMapPin: View {
    private let pinRed = Color(red: 0.90, green: 0.18, blue: 0.24)

    var body: some View {
        ZStack {
            PaywallSpinPinShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.34, blue: 0.38),
                            pinRed,
                            Color(red: 0.70, green: 0.08, blue: 0.14),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)

            Circle()
                .fill(Color.white)
                .frame(width: 9, height: 9)
                .offset(y: -7.5)
        }
    }
}

/// Pin type localisation : tête ronde + pointe vers le bas.
private struct PaywallSpinPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let r = w * 0.46
        let c = CGPoint(x: rect.midX, y: r + 0.5)
        let tip = CGPoint(x: rect.midX, y: h)

        var path = Path()
        path.addArc(
            center: c,
            radius: r,
            startAngle: .degrees(200),
            endAngle: .degrees(-20),
            clockwise: false
        )
        path.addLine(to: tip)
        path.closeSubpath()
        return path
    }
}

// MARK: - Liquid glass carte offre

private struct PaywallSpinLiquidGlassCard<S: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let shape: S

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content
                    .background {
                        shape.fill(.clear)
                    }
                    .glassEffect(ProcessGlass.waterSurface, in: shape)
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
            }
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.48 : 0.62),
                        Color.white.opacity(colorScheme == .dark ? 0.06 : 0.10),
                        Color.white.opacity(colorScheme == .dark ? 0.26 : 0.34),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.15
            )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.11), radius: 20, y: 10)
        .shadow(color: Color(red: 0.35, green: 0.82, blue: 0.94).opacity(0.14), radius: 24, y: 4)
    }
}

// MARK: - Compte à rebours offre

private struct PaywallSpinOfferCountdown: View {
    @Environment(\.colorScheme) private var colorScheme
    let endDate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.01)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
            let totalCentiseconds = Int((remaining * 100).rounded(.down))
            let minutes = min(99, totalCentiseconds / 6000)
            let seconds = (totalCentiseconds % 6000) / 100
            let centiseconds = totalCentiseconds % 100

            VStack(spacing: 10) {
                Text(OnboardingCopy.t("Offre expire dans", en: "Offer expires in"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.45))
                    .tracking(0.4)

                HStack(alignment: .center, spacing: 14) {
                    countdownUnit(value: minutes, label: "MIN")
                    countdownColon
                    countdownUnit(value: seconds, label: "SEC")
                    countdownColon
                    countdownUnit(value: centiseconds, label: "CS")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
        }
    }

    private var countdownColon: some View {
        Text(":")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.55))
            .padding(.bottom, 16)
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Text(String(format: "%02d", value))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 58, height: 48)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: colorScheme == .dark ? 0.22 : 0.18),
                                    Color.black.opacity(colorScheme == .dark ? 0.92 : 0.88),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                }

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.48))
                .tracking(1.0)
        }
    }
}

// MARK: - Étoiles animées

private struct PaywallSpinOfferStars: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulse = false

    private struct StarSpec: Identifiable {
        let id: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let delay: Double
        let opacity: Double
    }

    private let stars: [StarSpec] = [
        .init(id: "l1", x: -0.46, y: -0.22, size: 24, delay: 0.00, opacity: 0.95),
        .init(id: "l2", x: -0.38, y: 0.18, size: 14, delay: 0.25, opacity: 0.55),
        .init(id: "l3", x: -0.50, y: 0.08, size: 18, delay: 0.55, opacity: 0.72),
        .init(id: "r1", x: 0.46, y: -0.18, size: 22, delay: 0.12, opacity: 0.88),
        .init(id: "r2", x: 0.38, y: 0.24, size: 13, delay: 0.38, opacity: 0.50),
        .init(id: "r3", x: 0.50, y: 0.04, size: 17, delay: 0.62, opacity: 0.68),
    ]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ForEach(stars) { star in
                Image(systemName: "sparkle")
                    .font(.system(size: star.size, weight: .bold))
                    .foregroundStyle(starColor.opacity(star.opacity))
                    .position(
                        x: center.x + star.x * geo.size.width,
                        y: center.y + star.y * geo.size.height
                    )
                    .scaleEffect(pulse ? 1.14 : 0.82)
                    .opacity(pulse ? 1 : 0.55)
                    .rotationEffect(.degrees(pulse ? 8 : -8))
                    .animation(
                        .easeInOut(duration: 1.35)
                            .repeatForever(autoreverses: true)
                            .delay(star.delay),
                        value: pulse
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { pulse = true }
    }

    private var starColor: Color {
        colorScheme == .dark ? .white : .primary
    }
}

// MARK: - Confetti tombant (page offre)

private struct PaywallSpinFallingConfetti: View {
    private struct Piece: Identifiable {
        let id: Int
        let xRatio: CGFloat
        let size: CGFloat
        let colorIndex: Int
        let duration: Double
        let delay: Double
        let spin: Double
        let drift: CGFloat
    }

    private let palette: [Color] = [
        Color(red: 0.93, green: 0.82, blue: 0.38),
        Color(red: 0.55, green: 0.78, blue: 0.74),
        Color(red: 0.95, green: 0.42, blue: 0.48),
        Color(red: 0.98, green: 0.92, blue: 0.72),
        Color.white.opacity(0.85),
    ]

    private let pieces: [Piece] = [
        (0.06, 8, 0, 2.8, 0.0, 220, 18),
        (0.14, 10, 1, 3.1, 0.25, 180, -14),
        (0.22, 7, 2, 2.6, 0.55, 260, 22),
        (0.30, 9, 0, 3.4, 0.15, 200, -10),
        (0.38, 8, 3, 2.9, 0.75, 240, 16),
        (0.46, 11, 1, 3.2, 0.35, 170, -20),
        (0.54, 7, 2, 2.5, 0.95, 300, 12),
        (0.62, 9, 0, 3.6, 0.45, 210, -18),
        (0.70, 8, 4, 2.7, 0.10, 250, 24),
        (0.78, 10, 1, 3.0, 0.65, 190, -12),
        (0.86, 7, 2, 3.3, 0.85, 230, 15),
        (0.94, 9, 3, 2.8, 0.20, 280, -22),
        (0.10, 8, 0, 3.5, 1.10, 200, 10),
        (0.26, 11, 1, 2.4, 1.30, 260, -16),
        (0.42, 7, 2, 3.7, 0.50, 180, 20),
        (0.58, 9, 4, 2.6, 1.05, 300, -8),
        (0.74, 8, 0, 3.1, 0.70, 220, 14),
        (0.90, 10, 3, 2.9, 1.20, 250, -19),
        (0.18, 6, 1, 3.8, 0.40, 170, 11),
        (0.66, 8, 2, 2.5, 1.40, 290, -13),
    ].enumerated().map { index, spec in
        Piece(
            id: index,
            xRatio: spec.0,
            size: spec.1,
            colorIndex: spec.2,
            duration: spec.3,
            delay: spec.4,
            spin: spec.5,
            drift: spec.6
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(pieces) { piece in
                        let cycle = (elapsed + piece.delay)
                            .truncatingRemainder(dividingBy: piece.duration) / piece.duration
                        let y = -36 + cycle * (geo.size.height + 72)
                        let x = geo.size.width * piece.xRatio
                            + sin(cycle * .pi * 2) * piece.drift

                        Capsule()
                            .fill(palette[piece.colorIndex % palette.count])
                            .frame(width: piece.size * 0.45, height: piece.size)
                            .rotationEffect(.degrees(cycle * piece.spin))
                            .position(x: x, y: y)
                            .opacity(0.55 + (1 - cycle) * 0.35)
                            .blur(radius: cycle > 0.85 ? 0.6 : 0)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Confetti burst (roue)

private struct PaywallSpinConfetti: View {
    @State private var animate = false

    private let pieces: [(x: CGFloat, delay: Double, color: Color, size: CGFloat, spin: Double)] = [
        (0.08, 0.00, Color(red: 0.93, green: 0.82, blue: 0.38), 10, 180),
        (0.18, 0.03, Color(red: 0.55, green: 0.78, blue: 0.74), 8, 220),
        (0.28, 0.06, Color(red: 0.95, green: 0.42, blue: 0.48), 11, 160),
        (0.38, 0.02, Color(red: 0.98, green: 0.92, blue: 0.72), 7, 280),
        (0.48, 0.08, Color(red: 0.93, green: 0.82, blue: 0.38), 9, 200),
        (0.58, 0.04, Color(red: 0.55, green: 0.78, blue: 0.74), 10, 240),
        (0.68, 0.10, Color(red: 0.95, green: 0.42, blue: 0.48), 8, 190),
        (0.78, 0.05, Color(red: 0.93, green: 0.82, blue: 0.38), 11, 260),
        (0.88, 0.12, Color(red: 0.55, green: 0.78, blue: 0.74), 7, 210),
        (0.14, 0.16, Color(red: 0.95, green: 0.42, blue: 0.48), 9, 170),
        (0.34, 0.18, Color(red: 0.93, green: 0.82, blue: 0.38), 8, 300),
        (0.54, 0.14, Color(red: 0.98, green: 0.92, blue: 0.72), 10, 250),
        (0.72, 0.20, Color(red: 0.55, green: 0.78, blue: 0.74), 9, 270),
        (0.84, 0.22, Color(red: 0.95, green: 0.42, blue: 0.48), 8, 200),
        (0.24, 0.26, Color(red: 0.93, green: 0.82, blue: 0.38), 10, 230),
        (0.62, 0.28, Color(red: 0.55, green: 0.78, blue: 0.74), 7, 180),
        (0.42, 0.30, Color(red: 0.95, green: 0.42, blue: 0.48), 11, 290),
        (0.92, 0.24, Color(red: 0.98, green: 0.92, blue: 0.72), 8, 210),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                    Capsule()
                        .fill(piece.color)
                        .frame(width: piece.size * 0.48, height: piece.size)
                        .rotationEffect(.degrees(animate ? piece.spin : -20))
                        .position(
                            x: geo.size.width * piece.x,
                            y: animate ? geo.size.height * 0.95 : -30
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeIn(duration: 1.75).delay(piece.delay),
                            value: animate
                        )
                }
            }
        }
        .onAppear { animate = true }
        .allowsHitTesting(false)
    }
}

private struct PaywallSpinPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

#Preview {
    PaywallSpinWinbackView(onClaimed: {})
}
