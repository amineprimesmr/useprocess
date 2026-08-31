//
//  PaywallView.swift
//  useprocess
//
//  Paywall PRO — style Bevel (fond clair, features défilantes, cartes Mensuel / Annuel).
//

import SafariServices
import SwiftUI
import UIKit

struct PaywallView: View {
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var homeSwipeGate = ProcessPreAccessHomeSwipeCoordinator.shared

    let onComplete: (() -> Void)?
    /// Sortie sans achat (retour onboarding, ou dismiss si présenté en sheet).
    let onLeaveWithoutPurchase: (() -> Void)?
    /// Bloque la croix / swipe Home — paywall obligatoire après onboarding.
    let allowsLeaveWithoutPurchase: Bool
    private let analyticsSource: String

    /// Plan choisi dans le paywall (source de vérité unique).
    @State private var selectedBillingPlan: SubscriptionBillingPlan = .annual
    @State private var didSetInitialPlan = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseError: String?
    @State private var legalSafariURL: URL?
    @State private var showsPaywallLegalMenu = false
    @State private var showsReferralCodeSheet = false
    @State private var measuredTopSafeInset: CGFloat = 0
    @State private var continueShakeTicks: CGFloat = 0
    @State private var showsSpinWinback = false
    @State private var didPresentSpinWinback = false
    @State private var showsStayPopup = false
    @State private var lastHandledSwipeToken = 0
    @State private var didCompletePaywallFlow = false
    @State private var showsCloseXButton = false
    @State private var closeXAttemptCount = 0
    @State private var lastCloseXTapAt: Date?
    @State private var purchaseAttemptStartedAt: Date?
    @Bindable private var appLanguage = ProcessAppLanguage.shared
    private let termsURL = ProcessLegalURLs.termsOfUse
    private let privacyURL = ProcessLegalURLs.privacyPolicy

    init(
        onComplete: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        allowsLeaveWithoutPurchase: Bool = true,
        analyticsSource: String = "onboarding_or_paywall"
    ) {
        self.onComplete = onComplete
        self.allowsLeaveWithoutPurchase = allowsLeaveWithoutPurchase
        self.onLeaveWithoutPurchase = allowsLeaveWithoutPurchase ? onBack : nil
        self.analyticsSource = analyticsSource
    }

    private var pricingVariant: PaywallPricingExperiment.Variant {
        PaywallPricingExperiment.shared.activeVariant
    }

    private var shortBillingPlan: SubscriptionBillingPlan {
        pricingVariant.shortPlan
    }

    private var selectedPlanAvailableOnStore: Bool {
        subscriptionService.hasLiveProduct(for: selectedBillingPlan)
    }

    private var paywallRootTopPadding: CGFloat {
        measuredTopSafeInset + 4
    }

