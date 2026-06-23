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
        .system(size: 29, weight: .heavy, design: .default)
    }

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

    static func accentBlueGlow(for scheme: ColorScheme) -> Color {
        Color(red: 0.48, green: 0.72, blue: 0.98)
            .opacity(scheme == .dark ? 0.22 : 0.38)
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
    let subtitle: String
    let symbol: String
    let symbolColors: [Color]
    let assetName: String?
    let assetCornerRadius: CGFloat?

    init(
        id: String,
        title: String,
        subtitle: String,
        symbol: String,
        symbolColors: [Color],
        assetName: String? = nil,
        assetCornerRadius: CGFloat? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.symbolColors = symbolColors
        self.assetName = assetName
        self.assetCornerRadius = assetCornerRadius
    }
}

// MARK: - Fond + dégradé pastel (Bevel)

struct PaywallBevelBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                Color(red: 0.07, green: 0.07, blue: 0.08)
                RadialGradient(
                    colors: [
                        Color(red: 0.16, green: 0.22, blue: 0.38).opacity(0.42),
                        Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.22),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.42, y: 0.34),
                    startRadius: 20,
                    endRadius: 380
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.20, green: 0.16, blue: 0.32).opacity(0.24),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.82, y: 0.40),
                    startRadius: 8,
                    endRadius: 260
                )
            } else {
                Color(red: 0.99, green: 0.99, blue: 1.0)
                RadialGradient(
                    colors: [
                        Color(red: 0.90, green: 0.95, blue: 1.0).opacity(0.42),
                        Color(red: 0.96, green: 0.98, blue: 1.0).opacity(0.22),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.45, y: 0.38),
                    startRadius: 20,
                    endRadius: 420
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.94, green: 0.96, blue: 0.99).opacity(0.28),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.88, y: 0.42),
                    startRadius: 8,
                    endRadius: 280
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Ligne feature

struct PaywallBevelFeatureRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: PaywallFeatureItem

    private var iconSize: CGFloat { 48 }
    private var iconContainerSize: CGFloat { 62 }
    private var iconCornerRadius: CGFloat {
        max(item.assetCornerRadius ?? 0, 14)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            featureIcon
                .frame(width: iconContainerSize, height: iconContainerSize)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PaywallBevelTheme.titleText(for: colorScheme))
                    .multilineTextAlignment(.leading)
                Text(item.subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(PaywallBevelTheme.subtitleText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var featureIcon: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.12 : 0.28),
                            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.10),
                            .clear,
                        ],
                        center: .center,
                        startRadius: iconSize * 0.16,
                        endRadius: iconContainerSize * 0.50
                    )
                )
                .frame(width: iconContainerSize, height: iconContainerSize)

            if let assetName = item.assetName, !assetName.isEmpty {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: iconCornerRadius,
                            style: .continuous
                        )
                    )
            } else {
                Image(systemName: item.symbol)
                    .font(.system(size: 32, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(item.symbolColors.first ?? .blue, item.symbolColors.last ?? .cyan)
            }
        }
    }
}

struct PaywallBevelAlsoIncludesDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(PaywallBevelTheme.dividerLine(for: colorScheme))
                .frame(height: 1)
            Text("inclut également")
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

// MARK: - Défilement vertical (auto + manuel, boucle fluide sans saut)

struct PaywallBevelAutoScrollingFeatures: View {
    let primary: [PaywallFeatureItem]
    let alsoIncluded: [PaywallFeatureItem]

    private let pixelsPerSecond: CGFloat = 16

    @State private var measuredBlockHeight: CGFloat = 0
    @State private var baseOffset: CGFloat = 0
    @State private var autoAnchor = Date()
    @State private var isUserDragging = false
    @State private var dragTranslation: CGFloat = 0

