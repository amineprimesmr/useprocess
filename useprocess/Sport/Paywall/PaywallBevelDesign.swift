//
//  PaywallBevelDesign.swift
//  useprocess
//
//  Composants visuels paywall style Bevel — clair / sombre adaptatif.
//

import SwiftUI
import UIKit

// MARK: - Thème adaptatif

enum PaywallBevelTheme {
    static func titleText(for scheme: ColorScheme) -> Color {
        Color(.label)
    }

    static func paywallTitleFont() -> Font {
        paywallHeroTitleFont()
    }

    /// Titre hero paywall — SF Pro Display Bold, comme les paywalls Pro type référence.
    static func paywallHeroTitleFont(size: CGFloat = 26) -> Font {
        if let uiFont = UIFont(name: "SFProDisplay-Bold", size: size) {
            return Font(uiFont)
        }
        return .system(size: size, weight: .bold, design: .default)
    }

    static func paywallHeroSubtitleFont(size: CGFloat = 15) -> Font {
        if let uiFont = UIFont(name: "SFProDisplay-Regular", size: size) {
            return Font(uiFont)
        }
        return .system(size: size, weight: .regular, design: .default)
    }

    static let paywallHeroTitleTracking: CGFloat = -0.45

    static func paywallTitleColor(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(.label)
            : Color(red: 0.06, green: 0.07, blue: 0.09)
    }

    static func subtitleText(for scheme: ColorScheme) -> Color {
        Color(.secondaryLabel)
    }

    static func footerText(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(.label).opacity(0.88)
            : Color(red: 0.18, green: 0.19, blue: 0.22)
    }

    static func dividerLine(for scheme: ColorScheme) -> Color {
        Color(.separator).opacity(scheme == .dark ? 0.55 : 0.35)
    }

    static func dividerLabel(for scheme: ColorScheme) -> Color {
        Color(.tertiaryLabel)
    }

    static func planPrimaryPrice(for scheme: ColorScheme) -> Color {
        Color(.label)
    }

    static func planSecondaryPrice(for scheme: ColorScheme) -> Color {
        Color(.secondaryLabel)
    }

    static func chromeButtonFill(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.06)
    }

    static func chromeButtonIcon(for scheme: ColorScheme) -> Color {
        Color(.label).opacity(scheme == .dark ? 0.88 : 0.55)
    }

    static func cardFill(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(.secondarySystemGroupedBackground)
            : Color.white
    }

    static func cardBorder(for scheme: ColorScheme, selected: Bool) -> Color {
        if selected {
            return scheme == .dark ? Color.white : Color.black
        }
        return Color(.separator).opacity(scheme == .dark ? 0.65 : 0.35)
    }

    static func cardShadow(for scheme: ColorScheme, selected: Bool) -> Color {
        .black.opacity(scheme == .dark ? (selected ? 0.45 : 0.28) : (selected ? 0.10 : 0.05))
    }

    static func radioStroke(for scheme: ColorScheme) -> Color {
        Color(.label).opacity(scheme == .dark ? 0.35 : 0.18)
    }

    static func radioSelectedFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .black
    }

    static func radioSelectedCheck(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : .white
    }

    static func badgeFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .black
    }

    static func badgeText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : .white
    }

    static func ctaFill(for scheme: ColorScheme, enabled: Bool) -> Color {
        let base = scheme == .dark ? Color.white : Color.black
        return base.opacity(enabled ? 1 : 0.35)
    }

    static func ctaText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : .white
    }

    static func ctaGlow(for scheme: ColorScheme, enabled: Bool) -> Color {
        accentBlueGlow(for: scheme).opacity(enabled ? 1 : 0)
    }

    static func featureTitle(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.92)
            : Color(red: 0.06, green: 0.07, blue: 0.09).opacity(0.90)
    }

    static func featureIcon(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.88)
            : Color.primary.opacity(0.70)
    }

    static func featureRowFont() -> Font {
        .system(size: 17, weight: .medium)
    }

    static func accentBlueGlow(for scheme: ColorScheme) -> Color {
        Color(red: 0.48, green: 0.72, blue: 0.98)
            .opacity(scheme == .dark ? 0.22 : 0.38)
    }

    /// Dégradé « Pro » dans le titre hero paywall.
    static func paywallProTitleGradient(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            LinearGradient(
                colors: [
                    Color(red: 0.52, green: 0.88, blue: 1.0),
                    Color(red: 0.34, green: 0.72, blue: 1.0),
                    Color(red: 0.20, green: 0.56, blue: 0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.66, blue: 1.0),
                    Color(red: 0.14, green: 0.50, blue: 0.96),
                    Color(red: 0.08, green: 0.38, blue: 0.90),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Opacité de la 2e couche de lueur (badge + CTA).
    static func accentBlueGlowLayerOpacity(for scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.28 : 0.55
    }

    /// Halo flou derrière le bouton Continuer.
    static func ctaHaloOpacity(for scheme: ColorScheme, enabled: Bool) -> Double {
        guard enabled else { return 0 }
        return scheme == .dark ? 0.38 : 0.85
    }
}

// MARK: - Modèle feature

struct PaywallFeatureItem: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
}

// MARK: - Fond + dégradé pastel (Bevel)

struct PaywallBevelBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: backdropGradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var backdropGradientColors: [Color] {
        if colorScheme == .dark {
            [
                Color.black,
                Color(red: 0.04, green: 0.04, blue: 0.06),
                Color(red: 0.07, green: 0.09, blue: 0.14),
                Color(red: 0.10, green: 0.14, blue: 0.24),
                Color(red: 0.12, green: 0.17, blue: 0.30),
            ]
        } else {
            [
                Color.white,
                Color(red: 0.99, green: 0.99, blue: 1.0),
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.90, green: 0.94, blue: 0.99),
            ]
        }
    }
}

