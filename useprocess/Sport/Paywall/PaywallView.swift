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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

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
    @State private var hasScheduledExitNotification = false

    private let termsURL = ProcessLegalURLs.termsOfUse
    private let privacyURL = ProcessLegalURLs.privacyPolicy

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
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
                    .padding(.top, 6)
                    .padding(.bottom, 18)

                PaywallBevelAutoScrollingFeatures(
                    primary: PaywallBevelFeatureCatalog.primary,
                    alsoIncluded: PaywallBevelFeatureCatalog.alsoIncluded
                )
                .padding(.top, 4)
                .padding(.bottom, 12)
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

                bottomSection
            }
            .regularWidthContainer(maxWidth: AdaptiveScreenLayout.paywallMaxWidth)
            .padding(.top, paywallRootTopPadding)
        }
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
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .active && (newPhase == .background || newPhase == .inactive) {
                scheduleExitNotificationIfNeeded()
            }
        }
        .onDisappear {
            scheduleExitNotificationIfNeeded()
        }
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
            Spacer(minLength: 0)

            Button {
                HapticManager.shared.impact(.light)
                showsPaywallLegalMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .processGlassCircle()
            .buttonStyle(ProcessGlassPressStyle())
            .accessibilityLabel("Options et informations légales")
            .popover(isPresented: $showsPaywallLegalMenu, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                paywallLegalMenuPopover
                    .presentationCompactAdaptation(.popover)
            }
        }
        .padding(.horizontal, 18)
    }

    private var titleBlock: some View {
        Text(paywallTitleText)
            .font(PaywallBevelTheme.paywallTitleFont())
            .foregroundStyle(PaywallBevelTheme.paywallTitleColor(for: colorScheme))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private var paywallTitleText: String {
        switch selectedBillingPlan {
        case .annual:
            if subscriptionService.trialInfo(for: .annual).isActiveOffer {
                return "3 jours gratuits sur l'offre annuelle"
            }
            return "Choisissez l'offre annuelle"
        case .monthly:
            return "Abonnement mensuel sans essai"
        }
    }

    // MARK: - Bas (forfaits + CTA)

    private var bottomSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                PaywallBevelPlanCard(
                    title: "Annuel",
                    primaryPrice: annualPrimaryPrice,
                    secondaryPrice: annualSecondaryPrice,
                    isSelected: selectedBillingPlan == .annual,
                    savingsBadge: annualSavingsBadge
                ) {
                    selectAnnualPlan()
                }
                PaywallBevelPlanCard(
                    title: "Mensuel",
                    primaryPrice: monthlyPrimaryPrice,
                    secondaryPrice: monthlySecondaryPrice,
                    isSelected: selectedBillingPlan == .monthly,
                    savingsBadge: nil
                ) {
                    selectMonthlyPlan()
                }
            }

            PaywallBevelContinueButton(
                title: paywallContinueButtonTitle,
                isLoading: isPurchasing,
                isEnabled: paywallContinueButtonEnabled
            ) {
                Task { await purchaseSubscription() }
            }
            .padding(.top, -4)

            if selectedTrialInfo.isActiveOffer {
                Text("Aucun paiement aujourd'hui, sans engagement.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                    .multilineTextAlignment(.center)
            }

            if !subscriptionService.isLoading, !selectedPlanAvailableOnStore {
                Text("Cette offre n'est pas encore disponible sur l'App Store. Réessayez dans quelques minutes.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            paywallSubscriptionLegalFooter

            #if DEBUG
            paywallDemoAccessButton
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .padding(.top, 2)
    }

    // MARK: - Prix

    private var annualPrimaryPrice: String {
        let raw = normalizePrice(subscriptionService.displayProduct(for: .annual).displayPrice)
        return "\(raw)/an"
    }

    private var selectedTrialInfo: SubscriptionTrialInfo {
        subscriptionService.trialInfo(for: selectedBillingPlan)
    }

    private var monthlyPrimaryPrice: String {
        let raw = normalizePrice(subscriptionService.displayProduct(for: .monthly).displayPrice)
        return "\(raw)/mois"
    }

    private var annualSecondaryPrice: String {
        subscriptionService.trialInfo(for: .annual).cardSecondaryPrice(
            for: .annual,
            annualMonthlyEquivalent: annualMonthlyEquivalentPrice
        )
    }

    private var monthlySecondaryPrice: String {
        subscriptionService.trialInfo(for: .monthly).cardSecondaryPrice(
            for: .monthly,
            annualMonthlyEquivalent: annualMonthlyEquivalentPrice
        )
    }

    private var annualMonthlyEquivalentPrice: String {
        let display = subscriptionService.displayProduct(for: .annual)
        if let monthly = display.monthlyEquivalentPrice {
            return normalizePrice(monthly)
        }
        if let product = subscriptionService.annualProduct {
            let monthly = (product.price as NSDecimalNumber).doubleValue / 12.0
            return formatEuroAmount(monthly)
        }
        return SubscriptionConfiguration.fallbackAnnualMonthlyEquivalent
    }

    private var annualSavingsBadge: String? {
        "Économisez +50%"
    }

    private var paywallContinueButtonTitle: String {
        selectedTrialInfo.ctaTitle()
    }

    private var paywallContinueButtonEnabled: Bool {
        selectedPlanAvailableOnStore && !subscriptionService.isLoading && !isPurchasing
    }

    private func normalizePrice(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("$") {
            let amount = String(s.dropFirst()).trimmingCharacters(in: .whitespaces)
            return "\(amount.replacingOccurrences(of: ".", with: ",")) €"
        }
        return s
    }

    private func formatEuroAmount(_ amount: Double) -> String {
        String(format: "%.2f", amount).replacingOccurrences(of: ".", with: ",") + " €"
    }

    private func selectMonthlyPlan() {
        guard selectedBillingPlan != .monthly else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            selectedBillingPlan = .monthly
        }
    }

    private func selectAnnualPlan() {
        guard selectedBillingPlan != .annual else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            selectedBillingPlan = .annual
        }
    }

    private func refreshMeasuredTopSafeInset() {
        measuredTopSafeInset = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
    }

    private var paywallSubscriptionLegalFooter: some View {
        let product = subscriptionService.displayProduct(for: selectedBillingPlan)

        return VStack(spacing: 8) {
            Text(subscriptionLegalSummary(for: product))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                Button("Politique de confidentialité") {
                    legalSafariURL = privacyURL
                }
                Text("·")
                    .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                Button("Conditions d'utilisation") {
                    legalSafariURL = termsURL
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .buttonStyle(.plain)
            .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
        }
        .padding(.top, 2)
    }

    private func subscriptionLegalSummary(for product: SubscriptionProductDisplay) -> String {
        let length = selectedBillingPlan == .annual ? "1 an" : "1 mois"
        let trialPrefix = selectedTrialInfo.isActiveOffer
            ? " Essai gratuit de \(selectedTrialInfo.days) jours, puis "
            : " "
        return "Abonnement auto-renouvelable « \(product.displayName) » (\(length)) — \(product.displayPrice).\(trialPrefix)Renouvellement automatique jusqu'à annulation dans Réglages › Apple ID › Abonnements."
    }

    #if DEBUG
    private var paywallDemoAccessButton: some View {
        Button {
            HapticManager.shared.impact(.light)
            subscriptionService.grantComplimentaryAccess()
            completePaywallFlow()
        } label: {
            Text("Mode démo")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme).opacity(0.45))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .accessibilityLabel("Activer le mode démo développeur")
    }
    #endif

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
            return
        } catch {
            purchaseError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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

    private func scheduleExitNotificationIfNeeded() {
        guard !hasScheduledExitNotification else { return }
        guard !subscriptionService.subscriptionStatus.isActive else { return }
        hasScheduledExitNotification = true
        Task {
            await PaywallExitNotificationService.shared.scheduleExitNotification(hasPurchased: false)
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
