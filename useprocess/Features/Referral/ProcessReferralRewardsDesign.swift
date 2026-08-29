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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .processGlassButton(in: Capsule(style: .continuous))
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
        }
    }
}

// MARK: - Reward promo (partagé Réglages + page parrainage)

struct ProcessReferralRewardPromoFeature: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
}

enum ProcessReferralRewardPromoContent {
    @MainActor
    static var headerTitle: String {
        AppCopy.t(
            "Gagne du temps Process",
            en: "Earn free Process time"
        )
    }

    @MainActor
    static var headerSubtitle: String {
        AppCopy.t(
            "Parraine tes amis — tu gagnes \(ProcessReferralProgramTerms.perFriendRewardLabel).",
            en: "Refer friends — you earn \(ProcessReferralProgramTerms.perFriendRewardLabel)."
        )
    }

    @MainActor
    static var features: [ProcessReferralRewardPromoFeature] {
        [
            ProcessReferralRewardPromoFeature(
                id: "reward",
                icon: "gift.fill",
                title: ProcessReferralProgramTerms.headline,
                detail: ProcessReferralProgramTerms.subtitle
            ),
            ProcessReferralRewardPromoFeature(
                id: "share",
                icon: "link",
                title: AppCopy.t("Lien unique à partager", en: "One link to share"),
                detail: AppCopy.t(
                    "WhatsApp, Instagram ou iMessage en un tap.",
                    en: "WhatsApp, Instagram, or iMessage in one tap."
                )
            ),
            ProcessReferralRewardPromoFeature(
                id: "plan",
                icon: "calendar",
                title: AppCopy.t("Selon ton abonnement", en: "Based on your plan"),
                detail: AppCopy.t(
                    "Plan mensuel → 1 mois offert. Plan annuel → 1 an offert.",
                    en: "Monthly plan → 1 month free. Annual plan → 1 year free."
                )
            ),
            ProcessReferralRewardPromoFeature(
                id: "once",
                icon: "checkmark.seal.fill",
                title: AppCopy.t("Une fois par ami", en: "Once per friend"),
                detail: AppCopy.t(
                    "La récompense est créditée quand ton ami paie son abonnement.",
                    en: "The reward is granted when your friend pays for their subscription."
                )
            )
        ]
    }
}

