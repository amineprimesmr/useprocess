//
//  PaywallView+Content.swift
//  Process
//
//  Sous-vues principales du paywall (scroll, CTA, titre, loading, toggle/prix, `calculateMonthlyPrice`).
//  Voir PaywallView+TimelineAndSlider et PaywallView+PurchaseActions.
//

import SwiftUI
import StoreKit
import UIKit

extension PaywallView {
    // MARK: - Subviews pour simplifier le body

    @ViewBuilder
    var mainContentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Espace pour le titre en overlay (comme les autres pages)
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement pour le contenu - Réduit pour mettre la timeline plus haut
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing + 50)

                // ✅ Affichage conditionnel : image designbail avant déblocage, timeline après
                if !isSliderUnlocked {
                    // Image designbail avant que le slider soit débloqué - TAILLE ADAPTÉE POUR iPad
                    OptionalAssetImage(
                        name: "designbail",
                        systemName: "lock.rectangle.stack.fill",
                        maxHeight: LayoutConstants.isIPad ? 600 : 420
                    )
                    .adaptiveHorizontalPadding()
                    .padding(.bottom, LayoutConstants.isIPad ? 120 : 100)
                } else {
                    // ✅ Timeline avec icônes dans cercles et traits fins (après déblocage)
                    timelineView
                        .padding(.leading, LayoutConstants.isIPad ? 0 : -25)
                        .padding(.trailing, LayoutConstants.isIPad ? 0 : 5)
                        .padding(.bottom, LayoutConstants.isIPad ? 120 : 100)
                        .adaptiveHorizontalPadding()
                        .iPadContentWidth()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 0, for: .scrollContent)
        .scrollIndicators(.hidden)
        .onAppear {
            animateTimelineEntry()
        }
    }

    @ViewBuilder
    var overlayViews: some View {
        // ✅ Titre en OVERLAY
        titleOverlayView

    }

    @ViewBuilder
    var fixedButtonsView: some View {
        // ✅ BOUTON/SLIDER FIXE
        VStack(spacing: LayoutConstants.isIPad ? 16 : 12) {
            // Choix mensuel / annuel
            if isSliderUnlocked {
                billingPlanPickerView
                    .adaptiveHorizontalPadding()
                    .iPadContentWidth()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
            }

            // Slider ou bouton final
            sliderOrButtonView

            // ✅ Conformité App Store 3.1.2
            if isSliderUnlocked {
                let product = subscriptionService.displayProduct(for: selectedBillingPlan)
                VStack(spacing: 10) {
                    Text(product.displayName)
                        .font(.system(size: LayoutConstants.isIPad ? 16 : 14, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                    Text(compliancePriceLine(for: product))
                        .font(.system(size: LayoutConstants.isIPad ? 15 : 13, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    HStack(spacing: 8) {
                        Link("Conditions d'utilisation", destination: termsURL)
                        Text("•")
                            .foregroundColor(.white.opacity(0.45))
                        Link("Politique de confidentialité", destination: privacyURL)
                    }
                    .font(.system(size: LayoutConstants.isIPad ? 13 : 11, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.7))
                    .tint(.white.opacity(0.85))
                }
                .padding(.top, 8)
                .adaptiveHorizontalPadding()
                .transition(.opacity)
                .iPadContentWidth()
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: LayoutConstants.isIPad ? LayoutConstants.maxContentWidth : .infinity)
        .frame(maxWidth: .infinity)
        .padding(.bottom, LayoutConstants.isIPad ? 50 : 30)
        .padding(.top, LayoutConstants.isIPad ? -80 : -100)
        .frame(maxHeight: .infinity, alignment: .bottom)

        // Bouton retour au-dessus de tout
        backButtonView

        // Menu en haut à droite
        menuButtonView
    }

    @ViewBuilder
    var sliderOrButtonView: some View {
        ZStack {
            // Slider qui se transforme progressivement
            if !isSliderUnlocked {
                unlockSliderView
                    .adaptiveHorizontalPadding()
                    .iPadContentWidth()
                    .frame(maxWidth: .infinity)
                    .opacity(sliderTransformOpacity)
                    .rotationEffect(.degrees(sliderRotation))
                    .blur(radius: sliderBlur)
            }

            // Bouton final qui apparaît progressivement avec animation stylée
            if isSliderUnlocked {
                purchaseButtonView
            }
        }
    }

    @ViewBuilder
    var purchaseButtonView: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            Task {
                await purchaseSubscription()
            }
        }) {
            HStack(spacing: 12) {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }
                Text(buttonText)
                    .font(.system(size: LayoutConstants.isIPad ? LayoutConstants.Typography.buttonSize : 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0.5, y: 0.5)
                    .id(buttonText) // ✅ Animation fluide du texte (force la réanimation)
                    .scaleEffect(buttonTextScale)
                    .animation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0.4), value: buttonText) // ✅ Animation progressive
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 40) // ✅ Encore plus réduit (de 44 à 40)
            .padding(.horizontal, 20)
            .padding(.vertical, 8) // ✅ Réduit de 10 à 8
        }
        .glassStyle() // ✅ LIQUID GLASS NATIF (comme le bouton "Essai gratuit")
        .buttonStyle(.plain)
        .scaleEffect(buttonScale)
        .offset(y: buttonOffsetY)
        .opacity(buttonOpacity)
        .adaptiveHorizontalPadding()
        .iPadContentWidth()
        .frame(maxWidth: .infinity)
        .disabled(isPurchasing)
    }

    @ViewBuilder
    var titleOverlayView: some View {
        VStack {
            VStack(alignment: .center, spacing: 12) {
                ZStack(alignment: .center) {
                    // Texte principal - Style Revolut
                    Text(currentTitle.uppercased())
                        .font(.revolutTitle(size: LayoutConstants.isIPad ? LayoutConstants.Typography.titleSize : 26))
                        .foregroundColor(.white)
                        .kerning(0.8) // Espacement des lettres légèrement resserré
                        .multilineTextAlignment(.center)
                        .opacity(titleOpacity)

                    // Effet de reflet animé
                    if isAnimating {
                        Text(currentTitle.uppercased())
                            .font(.revolutTitle(size: LayoutConstants.isIPad ? LayoutConstants.Typography.titleSize : 26))
                            .foregroundColor(.white)
                            .kerning(0.8)
                            .multilineTextAlignment(.center)
                            .opacity(reflectionOpacity)
                            .offset(x: reflectionOffset)
                            .mask(
                                LinearGradient(
                                    colors: [.clear, .white, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: currentTitle)
                .animation(.easeInOut(duration: 0.5), value: titleOpacity)
            }
            .frame(maxWidth: LayoutConstants.isIPad ? LayoutConstants.maxContentWidth : .infinity, alignment: .center)
            .frame(maxWidth: .infinity)
            .adaptiveHorizontalPadding()
            .padding(.top, OnboardingConstants.titleTopPadding + (LayoutConstants.isIPad ? 70 : 90)) // Plus haut
            Spacer()
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    var noPaymentMessageView: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                if let checkImage = UIImage(named: "check") {
                    Image(uiImage: checkImage)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
                Text("Aucun paiement n'est dû aujourd'hui")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 580)
            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    @ViewBuilder
    var priceTextView: some View {
        VStack {
            Spacer()
            Group {
                if let product = subscriptionService.annualProduct {
                    Text("Puis \(product.displayPrice) par an (\(calculateMonthlyPrice(from: product)) /mois)")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("Chargement des prix...")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 580) // ✅ Positionné en dessous du bouton (ajusté pour être plus proche)
            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    @ViewBuilder
    var loadingIndicatorView: some View {
        if isPurchasing {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("Traitement en cours...")
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.95),
                                    Color.gray.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    // MARK: - Helper Methods

    func animateTimelineEntry() {
        for i in 0..<3 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(i) * 0.15)) {
                iconScale[i] = 1.0
                iconOpacity[i] = 1.0
            }
        }

        for i in 0..<2 {
            withAnimation(.easeInOut(duration: 0.8).delay(Double(i) * 0.15 + 0.3)) {
                lineOpacity[i] = 1.0
            }
        }

        for i in 0..<4 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(i) * 0.15 + 0.2)) {
                textOpacity[i] = 1.0
                textOffset[i] = 0
            }
        }
    }

    // MARK: - Computed Properties

    @ViewBuilder
    var billingPlanPickerView: some View {
        HStack(spacing: 10) {
            ForEach(SubscriptionBillingPlan.allCases) { plan in
                let isSelected = selectedBillingPlan == plan
                let isAvailable = plan == .monthly
                    ? subscriptionService.hasLiveMonthlyProduct
                    : subscriptionService.hasLiveAnnualProduct
                Button {
                    guard isAvailable else { return }
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        selectedBillingPlan = plan
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(plan.title)
                            .font(.system(size: 15, weight: .semibold))
                        Text(isAvailable ? planPriceSubtitle(for: plan) : "Indisponible")
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.85)
                    }
                    .foregroundStyle(isSelected ? Color.black : Color.white)
                    .opacity(isAvailable ? 1 : 0.45)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        Capsule()
                            .fill(isSelected ? Color.white : Color.white.opacity(0.12))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    func planPriceSubtitle(for plan: SubscriptionBillingPlan) -> String {
        let product = subscriptionService.displayProduct(for: plan)
        switch plan {
        case .monthly:
            return "\(product.displayPrice) / mois"
        case .annual:
            if let monthly = product.monthlyEquivalentPrice {
                return "\(product.displayPrice) / an · \(monthly)/mois"
            }
            return "\(product.displayPrice) / an"
        }
    }

    func compliancePriceLine(for product: SubscriptionProductDisplay) -> String {
        switch selectedBillingPlan {
        case .monthly:
            return "Renouvellement automatique · \(product.displayPrice) \(product.periodLabel)"
        case .annual:
            if let monthly = product.monthlyEquivalentPrice {
                return "Renouvellement automatique · \(product.displayPrice) \(product.periodLabel) (\(monthly) / mois)"
            }
            return "Renouvellement automatique · \(product.displayPrice) \(product.periodLabel)"
        }
    }

    var buttonText: String {
        let product = subscriptionService.displayProduct(for: selectedBillingPlan)
        switch selectedBillingPlan {
        case .monthly:
            return "S'abonner · \(product.displayPrice)/mois"
        case .annual:
            return "S'abonner · \(product.displayPrice)/an"
        }
    }

    var displayedPrice: String {
        subscriptionService.displayProduct(for: selectedBillingPlan).displayPrice
    }

    var originalPrice: String {
        displayedPrice
    }

    var displayedMonthlyPrice: String {
        let product = subscriptionService.displayProduct(for: selectedBillingPlan)
        return product.monthlyEquivalentPrice ?? product.displayPrice
    }

    var billingDateText: String {
        if let date = billingDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateStyle = .long
            return "Vous serez facturé le \(formatter.string(from: date)) sauf si vous annulez avant."
        }
        return "Vous serez facturé dans 3 jours sauf si vous annulez avant."
    }

    var billingDateFormatted: String {
        if let date = billingDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "d MMMM"
            return formatter.string(from: date)
        }
        return "dans 3 jours"
    }

    // MARK: - Helper Methods

    func calculateMonthlyPrice(from product: Product) -> String {
        guard product.subscription != nil else {
            return "N/A"
        }

        // Calculer le prix mensuel à partir du prix annuel
        let price = product.price
        let monthlyPrice = price / 12

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        // ✅ CORRIGÉ: Convertir Decimal en NSDecimalNumber correctement
        return formatter.string(from: NSDecimalNumber(decimal: monthlyPrice)) ?? "N/A"
    }
}