// MARK: - Ligne feature

struct PaywallBevelFeatureRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: PaywallFeatureItem
    let onNutritionSecretUnlock: (() -> Void)?

    init(item: PaywallFeatureItem, onNutritionSecretUnlock: (() -> Void)? = nil) {
        self.item = item
        self.onNutritionSecretUnlock = onNutritionSecretUnlock
    }

    private let iconSlotWidth: CGFloat = 30

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: item.symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(PaywallBevelTheme.featureIcon(for: colorScheme))
                .symbolRenderingMode(.monochrome)
                .frame(width: iconSlotWidth, height: iconSlotWidth, alignment: .center)

            Text(item.title)
                .font(PaywallBevelTheme.featureRowFont())
                .foregroundStyle(PaywallBevelTheme.featureTitle(for: colorScheme))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        #if DEBUG
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard item.id == "hydration" else { return }
            onNutritionSecretUnlock?()
        }
        #endif
    }
}

struct PaywallBevelAlsoIncludesDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(PaywallBevelTheme.dividerLine(for: colorScheme))
                .frame(height: 1)
            Text(OnboardingCopy.t("inclut également", en: "also includes"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PaywallBevelTheme.dividerLabel(for: colorScheme))
                .textCase(.lowercase)
                .fixedSize()
            Rectangle()
                .fill(PaywallBevelTheme.dividerLine(for: colorScheme))
                .frame(height: 1)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Liste features (statique)

struct PaywallBevelAutoScrollingFeatures: View {
    let primary: [PaywallFeatureItem]
    let alsoIncluded: [PaywallFeatureItem]
    let onNutritionSecretUnlock: (() -> Void)?

    init(
        primary: [PaywallFeatureItem],
        alsoIncluded: [PaywallFeatureItem],
        onNutritionSecretUnlock: (() -> Void)? = nil
    ) {
        self.primary = primary
        self.alsoIncluded = alsoIncluded
        self.onNutritionSecretUnlock = onNutritionSecretUnlock
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(primary) {
                    PaywallBevelFeatureRow(item: $0, onNutritionSecretUnlock: onNutritionSecretUnlock)
                }
                if !alsoIncluded.isEmpty {
                    PaywallBevelAlsoIncludesDivider()
                    ForEach(alsoIncluded) {
                        PaywallBevelFeatureRow(item: $0, onNutritionSecretUnlock: onNutritionSecretUnlock)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Segmented picker Annuel / Mensuel

struct PaywallBevelPlanSegmentPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: SubscriptionBillingPlan
    /// Plan court de la variante A/B (`.weekly` ou `.monthly`).
    let shortPlan: SubscriptionBillingPlan
    let annualComparePrice: String
    let annualPrice: String
    let shortPlanPrice: String
    var onSelectionChange: ((SubscriptionBillingPlan) -> Void)?

    @Namespace private var pillNamespace

    private let segmentHeight: CGFloat = 88
    private let inset: CGFloat = 5
    private let trackCornerRadius: CGFloat = 30
    private let pillCornerRadius: CGFloat = 24

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(.annual)
            segmentButton(shortPlan)
        }
        .padding(inset)
        .background {
            trackShape.fill(Color.clear)
        }
        .overlay {
            trackShape.strokeBorder(trackBorderColor, lineWidth: 1)
        }
    }

    private var trackShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous)
    }

    private func pillShape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
    }

    private var trackBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.26) : Color.black.opacity(0.14)
    }

    private func segmentButton(_ plan: SubscriptionBillingPlan) -> some View {
        let isSelected = selection == plan

        return Button {
            guard selection != plan else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.12)) {
                selection = plan
            }
            onSelectionChange?(plan)
        } label: {
            ZStack(alignment: .leading) {
                if isSelected {
                    selectedPillGlass
                        .matchedGeometryEffect(id: "paywallPlanPill", in: pillNamespace)
                }

                segmentContent(plan: plan, isSelected: isSelected)
                    .padding(.horizontal, 18)
            }
            .frame(maxWidth: .infinity, minHeight: segmentHeight, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous))
        }
        .buttonStyle(.processPlain)
    }

    @ViewBuilder
    private func segmentContent(plan: SubscriptionBillingPlan, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(plan.shortPickerTitle)
                .font(PaywallBevelTheme.paywallHeroSubtitleFont(size: isSelected ? 18 : 17))
                .fontWeight(isSelected ? .bold : .semibold)
                .foregroundStyle(isSelected ? selectedPrimaryText : unselectedText)

            if plan == .annual {
                annualPriceRow(isSelected: isSelected)
            } else {
                Text(shortPlanPrice)
                    .font(PaywallBevelTheme.paywallHeroSubtitleFont(size: 18))
                    .fontWeight(isSelected ? .bold : .semibold)
                    .foregroundStyle(isSelected ? selectedPrimaryText : unselectedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    @ViewBuilder
    private func annualPriceRow(isSelected: Bool) -> some View {
        let compareStyle = isSelected ? selectedCompareText : unselectedText.opacity(0.88)
        let priceWeight: Font.Weight = isSelected ? .bold : .semibold
        let priceColor = isSelected ? selectedPrimaryText : unselectedText

        (
            Text(annualComparePrice)
                .foregroundStyle(compareStyle)
                .strikethrough(
                    true,
                    color: compareStyle.opacity(0.72)
                )
            + Text(" ")
            + Text(annualPrice)
                .fontWeight(priceWeight)
                .foregroundStyle(priceColor)
        )
        .font(PaywallBevelTheme.paywallHeroSubtitleFont(size: 18))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .allowsTightening(true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var selectedPillGlass: some View {
        let shape = pillShape()

        shape
            .fill(.clear)
            .processGlassEffect(in: shape, interactive: true)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 6, y: 2)
    }

    private var selectedPrimaryText: Color {
        PaywallBevelTheme.planPrimaryPrice(for: colorScheme)
    }

    private var selectedCompareText: Color {
        PaywallBevelTheme.planSecondaryPrice(for: colorScheme).opacity(0.88)
    }

    private var unselectedText: Color {
        colorScheme == .dark ? Color.white.opacity(0.56) : Color.black.opacity(0.42)
    }
}

// MARK: - Carte forfait (legacy)

struct PaywallBevelPlanCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let primaryPrice: String
    var compareAtPrice: String? = nil
    let secondaryPrice: String
    let isSelected: Bool
    let savingsBadge: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PaywallBevelTheme.titleText(for: colorScheme).opacity(0.92))
                        Spacer(minLength: 0)
                        planRadio
                    }
                    .padding(.bottom, 10)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let compareAtPrice {
                            Text(compareAtPrice)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(PaywallBevelTheme.planSecondaryPrice(for: colorScheme).opacity(0.72))
                                .strikethrough(true, color: PaywallBevelTheme.planSecondaryPrice(for: colorScheme).opacity(0.55))
                        }

                        Text(primaryPrice)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(PaywallBevelTheme.planPrimaryPrice(for: colorScheme).opacity(0.94))
                    }
                    .padding(.bottom, secondaryPrice.isEmpty ? 0 : 4)

                    if !secondaryPrice.isEmpty {
                        Text(secondaryPrice)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(PaywallBevelTheme.planSecondaryPrice(for: colorScheme).opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, savingsBadge == nil ? 18 : 22)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.clear)
                }
                .processGlassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(
                    color: PaywallBevelTheme.cardShadow(for: colorScheme, selected: isSelected),
                    radius: isSelected ? 8 : 4,
                    y: 2
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            PaywallBevelTheme.cardBorder(for: colorScheme, selected: isSelected),
                            lineWidth: isSelected ? 1.5 : 0.75
                        )
                )

                if let savingsBadge {
                    Text(savingsBadge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PaywallBevelTheme.badgeText(for: colorScheme))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(PaywallBevelTheme.badgeFill(for: colorScheme))
                                .shadow(
                                    color: PaywallBevelTheme.accentBlueGlow(for: colorScheme),
                                    radius: colorScheme == .dark ? 6 : 8,
                                    y: 0
                                )
                                .shadow(
                                    color: PaywallBevelTheme.accentBlueGlow(for: colorScheme)
                                        .opacity(PaywallBevelTheme.accentBlueGlowLayerOpacity(for: colorScheme)),
                                    radius: colorScheme == .dark ? 10 : 14,
                                    y: 2
                                )
                        )
                        .offset(y: -9)
                }
            }
        }
        .buttonStyle(.processPlain)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var planRadio: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? Color.clear : PaywallBevelTheme.radioStroke(for: colorScheme),
                    lineWidth: 1.5
                )
                .frame(width: 24, height: 24)
            if isSelected {
                Circle()
                    .fill(PaywallBevelTheme.radioSelectedFill(for: colorScheme))
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PaywallBevelTheme.radioSelectedCheck(for: colorScheme))
            }
        }
    }
}

