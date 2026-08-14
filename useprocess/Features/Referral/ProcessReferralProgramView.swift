import SafariServices
import SwiftUI

/// Hub parrainage — récompenses Apple (temps offert), layout Push-style.
struct ProcessReferralProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var store = ProcessReferralStore.shared
    @State private var showShareSheet = false
    @State private var showRewardsInfo = false

    var body: some View {
        ProcessReferralProgramScreen(
            store: store,
            showsBackButton: true,
            onBack: { dismiss() },
            showShareSheet: $showShareSheet,
            showRewardsInfo: $showRewardsInfo
        )
        .onAppear { reloadStore() }
    }

    private func reloadStore() {
        store.reload(
            username: profileService.currentProfile?.username,
            userId: profileService.currentProfile?.userId
        )
    }
}

/// Page parrainage depuis Paramètres (navigation push).
struct ProcessReferralProgramDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var store = ProcessReferralStore.shared
    @State private var showShareSheet = false
    @State private var showRewardsInfo = false

    var body: some View {
        ProcessReferralProgramScreen(
            store: store,
            showsBackButton: true,
            onBack: { dismiss() },
            showShareSheet: $showShareSheet,
            showRewardsInfo: $showRewardsInfo
        )
        .onAppear {
            store.reload(
                username: profileService.currentProfile?.username,
                userId: profileService.currentProfile?.userId
            )
        }
    }
}

// MARK: - Screen

private struct ProcessReferralProgramScreen: View {
    @Bindable var store: ProcessReferralStore
    let showsBackButton: Bool
    let onBack: () -> Void
    @Binding var showShareSheet: Bool
    @Binding var showRewardsInfo: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ProcessReferralTheme.pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                        .padding(.top, 8)

                    titleBlock
                        .padding(.top, 28)

                    ProcessReferralMetalCard(
                        referralCode: store.displayReferralCode,
                        copyText: store.copyPayload,
                        onCopy: {}
                    )
                        .padding(.top, 28)

                    howItWorksCard
                        .padding(.top, 28)
                        .padding(.horizontal, -8)

                    referralsSection
                        .padding(.top, 32)

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 22)
            }

            inviteFriendsButton
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showShareSheet) {
            ProfileShareSheet(items: [store.shareMessage])
        }
        .sheet(isPresented: $showRewardsInfo) {
            ProcessReferralRewardsInfoSheet(acceptedCount: store.snapshot.acceptedCount)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var headerRow: some View {
        HStack {
            if showsBackButton {
                ProcessReferralCircleIconButton(systemName: "chevron.left", action: onBack)
                    .accessibilityLabel(AppCopy.back)
            }

            Spacer()

            Text(AppCopy.t("Récompenses", en: "Rewards"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule(style: .continuous).fill(ProcessReferralTheme.chipBackground))
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(AppCopy.t("Invite des amis.", en: "Invite friends."))
            Text(AppCopy.t("Sois récompensé.", en: "Get rewarded."))
        }
        .font(.system(size: 34, weight: .bold))
        .foregroundStyle(ProcessReferralTheme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var howItWorksCard: some View {
        VStack(alignment: .center, spacing: 0) {
            ProcessReferralHowItWorksStep(
                icon: "link",
                title: AppCopy.t("Partage ton invite", en: "Share your invite"),
                subtitle: AppCopy.t(
                    "Envoie ton lien personnel à un ami.",
                    en: "Send your personal invite link to a friend."
                ),
                showsConnector: true
            )

            ProcessReferralHowItWorksStep(
                icon: "figure.strengthtraining.traditional",
                title: AppCopy.t("Ton ami rejoint", en: "Friend joins"),
                subtitle: AppCopy.t(
                    "Il s'inscrit, prend un abonnement Apple, et vous recevez tous les deux du temps offert.",
                    en: "They sign up, start an Apple subscription, and you both receive free time."
                ),
                showsConnector: true
            )

            ProcessReferralHowItWorksStep(
                icon: "gift.fill",
                title: AppCopy.t("Vous gagnez tous les deux", en: "You both win"),
                subtitle: ProcessReferralProgramTerms.referrerRewardSummary,
                showsConnector: false
            )

            Button {
                showRewardsInfo = true
            } label: {
                Text(AppCopy.t("Voir les récompenses", en: "View Rewards"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule(style: .continuous).fill(Color(white: 0.16)))
            }
            .buttonStyle(.processPlain)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ProcessReferralTheme.surface)
        }
    }

    private var referralsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppCopy.t("Tes parrainages", en: "Your referrals"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ProcessReferralTheme.textPrimary)

            if store.snapshot.entries.isEmpty {
                Text(AppCopy.t(
                    "Aucun parrainage pour l'instant. Partage ton code pour voir tes invités ici.",
                    en: "No referrals yet. Share your code to see your invites here."
                ))
                .font(.system(size: 14))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.snapshot.entries) { entry in
                        ProcessReferralDarkTrackingRow(entry: entry)
                    }
                }
            }
        }
    }

    private var inviteFriendsButton: some View {
        Button {
            HapticManager.shared.impact(.medium)
            ProcessAnalytics.trackReferralShareOpened(source: "referral_program")
            showShareSheet = true
        } label: {
            Text(AppCopy.t("Inviter des amis", en: "Invite Friends"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule(style: .continuous).fill(Color.white))
        }
        .buttonStyle(.processPlain)
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .background {
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - How it works step

private struct ProcessReferralHowItWorksStep: View {
    let icon: String
    let title: String
    let subtitle: String
    let showsConnector: Bool

    private let iconButtonSize: CGFloat = 42

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ProcessReferralGlassIconButton(systemName: icon, size: iconButtonSize)

                if showsConnector {
                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 1, height: 34)
                        .padding(.top, 8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(ProcessReferralTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.top, 6)
            .padding(.bottom, showsConnector ? 8 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
    }
}

private struct ProcessReferralGlassIconButton: View {
    let systemName: String
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.94))
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(.clear)
                    .processGlassEffect(in: Circle(), interactive: false)
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Rewards info sheet

private struct ProcessReferralRewardsInfoSheet: View {
    let acceptedCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(ProcessReferralProgramTerms.rewardHeadline)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)

                Text(AppCopy.t(
                    "Quand ton ami s'inscrit avec ton code et prend un abonnement Apple, vous recevez tous les deux du temps offert sur Process — crédité automatiquement via l'App Store.",
                    en: "When your friend signs up with your code and starts an Apple subscription, you both receive free Process time — credited automatically through the App Store."
                ))
                .font(.system(size: 15))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                rewardRow(
                    title: AppCopy.t("Pour toi (parrain)", en: "For you (referrer)"),
                    detail: ProcessReferralProgramTerms.referrerRewardSummary
                )

                rewardRow(
                    title: AppCopy.t("Pour ton ami (invité)", en: "For your friend (invitee)"),
                    detail: AppCopy.t(
                        "7 jours offerts sur son abonnement Apple après son 1er paiement.",
                        en: "7 free days on their Apple subscription after their first payment."
                    )
                )

                HStack {
                    Text(AppCopy.t("Parrainages validés", en: "Verified referrals"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ProcessReferralTheme.textPrimary)
                    Spacer()
                    Text("\(acceptedCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(ProcessReferralTheme.textPrimary)
                        .monospacedDigit()
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(ProcessReferralTheme.surface)
                }

                Spacer()
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ProcessReferralTheme.pageBackground.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppCopy.close) { dismiss() }
                        .foregroundStyle(ProcessReferralTheme.textPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private func rewardRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textPrimary)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ProcessReferralTheme.surface)
        }
    }
}

