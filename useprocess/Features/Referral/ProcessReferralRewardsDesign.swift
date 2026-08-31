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

// MARK: - Opal progress text (page parrainage)

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