// MARK: - Bouton Continuer

struct PaywallBevelContinueButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule(style: .continuous)
                    .fill(PaywallBevelTheme.accentBlueGlow(for: colorScheme))
                    .blur(radius: colorScheme == .dark ? 12 : 14)
                    .opacity(PaywallBevelTheme.ctaHaloOpacity(for: colorScheme, enabled: isEnabled))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)

                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(paywallCTATextColor)
                    } else {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(paywallCTATextColor)
                            .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    paywallCTAGlassCapsule
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark
                                ? Color.black.opacity(0.08)
                                : Color.white.opacity(0.10),
                            lineWidth: 0.5
                        )
                }
                .shadow(
                    color: PaywallBevelTheme.ctaGlow(for: colorScheme, enabled: isEnabled),
                    radius: colorScheme == .dark ? 10 : 14,
                    y: 0
                )
                .shadow(
                    color: PaywallBevelTheme.ctaGlow(for: colorScheme, enabled: isEnabled)
                        .opacity(PaywallBevelTheme.accentBlueGlowLayerOpacity(for: colorScheme)),
                    radius: colorScheme == .dark ? 16 : 22,
                    y: 4
                )
            }
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(PaywallBevelPressStyle())
        .disabled(!isEnabled || isLoading)
    }

    private var paywallCTATextColor: Color {
        colorScheme == .dark ? .black : .white
    }

    @ViewBuilder
    private var paywallCTAGlassCapsule: some View {
        if #available(iOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(colorScheme == .dark ? .white.opacity(0.92) : .black.opacity(0.72))
                .glassEffect(
                    colorScheme == .dark
                        ? .regular.tint(.white.opacity(0.96)).interactive()
                        : .regular.tint(.black.opacity(0.88)).interactive(),
                    in: Capsule()
                )
        } else {
            Capsule(style: .continuous)
                .fill(colorScheme == .dark ? Color.white : Color.black.opacity(0.92))
        }
    }
}