    var body: some View {
        ZStack {
            PaywallBevelBackdrop()

            VStack(spacing: 0) {
                // Croix toujours tappable pendant le pop (tap = fermer le pop, jamais la roue).
                topChrome

                VStack(spacing: 0) {
                    titleBlock
                        .padding(.horizontal, 24)
                        .padding(.top, -6)
                        .padding(.bottom, 14)

                    PaywallBevelAutoScrollingFeatures(
                        primary: PaywallBevelFeatureCatalog.primary,
                        alsoIncluded: PaywallBevelFeatureCatalog.alsoIncluded,
                        onNutritionSecretUnlock: activateDeveloperPremiumAccess
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .frame(maxHeight: .infinity)

                    bottomSection
                        .layoutPriority(1)
                }
                .allowsHitTesting(!showsStayPopup)
            }
            .id(appLanguage.code)
            .regularWidthContainer(maxWidth: AdaptiveScreenLayout.paywallMaxWidth)
            .padding(.top, paywallRootTopPadding)

            if showsStayPopup {
                PaywallStayRetentionOverlay(
                    onTryLuck: {
                        ProcessAnalytics.trackPaywallStayPopupAction("try_luck_spin")
                        dismissStayPopup()
                        presentSpinWinbackIfNeeded(force: true)
                    },
                    onStay: {
                        ProcessAnalytics.trackPaywallStayPopupAction("stay")
                        dismissStayPopup()
                    }
                )
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showsStayPopup)
        .alert(AppCopy.t("Achat", en: "Purchase"), isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button(AppCopy.t("OK", en: "OK"), role: .cancel) {}
        } message: {
            if let purchaseError { Text(purchaseError) }
        }
        .sheet(isPresented: Binding(
            get: { legalSafariURL != nil },
            set: { if !$0 { legalSafariURL = nil } }
        )) {
            if let url = legalSafariURL {
                PaywallInAppSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showsReferralCodeSheet) {
            PaywallReferralCodeSheet()
        }
        .task {
            await subscriptionService.loadSubscriptions()
            if !didSetInitialPlan {
                if subscriptionService.hasLiveAnnualProduct {
                    selectedBillingPlan = .annual
                } else if subscriptionService.hasLiveProduct(for: shortBillingPlan) {
                    selectedBillingPlan = shortBillingPlan
                }
                didSetInitialPlan = true
            }
            await subscriptionService.checkSubscriptionStatus()
            if subscriptionService.subscriptionStatus.isActive {
                completePaywallFlow()
            }
        }
        .onAppear {
            refreshMeasuredTopSafeInset()
            trackPaywallAppear()
            guard allowsLeaveWithoutPurchase else { return }
            Task {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.28)) {
                    showsCloseXButton = true
                }
            }
        }
        .onChange(of: subscriptionService.subscriptionStatus) { oldValue, newValue in
            if newValue.isActive && !oldValue.isActive {
                isPurchasing = false
                completePaywallFlow()
            }
        }
        .fullScreenCover(isPresented: $showsSpinWinback) {
            PaywallSpinWinbackView {
                showsSpinWinback = false
                if subscriptionService.subscriptionStatus.isActive {
                    completePaywallFlow()
                }
            }
            .interactiveDismissDisabled()
        }
        .interactiveDismissDisabled()
        .onAppear {
            homeSwipeGate.retentionSurface = .paywall
            lastHandledSwipeToken = homeSwipeGate.swipeToken
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                await ProcessMarketingNotificationService.shared.prepareNotificationPermissionIfNeeded()
            }
        }
        .onDisappear {
            if homeSwipeGate.retentionSurface == .paywall {
                homeSwipeGate.retentionSurface = .none
            }
            if !subscriptionService.subscriptionStatus.isActive {
                Task {
                    await ProcessMarketingNotificationService.shared.startAfterPaywallDropoff(
                        sawSpin: didPresentSpinWinback,
                        reason: "paywall_disappear"
                    )
                }
            }
        }
        .onChange(of: showsSpinWinback) { _, isPresented in
            homeSwipeGate.retentionSurface = isPresented ? .spinWinback : .paywall
        }
        .onChange(of: selectedBillingPlan) { _, plan in
            ProcessAnalytics.trackPaywallPlanSelected(plan: plan.rawValue, source: "paywall")
        }
        .onChange(of: showsStayPopup) { _, isShowing in
            if isShowing {
                ProcessAnalytics.trackPaywallStayPopupShown(trigger: "home_swipe_or_close")
            }
        }
        .onChange(of: homeSwipeGate.swipeToken) { _, token in
            guard token != lastHandledSwipeToken else { return }
            lastHandledSwipeToken = token
            handleDeferredHomeSwipe()
        }
    }

    private func handleDeferredHomeSwipe() {
        guard allowsLeaveWithoutPurchase else { return }
        // Swipe Home → pop rétention (indépendant de la croix).
        guard homeSwipeGate.shouldShowPaywallStayPopup else { return }
        guard !showsSpinWinback, !showsStayPopup else { return }
        ProcessAnalytics.trackPaywallCloseTapped(source: "home_swipe")
        presentStayRetentionPopup()
    }

    func completePaywallFlow() {
        guard !didCompletePaywallFlow else { return }
        didCompletePaywallFlow = true
        if subscriptionService.subscriptionStatus.isActive {
            ProcessMarketingNotificationService.shared.cancelAll()
        } else {
            Task {
                await ProcessMarketingNotificationService.shared.startAfterPaywallDropoff(
                    sawSpin: didPresentSpinWinback,
                    reason: "paywall_completed_unpaid"
                )
            }
        }
        if let onComplete {
            onComplete()
        } else {
            dismiss()
        }
    }

    private func trackPaywallAppear() {
        ProcessAnalytics.trackPaywallViewed(source: analyticsSource)
    }

    // MARK: - Header

