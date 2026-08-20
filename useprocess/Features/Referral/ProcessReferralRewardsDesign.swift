import SwiftUI
import UIKit

// MARK: - Palette

enum ProcessReferralRewardsPalette {
    static let accentBlue = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let accentBlueSoft = Color(red: 0.22, green: 0.58, blue: 1.0)
    static let mintBright = Color(red: 0.62, green: 0.98, blue: 0.58)
    static let mintSoft = Color(red: 0.42, green: 0.88, blue: 0.72)

    /// Dégradé très léger sur les caractères du code (glass tiles).
    static let codeCharacterGradient = LinearGradient(
        colors: [
            Color.white,
            Color(red: 0.96, green: 0.97, blue: 1.0),
            Color(red: 0.88, green: 0.91, blue: 0.98)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Background

struct ProcessReferralBlueTopFade: View {
    var body: some View {
        LinearGradient(
            colors: [
                ProcessReferralRewardsPalette.accentBlue.opacity(0.16),
                ProcessReferralRewardsPalette.accentBlueSoft.opacity(0.07),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Header

struct ProcessReferralRewardsHeader: View {
    let title: String
    var onBack: (() -> Void)?
    var trailingTitle: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let onBack {
                ProcessGlassIconButton(systemName: "chevron.left", size: 38, iconSize: 15, action: onBack)
                    .accessibilityLabel(AppCopy.back)
            } else {
                Color.clear.frame(width: 38, height: 38)
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            if let trailingTitle, let trailingAction {
                Button(action: trailingAction) {
                    Text(trailingTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ProcessReferralTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .processTappableButtonLabel(in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .processGlassButton(in: Capsule(style: .continuous))
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
        }
    }
}

// MARK: - Commission promo (partagé Réglages + page parrainage)

struct ProcessReferralCommissionPromoFeature: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
}

enum ProcessReferralCommissionPromoContent {
    @MainActor
    static var headerTitle: String {
        AppCopy.t(
            "Gagne ta première commission",
            en: "Earn your first commission"
        )
    }

    @MainActor
    static var headerSubtitle: String {
        AppCopy.t(
            "Rembourse ton abonnement en parrainant tes amis — \(ProcessReferralProgramTerms.commissionPercentLabel) à vie sur chaque paiement.",
            en: "Cover your subscription by referring friends — \(ProcessReferralProgramTerms.commissionPercentLabel) for life on every payment."
        )
    }

    @MainActor
    static var features: [ProcessReferralCommissionPromoFeature] {
        [
            ProcessReferralCommissionPromoFeature(
                id: "rate",
                icon: "percent",
                title: AppCopy.t(
                    "\(ProcessReferralProgramTerms.commissionPercentLabel) de commission à vie",
                    en: "\(ProcessReferralProgramTerms.commissionPercentLabel) lifetime commission"
                ),
                detail: AppCopy.t(
                    "Sur chaque abonnement payé par tes amis.",
                    en: "On every paid subscription from your friends."
                )
            ),
            ProcessReferralCommissionPromoFeature(
                id: "share",
                icon: "link",
                title: AppCopy.t("Lien unique à partager", en: "One link to share"),
                detail: AppCopy.t(
                    "WhatsApp, Instagram ou iMessage en un tap.",
                    en: "WhatsApp, Instagram, or iMessage in one tap."
                )
            ),
            ProcessReferralCommissionPromoFeature(
                id: "renewals",
                icon: "arrow.triangle.2.circlepath",
                title: AppCopy.t("Renouvellements inclus", en: "Renewals included"),
                detail: AppCopy.t(
                    "Tu touches aussi à chaque renouvellement.",
                    en: "You earn on every renewal too."
                )
            ),
            ProcessReferralCommissionPromoFeature(
                id: "payout",
                icon: "clock.fill",
                title: AppCopy.t(
                    "Versement sous \(ProcessReferralProgramTerms.holdDays) jours",
                    en: "Payout after \(ProcessReferralProgramTerms.holdDays) days"
                ),
                detail: AppCopy.t(
                    "Gains disponibles après la période de sécurité.",
                    en: "Earnings become available after the hold period."
                )
            )
        ]
    }
}

struct ProcessReferralCommissionPromoFeatureRow: View {
    let feature: ProcessReferralCommissionPromoFeature

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ProcessReferralRewardsPalette.mintBright)
                .symbolRenderingMode(.monochrome)
                .frame(width: ProcessSettingsOpalTheme.iconColumnWidth, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(feature.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

struct ProcessReferralCommissionSimulatorSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var friendCount: Double = 5

    private let cardShape = RoundedRectangle(
        cornerRadius: ProcessSettingsOpalTheme.cardCornerRadius,
        style: .continuous
    )
    private let maxFriends = 50

    private var friendCountInt: Int {
        Int(friendCount.rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(ProcessReferralCommissionPromoContent.headerTitle)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ProcessSettingsOpalTheme.sectionTitleTint)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ProcessReferralCommissionPromoContent.headerSubtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            promoCard
        }
        .padding(.top, 20)
    }

    private var promoCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(ProcessReferralCommissionPromoContent.features) { feature in
                    ProcessReferralCommissionPromoFeatureRow(feature: feature)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            simulatorBlock
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                cardShape
                    .fill(ProcessSettingsOpalTheme.cardFillDark)

                promoWatermark
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 8)
                    .padding(.trailing, 4)
            }
            .clipShape(cardShape)
        }
        .overlay {
            cardShape.strokeBorder(ProcessSettingsOpalTheme.cardBorderDark, lineWidth: 0.5)
        }
    }

    private var simulatorBlock: some View {
        VStack(alignment: .center, spacing: 14) {
            Text(AppCopy.t("Simule tes gains", en: "Simulate your earnings"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .frame(maxWidth: .infinity)

            Text(ProcessReferralProgramTerms.formattedSimulatorTotal(friendCount: friendCountInt))
                .font(PaywallBevelTheme.paywallHeroTitleFont(size: 48))
                .tracking(PaywallBevelTheme.paywallHeroTitleTracking)
                .foregroundStyle(PaywallBevelTheme.paywallProTitleGradient(for: colorScheme))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.22), value: friendCountInt)

            Text(friendCountLabel)
                .font(PaywallBevelTheme.paywallHeroSubtitleFont(size: 15))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.22), value: friendCountInt)

            VStack(spacing: 10) {
                Slider(
                    value: $friendCount,
                    in: 0...Double(maxFriends),
                    step: 1
                ) {
                    Text(AppCopy.t("Amis abonnés simulés", en: "Simulated subscribed friends"))
                }
                .tint(ProcessReferralRewardsPalette.mintBright)
                .onChange(of: friendCountInt) { _, _ in
                    HapticManager.shared.selection()
                }

                HStack {
                    Text("0")
                    Spacer()
                    Text("\(maxFriends)")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ProcessReferralTheme.textTertiary)
            }

            Text(simulatorCommissionLine)
                .font(PaywallBevelTheme.paywallHeroSubtitleFont(size: 15))
                .foregroundStyle(ProcessReferralRewardsPalette.mintBright)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var promoWatermark: some View {
        Image("PlanHomeUpgradeDollar")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 132, height: 132)
            .opacity(0.14)
            .blendMode(.plusLighter)
            .accessibilityHidden(true)
    }

    private var friendCountLabel: String {
        switch friendCountInt {
        case 0:
            return AppCopy.t("0 ami", en: "0 friends")
        case 1:
            return AppCopy.t("1 ami", en: "1 friend")
        default:
            return AppCopy.t("\(friendCountInt) amis", en: "\(friendCountInt) friends")
        }
    }

    private var simulatorCommissionLine: String {
        AppCopy.t(
            "\(ProcessReferralProgramTerms.simulatorCommissionPerFriendLabel) · \(ProcessReferralProgramTerms.commissionPercentLabel)",
            en: "\(ProcessReferralProgramTerms.simulatorCommissionPerFriendLabel) · \(ProcessReferralProgramTerms.commissionPercentLabel)"
        )
    }
}

// MARK: - Social share row (liquid glass)

struct ProcessReferralGlassSocialShareRow: View {
    let copyText: String

    var body: some View {
        HStack(spacing: 0) {
            socialItem(
                title: AppCopy.t("Copier le lien", en: "Copy link"),
                brand: .copyLink
            ) {
                UIPasteboard.general.string = copyText
                HapticManager.shared.notification(.success)
            }

            socialItem(
                title: AppCopy.t("Messages", en: "Messages"),
                brand: .messages
            ) {
                shareViaMessages(copyText)
            }

            socialItem(
                title: "Instagram",
                brand: .instagram
            ) {
                UIPasteboard.general.string = copyText
                HapticManager.shared.notification(.success)
            }

            socialItem(
                title: "WhatsApp",
                brand: .whatsApp
            ) {
                openURL("https://wa.me/?text=\(copyText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
            }

            socialItem(
                title: "TikTok",
                brand: .tikTok
            ) {
                UIPasteboard.general.string = copyText
                HapticManager.shared.notification(.success)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func socialItem(
        title: String,
        brand: ProcessReferralSocialBrand,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ProcessReferralSocialBrandIcon(brand: brand)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ProcessReferralTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func shareViaMessages(_ text: String) {
        openURL("sms:&body=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Commission stats

struct ProcessReferralCommissionStatsCard: View {
    let stats: ProcessReferralCommissionStats

    private let cardShape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppCopy.t("Tes gains", en: "Your earnings"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 0) {
                statColumn(
                    title: AppCopy.t("En attente", en: "Pending"),
                    value: ProcessReferralProgramTerms.formattedCents(stats.pendingCents)
                )
                divider
                statColumn(
                    title: AppCopy.t("Disponible", en: "Payable"),
                    value: ProcessReferralProgramTerms.formattedCents(stats.payableCents)
                )
                divider
                statColumn(
                    title: AppCopy.t("Total", en: "Lifetime"),
                    value: ProcessReferralProgramTerms.formattedCents(stats.lifetimeCents)
                )
            }

            Text(
                AppCopy.t(
                    "Versement après \(ProcessReferralProgramTerms.holdDays) jours. 40 % du net à chaque paiement.",
                    en: "Payout after \(ProcessReferralProgramTerms.holdDays) days. 40% of net on every payment."
                )
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ProcessReferralTheme.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .processInteractiveGlassSurface(in: cardShape, interactive: false)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 44)
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(ProcessReferralTheme.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Bottom share CTA (liquid glass)

struct ProcessReferralGlassShareButton: View {
    let title: String
    let action: () -> Void

    private let shape = Capsule(style: .continuous)

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "square.and.arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .processTappableButtonLabel(in: shape, maxWidth: true)
        }
        .buttonStyle(.plain)
        .processGlassButton(in: shape)
        .controlSize(.regular)
        .background {
            shape
                .strokeBorder(ProcessSettingsOpalTheme.glowGradient, lineWidth: 1.5)
                .blur(radius: 6)
                .opacity(0.45)
                .offset(y: 4)
                .allowsHitTesting(false)
        }
    }
}

struct ProcessReferralStickyShareBar: View {
    let title: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    ProcessReferralTheme.pageBackground.opacity(0),
                    ProcessReferralTheme.pageBackground.opacity(0.92),
                    ProcessReferralTheme.pageBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)
            .allowsHitTesting(false)

            ProcessReferralGlassShareButton(title: title, action: action)
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
                .background(ProcessReferralTheme.pageBackground)
        }
    }
}

// MARK: - Milestones

struct ProcessReferralMilestone: Identifiable {
    let id: String
    let thresholdLabel: String
    let title: String
    let subtitle: String
    let progress: Double
    let isClaimed: Bool
    let usesGradientIcon: Bool
}

struct ProcessReferralMilestoneList: View {
    let milestones: [ProcessReferralMilestone]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                ProcessReferralMilestoneCard(milestone: milestone)

                if index < milestones.count - 1 {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.22))
                        .padding(.vertical, 10)
                }
            }
        }
    }
}

private struct ProcessReferralMilestoneCard: View {
    let milestone: ProcessReferralMilestone

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            milestoneIcon
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                Text(milestone.thresholdLabel.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ProcessReferralRewardsPalette.mintBright)
                    .tracking(0.6)

                Text(milestone.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(milestone.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(ProcessReferralTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.10))
                        Capsule(style: .continuous)
                            .fill(ProcessReferralRewardsPalette.mintBright)
                            .frame(width: max(0, geo.size.width * milestone.progress))
                    }
                }
                .frame(height: 4)
                .padding(.top, 2)

                if milestone.isClaimed {
                    HStack {
                        Spacer()
                        Label {
                            Text(AppCopy.t("Réclamé", en: "Claimed"))
                                .font(.system(size: 13, weight: .semibold))
                        } icon: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(ProcessReferralTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .processGlassEffect(in: Capsule(style: .continuous), interactive: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .processInteractiveGlassSurface(in: shape, interactive: false)
        .overlay {
            if milestone.usesGradientIcon {
                shape
                    .fill(ProcessReferralRewardsPalette.accentBlueSoft.opacity(0.10))
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var milestoneIcon: some View {
        let iconShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack {
            iconShape
                .fill(Color.clear)
                .processGlassEffect(in: iconShape, interactive: false)

            if milestone.usesGradientIcon {
                iconShape
                    .fill(
                        LinearGradient(
                            colors: [
                                ProcessReferralRewardsPalette.accentBlueSoft.opacity(0.35),
                                ProcessReferralRewardsPalette.mintSoft.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }

            Image(systemName: milestone.usesGradientIcon
                  ? "seal.fill"
                  : (milestone.isClaimed ? "gift.fill" : "sparkles"))
                .font(.system(size: milestone.usesGradientIcon ? 28 : 24, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textPrimary.opacity(0.9))
        }
        .clipShape(iconShape)
    }
}