struct ProcessReferralRewardPromoFeatureRow: View {
    let feature: ProcessReferralRewardPromoFeature

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

struct ProcessReferralRewardSimulatorSection: View {
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
                Text(ProcessReferralRewardPromoContent.headerTitle)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ProcessSettingsOpalTheme.sectionTitleTint)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ProcessReferralRewardPromoContent.headerSubtitle)
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
                ForEach(ProcessReferralRewardPromoContent.features) { feature in
                    ProcessReferralRewardPromoFeatureRow(feature: feature)
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
            Text(AppCopy.t("Simule tes récompenses", en: "Simulate your rewards"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .frame(maxWidth: .infinity)

            Text(ProcessReferralProgramTerms.simulatedRewardLabel(friendCount: friendCountInt))
                .font(PaywallBevelTheme.paywallHeroTitleFont(size: 48))
                .tracking(PaywallBevelTheme.paywallHeroTitleTracking)
                .foregroundStyle(PaywallBevelTheme.paywallProTitleGradient(for: colorScheme))
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.22), value: friendCountInt)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

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

            Text(ProcessReferralProgramTerms.perFriendSimulatorDetailLabel())
                .font(PaywallBevelTheme.paywallHeroSubtitleFont(size: 15))
                .foregroundStyle(ProcessReferralRewardsPalette.mintBright)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var promoWatermark: some View {
        Image(systemName: "gift.fill")
            .font(.system(size: 88, weight: .semibold))
            .foregroundStyle(ProcessReferralRewardsPalette.mintBright.opacity(0.22))
            .frame(width: 132, height: 132)
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
}

// MARK: - Opal headline (page parrainage)

struct ProcessReferralOpalHeadlineSection: View {
    let acceptedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ProcessReferralProgramTerms.opalOfferHeadline)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(ProcessReferralTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ProcessReferralOpalProgressText(acceptedCount: acceptedCount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }
}

struct ProcessReferralOpalProgressText: View {
    let acceptedCount: Int

    private var mint: Color { ProcessReferralRewardsPalette.mintBright }

    var body: some View {
        Group {
            if acceptedCount == 0 {
                Text(ProcessReferralProgramTerms.opalZeroFriendsBody)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ProcessReferralTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                (
                    Text(AppCopy.t("Bravo ! Tu as parrainé ", en: "Nice! You referred "))
                        .foregroundStyle(ProcessReferralTheme.textSecondary)
                    + Text(friendCountFragment)
                        .foregroundStyle(mint)
                        .fontWeight(.semibold)
                    + Text(AppCopy.t(" sur Process. ", en: " on Process. "))
                        .foregroundStyle(ProcessReferralTheme.textSecondary)
                    + Text(ProcessReferralProgramTerms.opalProgressSuffix)
                        .foregroundStyle(ProcessReferralTheme.textSecondary)
                )
                .font(.system(size: 15, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var friendCountFragment: String {
        switch acceptedCount {
        case 1:
            return AppCopy.t("1 ami", en: "1 friend")
        default:
            return AppCopy.t("\(acceptedCount) amis", en: "\(acceptedCount) friends")
        }
    }
}

// MARK: - Social share row (style Opal)

struct ProcessReferralGlassSocialShareRow: View {
    let shareMessage: String
    let link: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 8) {
            socialItem(
                title: AppCopy.t("Copier le lien", en: "Copy link"),
                brand: .copyLink
            ) {
                _ = ProcessReferralShareRouter.handle(
                    .copyLink,
                    message: shareMessage,
                    link: link
                )
            }

            socialItem(
                title: "Instagram",
                brand: .instagram
            ) {
                _ = ProcessReferralShareRouter.handle(
                    .instagram,
                    message: shareMessage,
                    link: link
                )
            }

            socialItem(
                title: "WhatsApp",
                brand: .whatsApp
            ) {
                _ = ProcessReferralShareRouter.handle(
                    .whatsApp,
                    message: shareMessage,
                    link: link
                )
            }

            socialItem(
                title: "TikTok",
                brand: .tikTok
            ) {
                _ = ProcessReferralShareRouter.handle(
                    .tikTok,
                    message: shareMessage,
                    link: link
                )
            }

            clipperItem
        }
        .frame(maxWidth: .infinity)
    }

    private var clipperItem: some View {
        let buttonSize = ProcessReferralSocialShareMetrics.buttonSize
        let title = AppCopy.t("Clippers", en: "Clippers")

        return VStack(spacing: 8) {
            Button {
                HapticManager.shared.impact(.light)
                Task { openURL(await ProcessAffiliatePortalLink.portalURLForCurrentUser()) }
            } label: {
                Image("PlanHomeUpgradeDollar")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: buttonSize, height: buttonSize)
                    .scaleEffect(ProcessReferralSocialShareMetrics.brandImageFillScale)
                    .frame(width: buttonSize, height: buttonSize)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .frame(width: buttonSize, height: buttonSize)
            .accessibilityLabel(title)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func socialItem(
        title: String,
        brand: ProcessReferralSocialBrand,
        action: @escaping () -> Void
    ) -> some View {
        let buttonSize = ProcessReferralSocialShareMetrics.buttonSize

        return VStack(spacing: 8) {
            Button(action: action) {
                ProcessReferralSocialBrandIcon(brand: brand, size: buttonSize)
            }
            .buttonStyle(.plain)
            .frame(width: buttonSize, height: buttonSize)
            .accessibilityLabel(title)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Referral stats (legacy card removed — rewards shown on metal card)

// MARK: - How it works (timeline)

private struct ProcessReferralHowItWorksStep: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
}

struct ProcessReferralHowItWorksSection: View {
    var onViewRewards: () -> Void

    private let cardShape = RoundedRectangle(
        cornerRadius: ProcessSettingsOpalTheme.cardCornerRadius,
        style: .continuous
    )

    @MainActor
    private var steps: [ProcessReferralHowItWorksStep] {
        [
            ProcessReferralHowItWorksStep(
                id: "share",
                icon: "link",
                title: AppCopy.t("Partage ton invitation", en: "Share your invite"),
                detail: AppCopy.t(
                    "Envoie ton lien personnel à un ami.",
                    en: "Send your personal invite link to a friend."
                )
            ),
            ProcessReferralHowItWorksStep(
                id: "join",
                icon: "person.crop.circle.badge.plus",
                title: AppCopy.t("Ton ami rejoint Process", en: "Friend joins Process"),
                detail: AppCopy.t(
                    "Il s’inscrit avec ton lien et s’abonne.",
                    en: "They sign up with your link and subscribe."
                )
            ),
            ProcessReferralHowItWorksStep(
                id: "reward",
                icon: "gift.fill",
                title: AppCopy.t("Tu débloques ta récompense", en: "You unlock rewards"),
                detail: AppCopy.t(
                    "Tu gagnes \(ProcessReferralProgramTerms.perFriendRewardLabel) après son premier paiement.",
                    en: "You earn \(ProcessReferralProgramTerms.perFriendRewardLabel) after their first payment."
                )
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    ProcessReferralHowItWorksStepRow(
                        step: step,
                        showsConnector: index < steps.count - 1
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Button(action: onViewRewards) {
                Text(AppCopy.t("Voir les récompenses", en: "View rewards"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ProcessReferralTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            cardShape.fill(ProcessReferralTheme.surface)
        }
        .overlay {
            cardShape.strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        }
        .padding(.top, 28)
    }
}

private struct ProcessReferralHowItWorksStepRow: View {
    let step: ProcessReferralHowItWorksStep
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: step.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ProcessReferralTheme.textPrimary.opacity(0.88))
                }

                if showsConnector {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 2, height: 36)
                        .padding(.vertical, 6)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.detail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ProcessReferralTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .padding(.bottom, showsConnector ? 8 : 0)

            Spacer(minLength: 0)
        }
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
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .processGlassButton(in: shape)
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