private struct PaywallBevelPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - Features Process

enum PaywallBevelFeatureCatalog {
    @MainActor
    static var primary: [PaywallFeatureItem] {
        [
            PaywallFeatureItem(
                id: "plan",
                title: OnboardingCopy.t(
                    "Plan personnalisé anti-rétention",
                    en: "Personalized anti-bloat plan"
                ),
                symbol: "list.clipboard"
            ),
            PaywallFeatureItem(
                id: "scan",
                title: OnboardingCopy.t(
                    "Scans visage illimités",
                    en: "Unlimited face scans"
                ),
                symbol: "viewfinder"
            ),
            PaywallFeatureItem(
                id: "hydration",
                title: OnboardingCopy.t(
                    "Hydratation guidée au quotidien",
                    en: "Daily guided hydration"
                ),
                symbol: "drop"
            ),
            PaywallFeatureItem(
                id: "coach",
                title: OnboardingCopy.t(
                    "Coach IA dédié à ton visage",
                    en: "AI coach for your face"
                ),
                symbol: "bubble.left.and.bubble.right"
            ),
            PaywallFeatureItem(
                id: "nutrition",
                title: OnboardingCopy.t(
                    "Nutrition et repas anti-rétention",
                    en: "Anti-bloat nutrition & meals"
                ),
                symbol: "fork.knife"
            ),
        ]
    }

    static let alsoIncluded: [PaywallFeatureItem] = []
}