// MARK: - Tracking row (dark)

private struct ProcessReferralDarkTrackingRow: View {
    let entry: ProcessReferralEntry

    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.maskedName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)

                Text(AppCopy.t(
                    "Invité le \(Self.dateFormatter.string(from: entry.invitedAt))",
                    en: "Invited \(Self.dateFormatter.string(from: entry.invitedAt))"
                ))
                .font(.system(size: 12))
                .foregroundStyle(ProcessReferralTheme.textSecondary)

                if let rewardLabel = entry.rewardLabel {
                    Text(rewardLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.95, blue: 0.65))
                }
            }

            Spacer(minLength: 8)

            ProcessReferralStatusBadge(status: entry.status)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ProcessReferralTheme.surface)
        }
    }
}

// MARK: - Shared chrome

enum ProcessReferralTheme {
    static let pageBackground = Color.black
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let chipBackground = Color(white: 0.14)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.62)
    static let textTertiary = Color(white: 0.45)
}

struct ProcessReferralCircleIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(ProcessReferralTheme.chipBackground))
        }
        .buttonStyle(.processPlain)
    }
}

struct ProcessReferralToolbarButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        ProcessReferralCircleIconButton(systemName: systemName, action: action)
    }
}

struct ProcessReferralStatusBadge: View {
    let status: ProcessReferralEntryStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)

            Text(status.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(backgroundColor, in: Capsule())
    }

    private var dotColor: Color {
        status == .accepted ? Color(red: 0.2, green: 0.78, blue: 0.35) : Color.orange
    }

    private var textColor: Color {
        status == .accepted ? Color(red: 0.55, green: 0.95, blue: 0.65) : Color.orange.opacity(0.95)
    }

    private var backgroundColor: Color {
        status == .accepted
            ? Color(red: 0.2, green: 0.78, blue: 0.35).opacity(0.16)
            : Color.orange.opacity(0.14)
    }
}

// MARK: - Legacy status section (tracking view)

struct ProcessReferralStatusSection: View {
    let entries: [ProcessReferralEntry]

    var body: some View {
        EmptyView()
    }
}