    private var loopBlockHeight: CGFloat {
        max(measuredBlockHeight, 1)
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isUserDragging)) { timeline in
                let block = loopBlockHeight
                let autoDelta: CGFloat = {
                    guard !isUserDragging else { return 0 }
                    let elapsed = timeline.date.timeIntervalSince(autoAnchor)
                    return -CGFloat(elapsed) * pixelsPerSecond
                }()
                let raw = baseOffset + autoDelta + (isUserDragging ? dragTranslation : 0)
                let displayOffset = loopOffset(raw, block: block)

                VStack(spacing: 0) {
                    featureStack
                    featureStack
                    featureStack
                }
                .offset(y: displayOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(manualScrollGesture)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.06),
                        .init(color: .black, location: 0.96),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var manualScrollGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let block = loopBlockHeight
                if !isUserDragging {
                    let elapsed = Date().timeIntervalSince(autoAnchor)
                    baseOffset = loopOffset(baseOffset - CGFloat(elapsed) * pixelsPerSecond, block: block)
                    autoAnchor = Date()
                    isUserDragging = true
                }
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                let block = loopBlockHeight
                baseOffset = loopOffset(baseOffset + value.translation.height, block: block)
                dragTranslation = 0
                autoAnchor = Date()
                isUserDragging = false
            }
    }

    private func loopOffset(_ raw: CGFloat, block: CGFloat) -> CGFloat {
        guard block > 0 else { return raw }
        var value = raw.truncatingRemainder(dividingBy: block)
        if value > 0 { value -= block }
        return value
    }

    @ViewBuilder
    private var featureStack: some View {
        VStack(spacing: 0) {
            ForEach(primary) { PaywallBevelFeatureRow(item: $0) }
            if !alsoIncluded.isEmpty {
                PaywallBevelAlsoIncludesDivider()
                ForEach(alsoIncluded) { PaywallBevelFeatureRow(item: $0) }
            }
        }
        .padding(.horizontal, 22)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: PaywallFeatureBlockHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(PaywallFeatureBlockHeightKey.self) { height in
            guard height > 0, abs(height - measuredBlockHeight) > 0.5 else { return }
            measuredBlockHeight = height
        }
    }
}

private struct PaywallFeatureBlockHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Carte forfait

struct PaywallBevelPlanCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let primaryPrice: String
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
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PaywallBevelTheme.titleText(for: colorScheme).opacity(0.92))
                        Spacer(minLength: 0)
                        planRadio
                    }
                    .padding(.bottom, 7)

                    Text(primaryPrice)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PaywallBevelTheme.planPrimaryPrice(for: colorScheme).opacity(0.94))
                        .padding(.bottom, 2)

                    Text(secondaryPrice)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(PaywallBevelTheme.planSecondaryPrice(for: colorScheme).opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.clear)
                }
                .processGlassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(
                    color: PaywallBevelTheme.cardShadow(for: colorScheme, selected: isSelected),
                    radius: isSelected ? 8 : 4,
                    y: 2
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            PaywallBevelTheme.cardBorder(for: colorScheme, selected: isSelected),
                            lineWidth: isSelected ? 1.5 : 0.75
                        )
                )

                if let savingsBadge {
                    Text(savingsBadge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PaywallBevelTheme.badgeText(for: colorScheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(PaywallBevelTheme.badgeFill(for: colorScheme))
                                .shadow(
                                    color: PaywallBevelTheme.accentBlueGlow(for: colorScheme),
                                    radius: colorScheme == .dark ? 8 : 10,
                                    y: 0
                                )
                                .shadow(
                                    color: PaywallBevelTheme.accentBlueGlow(for: colorScheme)
                                        .opacity(PaywallBevelTheme.accentBlueGlowLayerOpacity(for: colorScheme)),
                                    radius: colorScheme == .dark ? 12 : 18,
                                    y: 3
                                )
                        )
                        .offset(y: -9)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var planRadio: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? Color.clear : PaywallBevelTheme.radioStroke(for: colorScheme),
                    lineWidth: 1.5
                )
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(PaywallBevelTheme.radioSelectedFill(for: colorScheme))
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PaywallBevelTheme.radioSelectedCheck(for: colorScheme))
            }
        }
    }
}

// MARK: - Bouton Continuer