    private var topChrome: some View {
        HStack {
            Button {
                HapticManager.shared.impact(.light)
                showsPaywallLegalMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.28))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.processPlain)
            .accessibilityLabel(OnboardingCopy.t(
                "Options et informations légales",
                en: "Options and legal information"
            ))
            .popover(isPresented: $showsPaywallLegalMenu, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                paywallLegalMenuPopover
                    .presentationCompactAdaptation(.popover)
            }

            Spacer(minLength: 0)

            if allowsLeaveWithoutPurchase {
                Button {
                    handlePaywallCloseAttempt(source: "xmark")
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 36, height: 36)
                }
                .processGlassIconButtonStyle()
                .opacity(showsCloseXButton ? 1 : 0)
                .allowsHitTesting(showsCloseXButton)
                .accessibilityHidden(!showsCloseXButton)
                .accessibilityLabel(OnboardingCopy.t("Fermer", en: "Close"))
            }
        }
        .padding(.horizontal, 18)
    }

    /// Croix : 1er tap = shake CTA. 2e tap = pop « Attends ! ». 3e tap = sortie réelle.
    /// Jamais la roue depuis la croix (via « Tente ta chance »).
    private func handlePaywallCloseAttempt(source: String) {
        ProcessAnalytics.trackPaywallCloseTapped(source: source)
        guard !showsSpinWinback else { return }

        if showsStayPopup {
            dismissStayPopup()
            leavePaywallWithoutPurchase()
            return
        }

        // Anti double-fire (bouton glass iOS 26) — un seul compte par geste.
        let now = Date()
        if let lastCloseXTapAt, now.timeIntervalSince(lastCloseXTapAt) < 0.40 {
            return
        }
        lastCloseXTapAt = now

        closeXAttemptCount += 1
        switch closeXAttemptCount {
        case 1:
            shakeContinueButton()
        case 2:
            presentStayRetentionPopup()
        default:
            leavePaywallWithoutPurchase()
        }
    }

    /// Sortie sans achat — ne passe jamais par `onComplete` (page « Merci, Pro activé »).
    private func leavePaywallWithoutPurchase() {
        ProcessAnalytics.trackPaywallCloseTapped(source: "xmark_exit")
        if let onLeaveWithoutPurchase {
            onLeaveWithoutPurchase()
        } else {
            dismiss()
        }
    }

    private func presentStayRetentionPopup() {
        guard !showsStayPopup, !showsSpinWinback else { return }
        HapticManager.shared.notification(.warning)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            showsStayPopup = true
        }
    }

    private func dismissStayPopup() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            showsStayPopup = false
        }
    }

    private func shakeContinueButton() {
        HapticManager.shared.notification(.warning)
        withAnimation(.default) {
            continueShakeTicks += 1
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            if let result = FaceScanHistoryStore.shared.latestResult {
                PaywallFaceScanHero(
                    result: result,
                    onDeveloperUnlock: activateDeveloperPremiumAccess
                )
                .padding(.bottom, 2)
            }

            VStack(spacing: 10) {
                paywallHeroProTitle

                Text(paywallCommunitySubtitle)
                    .font(PaywallBevelTheme.paywallHeroSubtitleFont())
                    .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var paywallHeroProTitle: some View {
        let prefix = OnboardingCopy.t(
            "Débloque ton plan personnalisé avec ",
            en: "Unlock your personalized plan with "
        )

        // « Pro » en Text séparé pour le double-tap DEBUG (débloque l’app).
        return (
            Text(prefix)
                .foregroundStyle(PaywallBevelTheme.paywallTitleColor(for: colorScheme))
            + Text("Pro")
                .foregroundStyle(PaywallBevelTheme.paywallProTitleGradient(for: colorScheme))
        )
        .font(PaywallBevelTheme.paywallHeroTitleFont(size: 31))
        .tracking(PaywallBevelTheme.paywallHeroTitleTracking)
        .multilineTextAlignment(.center)
        .lineSpacing(1)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        #if DEBUG
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            activateDeveloperPremiumAccess()
        }
        .accessibilityLabel("Developer premium unlock")
        .accessibilityAddTraits(.isButton)
        #endif
    }

    private var paywallCommunitySubtitle: String {
        OnboardingCopy.t(
            "Rejoins +\(TransformationCaseStudyCatalog.transformedPeopleCount) personnes qui ont déjà dégonflés leur visage avec Process.",
            en: "Join +\(TransformationCaseStudyCatalog.transformedPeopleCount) people who already debloated their face with Process."
        )
    }

    // MARK: - Bas (forfaits + CTA)

    private var bottomSection: some View {
        VStack(spacing: 12) {
            PaywallBevelPlanSegmentPicker(
                selection: $selectedBillingPlan,
                shortPlan: shortBillingPlan,
                annualComparePrice: subscriptionService.displayProduct(for: shortBillingPlan)
                    .paywallAnnualStrikethroughComparePrice,
                annualPrice: annualPrimaryPrice,
                shortPlanPrice: shortPlanPrimaryPrice,
                annualOfferBadge: nil
            )

            PaywallBevelContinueButton(
                title: paywallContinueButtonTitle,
                isLoading: isPurchasing,
                isEnabled: paywallContinueButtonEnabled
            ) {
                Task { await purchaseSubscription() }
            }
            .modifier(PaywallContinueShakeEffect(shakes: continueShakeTicks))

            Text(paywallContinueSubtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.top, 2)

            if !subscriptionService.isLoading, !selectedPlanAvailableOnStore {
                Text(OnboardingCopy.t(
                    "Cette offre n'est pas encore disponible sur l'App Store. Réessayez dans quelques minutes.",
                    en: "This offer isn’t available on the App Store yet. Try again in a few minutes."
                ))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .padding(.top, 2)
    }

    // MARK: - Prix

    private var annualPrimaryPrice: String {
        subscriptionService.displayProduct(for: .annual).paywallPrimaryAnnualPriceLabel
    }

    private var shortPlanPrimaryPrice: String {
        let display = subscriptionService.displayProduct(for: shortBillingPlan)
        return display.paywallShortPlanPriceLabel(for: shortBillingPlan)
    }

    private var paywallContinueButtonTitle: String {
        OnboardingCopy.t("Continuer, aucun engagement.", en: "Continue — no commitment.")
    }

    private var paywallContinueSubtitle: String {
        OnboardingCopy.t(
            "Sans engagement, annulable à tout moment.",
            en: "No commitment — cancel anytime."
        )
    }

    private var paywallContinueButtonEnabled: Bool {
        selectedPlanAvailableOnStore && !subscriptionService.isLoading && !isPurchasing
    }

    private func refreshMeasuredTopSafeInset() {
        measuredTopSafeInset = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
    }

    // MARK: - Menu légal

    private var paywallLegalMenuPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            paywallLegalMenuRow(
                symbol: "hand.raised",
                title: OnboardingCopy.t("Politique de confidentialité", en: "Privacy Policy")
            ) {
                showsPaywallLegalMenu = false
                legalSafariURL = privacyURL
            }
            paywallLegalMenuRow(
                symbol: "doc.text",
                title: OnboardingCopy.t("Conditions (EULA)", en: "Terms (EULA)")
            ) {
                showsPaywallLegalMenu = false
                legalSafariURL = termsURL
            }
            Divider().padding(.horizontal, 12).padding(.vertical, 4)
            paywallLegalMenuRow(
                symbol: "arrow.clockwise",
                title: OnboardingCopy.t("Restaurer", en: "Restore")
            ) {
                showsPaywallLegalMenu = false
                Task { await restorePurchases() }
            }
            paywallLegalMenuRow(
                symbol: "gift",
                title: OnboardingCopy.t("Code de parrainage", en: "Referral code")
            ) {
                showsPaywallLegalMenu = false
                showsReferralCodeSheet = true
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 248, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func paywallLegalMenuRow(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.72))
                    .frame(width: 22, alignment: .center)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.processPlain)
        .disabled(
            (title == OnboardingCopy.t("Restaurer", en: "Restore"))
                && (isRestoring || isPurchasing)
        )
    }

    // MARK: - Achat

    @MainActor
    private func purchaseSubscription() async {
        if !subscriptionService.canPurchase {
            await subscriptionService.loadSubscriptions()
            guard subscriptionService.canPurchase else {
                purchaseError = OnboardingCopy.t(
                    "Les offres ne sont pas encore chargées. Réessayez dans quelques instants.",
                    en: "Offers aren’t loaded yet. Try again in a moment."
                )
                return
            }
        }

        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        let plan = selectedBillingPlan.rawValue
        let offer = "standard"
        ProcessAnalytics.trackPaywallCTATapped(plan: plan, source: "paywall")
        ProcessAnalytics.trackPurchaseStarted(plan: plan, offer: offer, source: "paywall")
        purchaseAttemptStartedAt = Date()

        do {
            try await subscriptionService.purchase(plan: selectedBillingPlan)
            await subscriptionService.checkSubscriptionStatus()
            if subscriptionService.subscriptionStatus.isActive {
                ProcessAnalytics.trackPurchaseCompleted(plan: plan, offer: offer, source: "paywall")
                ProcessMarketingNotificationService.shared.handlePurchaseSuccess(plan: plan)
                completePaywallFlow()
            }
        } catch SubscriptionError.userCancelled {
            ProcessAnalytics.trackPurchaseCancelled(
                plan: plan,
                offer: offer,
                source: "paywall",
                priceDisplayed: subscriptionService.displayProduct(for: selectedBillingPlan).displayPrice,
                secondsSinceStarted: purchaseAttemptStartedAt.map { Date().timeIntervalSince($0) }
            )
            presentSpinWinbackIfNeeded()
            Task {
                await ProcessMarketingNotificationService.shared.startAfterPaywallDropoff(
                    sawSpin: true,
                    reason: "purchase_cancelled"
                )
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            ProcessAnalytics.trackPurchaseFailed(
                plan: plan,
                error: message,
                offer: offer,
                source: "paywall"
            )
            purchaseError = message
        }
    }

    private func presentSpinWinbackIfNeeded(force: Bool = false) {
        if didPresentSpinWinback, !force {
            shakeContinueButton()
            return
        }
        if didPresentSpinWinback, force {
            ProcessMarketingNotificationService.shared.markSawSpinWheel()
            ProcessAnalytics.capture("spin_wheel_presented", properties: [
                "source": "stay_popup_or_retry",
                "force": true
            ])
            showsSpinWinback = true
            return
        }
        didPresentSpinWinback = true
        ProcessMarketingNotificationService.shared.markSawSpinWheel()
        ProcessAnalytics.capture("spin_wheel_presented", properties: [
            "source": "purchase_cancelled",
            "force": false
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            showsSpinWinback = true
        }
    }

    @MainActor
    private func restorePurchases() async {
        isRestoring = true
        purchaseError = nil
        defer { isRestoring = false }

        ProcessAnalytics.trackRestoreStarted(source: "paywall")
        do {
            try await subscriptionService.restorePurchases()
            let active = subscriptionService.subscriptionStatus.isActive
            ProcessAnalytics.trackRestoreCompleted(isActive: active)
            if active {
                completePaywallFlow()
            } else {
                purchaseError = OnboardingCopy.t(
                    "Aucun abonnement actif trouvé.",
                    en: "No active subscription found."
                )
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            ProcessAnalytics.trackRestoreFailed(error: message, source: "paywall")
            purchaseError = message
        }
    }

    private func activateDeveloperPremiumAccess() {
        #if DEBUG
        HapticManager.shared.notification(.success)
        subscriptionService.activateDeveloperPremiumAccess()
        ProcessMarketingNotificationService.shared.cancelAll()
        completePaywallFlow()
        #endif
    }
}

// MARK: - Code parrainage (fallback paywall)

private struct PaywallReferralCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var draftCode = ""
    @State private var isSubmitting = false
    @State private var feedback: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(OnboardingCopy.t(
                    "Code affilié Process = accès à vie.",
                    en: "Process affiliate code = lifetime access."
                ))
                .font(.system(size: 15))
                .foregroundStyle(OnboardingTheme.bodyText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 20)

                TextField(
                    "",
                    text: $draftCode,
                    prompt: Text(OnboardingCopy.t("Ex. K7X2M", en: "e.g. K7X2M"))
                        .foregroundStyle(OnboardingTheme.mutedText)
                )
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { Task { await applyCode() } }
                .onChange(of: draftCode) { _, newValue in
                    let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                    draftCode = String(filtered.prefix(ProcessReferralCode.length))
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)

                if let feedback {
                    Text(feedback)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(OnboardingTheme.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                }

                Spacer(minLength: 0)

                Button {
                    Task { await applyCode() }
                } label: {
                    Text(OnboardingCopy.t("Utiliser", en: "Apply"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .onboardingPrimaryActionStyle()
                .disabled(!ProcessReferralCode.isValid(normalizedCode) || isSubmitting)
                .opacity(!ProcessReferralCode.isValid(normalizedCode) || isSubmitting ? 0.45 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle(OnboardingCopy.t("Code de parrainage", en: "Referral code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(OnboardingCopy.t("Fermer", en: "Close")) { dismiss() }
                }
            }
        }
        .onAppear {
            if let pending = ProcessReferralAttribution.pendingCode ?? ProcessAffiliateAttribution.pendingCode {
                draftCode = pending
            }
            isFocused = true
        }
    }

    private var normalizedCode: String {
        ProcessReferralCode.normalize(draftCode)
    }

    @MainActor
    private func applyCode() async {
        let normalized = ProcessReferralCode.normalize(draftCode)
        guard ProcessReferralCode.isValid(normalized) else { return }

        // Lifetime affiliés — local only, never hit Firebase resolve.
        if ProcessAffiliateLifetimePass.matches(normalized)
            || normalized == ProcessAffiliateLifetimePass.code {
            isSubmitting = true
            defer { isSubmitting = false }
            await applyAffiliateLifetimePassAndDismiss()
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let resolved = await AffiliateService.shared.resolveCode(normalized)
        if ProcessAffiliateLifetimePass.matches(normalized)
            || normalized == ProcessAffiliateLifetimePass.code {
            await applyAffiliateLifetimePassAndDismiss()
            return
        }

        let canUnlockWithoutNetwork = !FirebaseBootstrap.isConfigured
            || ClaudeConfiguration.functionsBaseURL == nil

        if resolved == nil, !canUnlockWithoutNetwork {
            feedback = OnboardingCopy.t(
                "Code introuvable. Vérifie et réessaie.",
                en: "Code not found. Check and try again."
            )
            HapticManager.shared.notification(.error)
            return
        }

        ProcessAcquisitionAttribution.captureReferralCode(normalized, source: "paywall", medium: "referral")
        ProcessAcquisitionAttribution.captureAffiliateCode(normalized, source: "paywall", medium: "creator")
        ProcessReferralAttribution.rememberManualEntry(normalized)
        ProcessAnalytics.trackReferralCodeApplied(source: "paywall_menu")

        let userId = UnifiedProfileService.shared.currentProfile?.userId
            ?? UserScopedStorage.currentUserId()
        let displayName = UnifiedProfileService.shared.currentProfile?.firstName

        if let userId {
            await AcquisitionCodeService.registerIfPresent(
                code: normalized,
                referredUserId: userId,
                displayName: displayName
            )
            ProcessReferralAttribution.clearPending()
            ProcessAffiliateAttribution.clearPending()
        }

        HapticManager.shared.notification(.success)
        await SubscriptionService.shared.loadSubscriptions()
        feedback = OnboardingCopy.t(
            "Code appliqué.",
            en: "Code applied."
        )
        try? await Task.sleep(for: .milliseconds(650))
        dismiss()
    }

    @MainActor
    private func applyAffiliateLifetimePassAndDismiss() async {
        ProcessAffiliateLifetimePass.unlock()
        await SubscriptionService.shared.checkSubscriptionStatus()
        // Re-applique après le refresh RC — `applyCustomerInfo` peut repasser brièvement en notSubscribed.
        SubscriptionService.shared.activateAffiliateLifetimePass()
        guard SubscriptionService.shared.subscriptionStatus.isActive else {
            feedback = OnboardingCopy.t(
                "Impossible d’activer l’accès. Réessaie.",
                en: "Couldn’t unlock access. Try again."
            )
            HapticManager.shared.notification(.error)
            return
        }
        HapticManager.shared.notification(.success)
        feedback = OnboardingCopy.t(
            "Accès offert à vie. Bienvenue.",
            en: "Lifetime access unlocked. Welcome."
        )
        try? await Task.sleep(for: .milliseconds(650))
        dismiss()
    }
}

private struct PaywallStayRetentionOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let onTryLuck: () -> Void
    let onStay: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.48 : 0)
                .ignoresSafeArea()
                .onTapGesture { onStay() }

            VStack(spacing: 18) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(red: 0.98, green: 0.48, blue: 0.36))
                    .padding(.top, 4)

                Text(OnboardingCopy.t("Attends !", en: "Wait!"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)

                Text(OnboardingCopy.t(
                    "Ne pars pas maintenant.\nTente ta chance — une offre exclusive t’attend.",
                    en: "Don’t leave yet.\nTry your luck — an exclusive offer is waiting."
                ))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(OnboardingTheme.bodyText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onTryLuck) {
                    Text(OnboardingCopy.t("Tente ta chance", en: "Try your luck"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.92 : 0.94))
                        }
                }
                .buttonStyle(.processPlain)
                .padding(.top, 4)

                Button(action: onStay) {
                    Text(OnboardingCopy.t("Rester sur l’offre", en: "Stay on this offer"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.processPlain)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: 340)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 28, y: 14)
            }
            .padding(.horizontal, 28)
            .scaleEffect(appeared ? 1 : 0.88)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }
}

// MARK: - Shake CTA (croix paywall)

private struct PaywallContinueShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(shakes * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

// MARK: - Aperçu scan visage

struct PaywallFaceScanHero: View {
    let result: FaceScanResult
    var onDeveloperUnlock: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var resolvedVideoURL: URL?
    @State private var resolvedSnapshot: UIImage?
    @State private var mediaRefreshToken = 0
    @State private var animatedProgress: Double = 0

    private let ringSize: CGFloat = 168
    private let strokeWidth: CGFloat = 5

    private var innerDiameter: CGFloat {
        ringSize - strokeWidth * 2 - 6
    }

    private var displayScore: Int {
        result.displayWellnessScore
    }

    private var scoreZone: FaceScanIndicators.WellnessZone {
        FaceScanIndicators.compositeWellnessZone(for: result)
    }

    private var ringProgressColor: Color {
        FaceScanWhoopPalette.ringColor(for: scoreZone)
    }

    var body: some View {
        ZStack {
            mediaContent
                .frame(width: innerDiameter, height: innerDiameter)
                .clipShape(Circle())

            Circle()
                .stroke(FaceScanWhoopPalette.ringTrack, lineWidth: strokeWidth)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    ringProgressColor,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
        }
        .frame(width: ringSize, height: ringSize)
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12),
            radius: 16,
            y: 7
        )
        .contentShape(Circle())
        #if DEBUG
        .onTapGesture(count: 2) {
            onDeveloperUnlock?()
        }
        #endif
        .id("\(result.id)-paywall-\(mediaRefreshToken)")
        .onAppear {
            refreshMedia()
            animatedProgress = 0
            withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) {
                animatedProgress = Double(displayScore) / 100.0
            }
        }
        .onChange(of: result.id) { _, _ in
            refreshMedia()
            animatedProgress = 0
            withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) {
                animatedProgress = Double(displayScore) / 100.0
            }
        }
        .onChange(of: result.videoFilename) { _, _ in refreshMedia() }
        .onChange(of: result.snapshotFilename) { _, _ in refreshMedia() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshMedia()
        }
        .task(id: result.id) {
            await resolveVideoWithRetry()
        }
        .accessibilityLabel(AppCopy.t("Score visage \(displayScore) pour cent", en: "Face score \(displayScore) percent"))
    }

    @ViewBuilder
    private var mediaContent: some View {
        if let url = resolvedVideoURL {
            FaceScanSilentVideoLoopView(url: url)
        } else if let image = resolvedSnapshot {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(Color.primary.opacity(0.06))
                .overlay {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func refreshMedia() {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
        resolvedVideoURL = FaceScanImageStore.resolvedVideoURL(for: reconciled)
        if let filename = FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) {
            resolvedSnapshot = FaceScanImageStore.load(filename: filename)
        } else {
            resolvedSnapshot = nil
        }
        if resolvedVideoURL == nil, resolvedSnapshot == nil {
            mediaRefreshToken &+= 1
        }
    }

    private func resolveVideoWithRetry() async {
        for _ in 0..<24 {
            let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
            if let url = FaceScanImageStore.resolvedVideoURL(for: reconciled) {
                resolvedVideoURL = url
                return
            }
            try? await Task.sleep(for: .milliseconds(180))
        }
    }
}

// MARK: - Safari in-app

struct PaywallInAppSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview("Clair") {
    PaywallView()
        .preferredColorScheme(.light)
}

#Preview("Sombre") {
    PaywallView()
        .preferredColorScheme(.dark)
}
