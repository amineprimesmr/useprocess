import SafariServices
import SwiftUI

/// Hub parrainage — style Bevel, récompenses Process (15 €, Pro).
struct ProcessReferralProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var store = ProcessReferralStore.shared
    @State private var showTracking = false
    @State private var showShareSheet = false
    @State private var showTerms = false
    @State private var redeemedAlertReward: ProcessReferralReward?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroCard
                        .padding(.top, 8)

                    headlineBlock
                        .padding(.top, 28)

                    linkSection
                        .padding(.top, 24)

                    shareButton
                        .padding(.top, 16)

                    termsLine
                        .padding(.top, 12)

                    rewardsSection
                        .padding(.top, 32)

                    legalFooter
                        .padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .processTransparentScrollSurface()
            .navigationTitle("Récompenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProcessReferralToolbarButton(systemName: "chevron.left", action: { dismiss() })
                        .accessibilityLabel("Fermer")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ProcessReferralToolbarButton(systemName: "person.2.fill", action: { showTracking = true })
                        .accessibilityLabel("Suivre les parrainages")
                }
            }
            .sheet(isPresented: $showTracking) {
                ProcessReferralTrackingView()
            }
            .sheet(isPresented: $showShareSheet) {
                ProfileShareSheet(items: [store.shareMessage, store.referralLink])
            }
            .sheet(isPresented: $showTerms) {
                ProcessReferralSafariView(url: ProcessLegalURLs.termsOfUse)
            }
            .alert(
                "Récompense demandée",
                isPresented: Binding(
                    get: { redeemedAlertReward != nil },
                    set: { if !$0 { redeemedAlertReward = nil } }
                ),
                presenting: redeemedAlertReward
            ) { reward in
                Button("OK", role: .cancel) {}
            } message: { reward in
                Text(redeemedConfirmation(for: reward))
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .onAppear {
            store.reload(
                username: profileService.currentProfile?.username,
                userId: profileService.currentProfile?.userId
            )
        }
    }

  // MARK: - Hero

    private var heroCard: some View {
        Image("carteparrainage")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 24, y: 10)
            .accessibilityLabel("Gagnez 15 euros par parrainage")
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invitez et gagnez 15 €")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(ProcessReferralTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                "Offrez à vos amis 30 jours d'accès Process Pro et recevez 15 € pour chaque parrainage validé."
            )
            .font(.system(size: 15))
            .foregroundStyle(ProcessReferralTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Votre lien de parrainage")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)

                Button {
                    // Info — même contenu que le footer
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ProcessReferralTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Informations sur le parrainage")
            }

            HStack(spacing: 12) {
                Text(store.referralLink)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                Button {
                    UIPasteboard.general.string = store.referralLink
                    HapticManager.shared.notification(.success)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ProcessReferralTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copier le lien")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        ProcessReferralTheme.dashedBorder,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                    )
            }
        }
    }

    private var shareButton: some View {
        Button {
            HapticManager.shared.impact(.medium)
            showShareSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                Text("Partager votre lien de parrainage")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var termsLine: some View {
        Button {
            showTerms = true
        } label: {
            Text("En utilisant notre programme de parrainage, vous acceptez nos conditions d'utilisation.")
                .font(.system(size: 12))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vos récompenses")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ProcessReferralTheme.textPrimary)

            Text(
                "Partagez Process avec un ami. Il profite de 30 jours Pro et vous recevez 15 € ou des mois gratuits."
            )
            .font(.system(size: 14))
            .foregroundStyle(ProcessReferralTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 14) {
                ForEach(ProcessReferralReward.catalog) { reward in
                    ProcessReferralRewardCard(
                        reward: reward,
                        progress: store.progress(for: reward),
                        canRedeem: store.canRedeem(reward),
                        isRedeemed: store.isRedeemed(reward),
                        onRedeem: {
                            store.redeem(reward: reward)
                            redeemedAlertReward = reward
                        }
                    )
                }
            }
        }
    }

    private var legalFooter: some View {
        Text(
            "Les parrainages sont vérifiés par notre équipe. Process se réserve le droit de révoquer les avantages en cas d'abus ou de fraude."
        )
        .font(.system(size: 11))
        .foregroundStyle(ProcessReferralTheme.textTertiary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func redeemedConfirmation(for reward: ProcessReferralReward) -> String {
        switch reward.kind {
        case .cashEUR:
            return "Ta demande de \(reward.cashAmount ?? 15) € a été enregistrée. Notre équipe valide sous 48 h."
        case .proMonths:
            let months = reward.proMonths ?? 1
            return "Ta demande de \(months) mois Pro gratuit a été enregistrée. Notre équipe valide sous 48 h."
        }
    }
}

// MARK: - Reward card

private struct ProcessReferralRewardCard: View {
    let reward: ProcessReferralReward
    let progress: (current: Int, total: Int)
    let canRedeem: Bool
    let isRedeemed: Bool
    var onRedeem: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ProcessReferralRewardIcon(reward: reward)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(reward.requiredReferrals) parrainage\(reward.requiredReferrals > 1 ? "s" : "")")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ProcessReferralTheme.badgeBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ProcessReferralTheme.badgeBlue.opacity(0.12), in: Capsule())

                Text(reward.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(progress.current)/\(progress.total)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(ProcessReferralTheme.textSecondary)
            }

            Spacer(minLength: 4)

            redeemButton
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ProcessReferralTheme.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
        }
    }

    @ViewBuilder
    private var redeemButton: some View {
        if isRedeemed {
            Text("Échangé")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ProcessReferralTheme.chipBackground, in: Capsule())
        } else if canRedeem {
            Button {
                HapticManager.shared.impact(.medium)
                onRedeem()
            } label: {
                Text("Échanger")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black, in: Capsule())
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Échanger")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(ProcessReferralTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ProcessReferralTheme.chipBackground, in: Capsule())
        }
    }
}

// MARK: - Shared chrome

enum ProcessReferralTheme {
    static var pageBackground: Color { Color(UIColor.systemGroupedBackground) }
    static var cardBackground: Color { Color(UIColor.secondarySystemGroupedBackground) }
    static var chipBackground: Color { Color(UIColor.tertiarySystemGroupedBackground) }
    static var textPrimary: Color { Color(UIColor.label) }
    static var textSecondary: Color { Color(UIColor.secondaryLabel) }
    static var textTertiary: Color { Color(UIColor.tertiaryLabel) }
    static var badgeBlue: Color { Color(red: 0.0, green: 0.48, blue: 1.0) }
    static var dashedBorder: Color { Color(UIColor.separator) }
}

struct ProcessReferralToolbarButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

struct ProcessReferralRewardIcon: View {
    let reward: ProcessReferralReward

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)

            Image(systemName: reward.iconSystemName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
    }

    private var gradientColors: [Color] {
        reward.accentGradient.map { Color(hex: $0) }
    }
}

private struct ProcessReferralSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewControllerWrapper {
        SFSafariViewControllerWrapper(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewControllerWrapper, context: Context) {}
}

private final class SFSafariViewControllerWrapper: UIViewController {
    init(url: URL) {
        super.init(nibName: nil, bundle: nil)
        let safari = SFSafariViewController(url: url)
        addChild(safari)
        view.addSubview(safari.view)
        safari.view.frame = view.bounds
        safari.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        safari.didMove(toParent: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}