struct PaywallBevelContinueButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var subtitle: String? = nil
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    private var buttonHeight: CGFloat {
        subtitle == nil ? 56 : 64
    }

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
                        VStack(spacing: 2) {
                            Text(title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(paywallCTATextColor)

                            if let subtitle {
                                Text(subtitle)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(paywallCTATextColor.opacity(0.72))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: buttonHeight)
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
    private static let iconCornerRadius: CGFloat = 11

    static let primary: [PaywallFeatureItem] = [
        PaywallFeatureItem(
            id: "habits",
            title: "Suivez les habitudes et les symptômes",
            subtitle: "Repère tes routines et ce qui change au quotidien.",
            symbol: "list.bullet.clipboard.fill",
            symbolColors: [Color(red: 0.28, green: 0.62, blue: 0.98), Color(red: 0.52, green: 0.82, blue: 1.0)],
            assetName: "PaywallIconHabits",
            assetCornerRadius: iconCornerRadius
        ),
        PaywallFeatureItem(
            id: "stress",
            title: "Identifiez les déclencheurs de stress",
            subtitle: "Comprends ce qui te tire vers le bas et agis dessus.",
            symbol: "bolt.heart.fill",
            symbolColors: [Color(red: 0.95, green: 0.55, blue: 0.18), Color(red: 1.0, green: 0.78, blue: 0.42)],
            assetName: "PaywallIconStress",
            assetCornerRadius: iconCornerRadius
        ),
        PaywallFeatureItem(
            id: "body",
            title: "Optimisez votre corps",
            subtitle: "Ajuste ton entraînement et ta récupération en continu.",
            symbol: "figure.strengthtraining.traditional",
            symbolColors: [Color(red: 0.98, green: 0.34, blue: 0.42), Color(red: 1.0, green: 0.62, blue: 0.58)],
            assetName: "PaywallIconBody",
            assetCornerRadius: iconCornerRadius
        ),
        PaywallFeatureItem(
            id: "training",
            title: "Plans d'entraînement personnalisés",
            subtitle: "Des séances adaptées à ton niveau et à tes objectifs.",
            symbol: "calendar.badge.clock",
            symbolColors: [Color(red: 0.42, green: 0.48, blue: 0.98), Color(red: 0.68, green: 0.72, blue: 1.0)],
            assetName: "PaywallIconTraining",
            assetCornerRadius: iconCornerRadius
        ),
        PaywallFeatureItem(
            id: "nutrition",
            title: "Plan nutritionnel facile",
            subtitle: "Des repères simples pour mieux manger sans prise de tête.",
            symbol: "leaf.fill",
            symbolColors: [Color(red: 0.22, green: 0.72, blue: 0.48), Color(red: 0.52, green: 0.88, blue: 0.62)],
            assetName: "PaywallIconNutrition",
            assetCornerRadius: iconCornerRadius
        ),
        PaywallFeatureItem(
            id: "sleep",
            title: "Améliorer la qualité du sommeil",
            subtitle: "Repères concrets pour mieux dormir et récupérer.",
            symbol: "moon.zzz.fill",
            symbolColors: [Color(red: 0.55, green: 0.35, blue: 0.92), Color(red: 0.78, green: 0.62, blue: 1.0)],
            assetName: "PaywallIconSleep",
            assetCornerRadius: iconCornerRadius
        ),
        PaywallFeatureItem(
            id: "intelligence",
            title: "Process Intelligence",
            subtitle: "Un coach IA illimité, adapté à ton profil et tes objectifs.",
            symbol: "sparkles",
            symbolColors: [Color(red: 0.98, green: 0.45, blue: 0.38), Color(red: 1.0, green: 0.72, blue: 0.55)],
            assetName: "PaywallIconIntelligence",
            assetCornerRadius: iconCornerRadius
        ),
        PaywallFeatureItem(
            id: "scan360",
            title: "Analyse visage 360°",
            subtitle: "Suis ta progression avec une analyse visuelle complète.",
            symbol: "viewfinder.circle.fill",
            symbolColors: [Color(red: 0.98, green: 0.45, blue: 0.38), Color(red: 1.0, green: 0.72, blue: 0.55)],
            assetName: "PaywallIconScanVisage",
            assetCornerRadius: iconCornerRadius
        ),
        PaywallFeatureItem(
            id: "memory",
            title: "Mémoire Claude illimitée",
            subtitle: "Ton contexte est retenu d'une session à l'autre.",
            symbol: "brain.head.profile.fill",
            symbolColors: [Color(red: 0.55, green: 0.35, blue: 0.92), Color(red: 0.78, green: 0.62, blue: 1.0)],
            assetName: "PaywallIconMemory",
            assetCornerRadius: iconCornerRadius
        ),
    ]

    static let alsoIncluded: [PaywallFeatureItem] = []
}
