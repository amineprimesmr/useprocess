//
//  PaywallView.swift
//  useprocess
//
//  Paywall PRO — style Bevel (fond clair, features défilantes, cartes Mensuel / Annuel).
//

import SafariServices
import StoreKit
import SwiftUI
import UIKit

struct PaywallView: View {
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var homeSwipeGate = ProcessPreAccessHomeSwipeCoordinator.shared

    let onComplete: (() -> Void)?

    /// Plan choisi dans le paywall (source de vérité unique).
    @State private var selectedBillingPlan: SubscriptionBillingPlan = .annual
    @State private var didSetInitialPlan = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseError: String?
    @State private var legalSafariURL: URL?
    @State private var showsPaywallLegalMenu = false
    @State private var measuredTopSafeInset: CGFloat = 0
    @State private var continueShakeTicks: CGFloat = 0
    @State private var showsSpinWinback = false
    @State private var didPresentSpinWinback = false
    @State private var showsStayPopup = false
    @State private var lastHandledSwipeToken = 0
    private let termsURL = ProcessLegalURLs.termsOfUse
    private let privacyURL = ProcessLegalURLs.privacyPolicy

    init(onComplete: (() -> Void)? = nil, onBack: (() -> Void)? = nil) {
        self.onComplete = onComplete
        _ = onBack
    }

    private var selectedPlanAvailableOnStore: Bool {
        switch selectedBillingPlan {
        case .annual: subscriptionService.hasLiveAnnualProduct
        case .monthly: subscriptionService.hasLiveMonthlyProduct
        }
    }

    private var paywallRootTopPadding: CGFloat {
        measuredTopSafeInset + 4
    }

    var body: some View {
        ZStack {
            PaywallBevelBackdrop()

            VStack(spacing: 0) {
                topChrome

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
                .layoutPriority(1)

                bottomSection
            }
            .regularWidthContainer(maxWidth: AdaptiveScreenLayout.paywallMaxWidth)
            .padding(.top, paywallRootTopPadding)
            .allowsHitTesting(!showsStayPopup)

            if showsStayPopup {
                PaywallStayRetentionOverlay(
                    onTryLuck: {
                        dismissStayPopup()
                        presentSpinWinbackIfNeeded(force: true)
                    },
                    onStay: {
                        dismissStayPopup()
                    }
                )
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showsStayPopup)
        .alert("Achat", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) {}
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
        .task {
            await subscriptionService.loadSubscriptions()
            if !didSetInitialPlan {
                if subscriptionService.hasLiveAnnualProduct {
                    selectedBillingPlan = .annual
                } else if subscriptionService.hasLiveMonthlyProduct {
                    selectedBillingPlan = .monthly
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
                completePaywallFlow()
            }
            .interactiveDismissDisabled()
        }
        .interactiveDismissDisabled()
        .onAppear {
            homeSwipeGate.retentionSurface = .paywall
            lastHandledSwipeToken = homeSwipeGate.swipeToken
        }
        .onDisappear {
            if homeSwipeGate.retentionSurface == .paywall {
                homeSwipeGate.retentionSurface = .none
            }
        }
        .onChange(of: showsSpinWinback) { _, isPresented in
            homeSwipeGate.retentionSurface = isPresented ? .spinWinback : .paywall
        }
        .onChange(of: homeSwipeGate.swipeToken) { _, token in
            guard token != lastHandledSwipeToken else { return }
            lastHandledSwipeToken = token
            handleDeferredHomeSwipe()
        }
    }

    private func handleDeferredHomeSwipe() {
        // 1er swipe Home uniquement → pop rétention (gate global pré-accès).
        guard homeSwipeGate.shouldShowPaywallStayPopup else { return }
        guard !showsSpinWinback, !showsStayPopup else { return }
        HapticManager.shared.notification(.warning)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            showsStayPopup = true
        }
        shakeContinueButton()
    }

    func completePaywallFlow() {
        if let onComplete {
            onComplete()
        } else {
            dismiss()
        }
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
            .buttonStyle(.plain)
            .accessibilityLabel("Options et informations légales")
            .popover(isPresented: $showsPaywallLegalMenu, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                paywallLegalMenuPopover
                    .presentationCompactAdaptation(.popover)
            }

            Spacer(minLength: 0)

            Button {
                shakeContinueButton()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 36, height: 36)
            }
            .processGlassIconButtonStyle()
            .accessibilityLabel("Fermer")
        }
        .padding(.horizontal, 18)
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
                (
                    Text("Débloque ton plan personnalisé avec ")
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

    private var paywallCommunitySubtitle: String {
        "Rejoins +\(TransformationCaseStudyCatalog.transformedPeopleCount) personnes qui ont déjà dégonflés leur visage avec Process."
    }

    // MARK: - Bas (forfaits + CTA)

    private var bottomSection: some View {
        VStack(spacing: 12) {
            PaywallBevelPlanSegmentPicker(
                selection: $selectedBillingPlan,
                annualComparePrice: subscriptionService.displayProduct(for: .monthly).paywallAnnualStrikethroughComparePrice,
                annualPrice: annualPrimaryPrice,
                monthlyPrice: monthlyPrimaryPrice
            )

            PaywallBevelContinueButton(
                title: paywallContinueButtonTitle,
                isLoading: isPurchasing,
                isEnabled: paywallContinueButtonEnabled
            ) {
                Task { await purchaseSubscription() }
            }
            .modifier(PaywallContinueShakeEffect(shakes: continueShakeTicks))

            Text("Sans engagement, annulable à tout moment.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.top, 2)

            if !subscriptionService.isLoading, !selectedPlanAvailableOnStore {
                Text("Cette offre n'est pas encore disponible sur l'App Store. Réessayez dans quelques minutes.")
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
        subscriptionService.displayProduct(for: .annual).paywallPrimaryMonthlyPriceLabel
    }

    private var monthlyPrimaryPrice: String {
        subscriptionService.displayProduct(for: .monthly).paywallPrimaryMonthlyPriceLabel
    }

    private var paywallContinueButtonTitle: String {
        "Continuer, aucun engagement."
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
            paywallLegalMenuRow(symbol: "hand.raised", title: "Politique de confidentialité") {
                showsPaywallLegalMenu = false
                legalSafariURL = privacyURL
            }
            paywallLegalMenuRow(symbol: "doc.text", title: "Conditions (EULA)") {
                showsPaywallLegalMenu = false
                legalSafariURL = termsURL
            }
            Divider().padding(.horizontal, 12).padding(.vertical, 4)
            paywallLegalMenuRow(symbol: "arrow.clockwise", title: "Restaurer") {
                showsPaywallLegalMenu = false
                Task { await restorePurchases() }
            }
            paywallLegalMenuRow(symbol: "tag", title: "Code promo Apple") {
                showsPaywallLegalMenu = false
                presentCodeRedemption()
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
        .buttonStyle(.plain)
        .disabled(title == "Restaurer" && (isRestoring || isPurchasing))
    }

    // MARK: - Achat

    @MainActor
    private func purchaseSubscription() async {
        if !subscriptionService.canPurchase {
            await subscriptionService.loadSubscriptions()
            guard subscriptionService.canPurchase else {
                purchaseError = "Les offres ne sont pas encore chargées. Réessayez dans quelques instants."
                return
            }
        }

        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            try await subscriptionService.purchase(plan: selectedBillingPlan)
            await subscriptionService.checkSubscriptionStatus()
            if subscriptionService.subscriptionStatus.isActive {
                completePaywallFlow()
            }
        } catch SubscriptionError.userCancelled {
            presentSpinWinbackIfNeeded()
        } catch {
            purchaseError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func presentSpinWinbackIfNeeded(force: Bool = false) {
        if didPresentSpinWinback, !force {
            shakeContinueButton()
            return
        }
        if didPresentSpinWinback, force {
            showsSpinWinback = true
            return
        }
        didPresentSpinWinback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            showsSpinWinback = true
        }
    }

    @MainActor
    private func restorePurchases() async {
        isRestoring = true
        purchaseError = nil
        defer { isRestoring = false }

        do {
            try await subscriptionService.restorePurchases()
            if subscriptionService.subscriptionStatus.isActive {
                completePaywallFlow()
            } else {
                purchaseError = "Aucun abonnement actif trouvé."
            }
        } catch {
            purchaseError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func presentCodeRedemption() {
        Task {
            do {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
                } else {
                    purchaseError = "Impossible d'ouvrir la page de code promo."
                }
            } catch {
                purchaseError = "Impossible d'ouvrir la page de code promo."
            }
        }
    }

    private func activateDeveloperPremiumAccess() {
        #if DEBUG
        HapticManager.shared.notification(.success)
        subscriptionService.activateDeveloperPremiumAccess()
        completePaywallFlow()
        #endif
    }
}

// MARK: - Pop rétention (double sortie)

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

                Text("Attends !")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)

                Text("Ne pars pas maintenant.\nTente ta chance — une offre exclusive t’attend.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(OnboardingTheme.bodyText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onTryLuck) {
                    Text("Tente ta chance")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.92 : 0.94))
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                Button(action: onStay) {
                    Text("Rester sur l’offre")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                }
                .buttonStyle(.plain)
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
        .accessibilityLabel("Score visage \(displayScore) pour cent")
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

private struct PaywallInAppSafariView: UIViewControllerRepresentable {
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
